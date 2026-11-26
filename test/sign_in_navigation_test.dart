import 'package:astralkeytest/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Sign in opens the Windows token form', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _openSignIn(tester);

      expect(find.byType(WindowsTokenAuthScreen), findsOneWidget);
      expect(find.byType(WebAuthScreen), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android exchanges only the callback for the active login', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final openedUrls = <Uri>[];
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        expect(call.method, 'launch');
        openedUrls.add(Uri.parse(call.arguments['url'] as String));
        return true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/events'),
      (_) async => null,
    );
    var tokenRequests = 0;
    final client = MockClient((request) async {
      tokenRequests++;
      expect(request.bodyFields['code'], 'fixture-code');
      return http.Response('{"access_token":"fixture-android-token"}', 200);
    });
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await http.runWithClient(() async {
        await _openSignIn(tester);

        expect(find.byType(MobileWebAuthScreen), findsOneWidget);
        expect(find.byType(WebAuthScreen), findsNothing);
        final uri = openedUrls.single;
        final parameters = uri.queryParameters;
        expect(uri.path, '/connect/authorize');
        expect(parameters['code_challenge_method'], 'S256');
        final redirect = Uri.parse(parameters['redirect_uri']!);
        Future<void> deliver(String state) async {
          final callback = redirect.replace(
            queryParameters: {'code': 'fixture-code', 'state': state},
          );
          await messenger.handlePlatformMessage(
            'com.llfbandit.app_links/events',
            const StandardMethodCodec().encodeSuccessEnvelope(
              callback.toString(),
            ),
            (_) {},
          );
          await tester.pumpAndSettle();
        }

        await deliver('old-attempt');
        expect(tokenRequests, 0);
        await deliver(parameters['state']!);
        expect(tokenRequests, 1);
        expect(await AuthTokenVault.readToken(), 'fixture-android-token');
        expect(find.byType(PinSetupScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS retries the system sign-in and copies the returned token', (
    tester,
  ) async {
    const fixtureToken = 'fixture-access-token';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final openedUrls = <Uri>[];
    String? copiedToken;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.astralkey.astralkeytest/oauth'),
      (call) async {
        expect(call.method, 'authenticate');
        final uri = Uri.parse(call.arguments['url'] as String);
        final parameters = uri.queryParameters;
        expect(parameters['code_challenge_method'], 'S256');
        expect(call.arguments['callbackScheme'], 'astralkey');
        openedUrls.add(uri);
        if (openedUrls.length == 1) return null;
        return Uri.parse(parameters['redirect_uri']!)
            .replace(
              queryParameters: {
                'code': 'fixture-code',
                'state': parameters['state'],
              },
            )
            .toString();
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedToken = call.arguments['text'] as String;
      }
      return null;
    });
    final client = MockClient((request) async {
      expect(request.bodyFields['code'], 'fixture-code');
      expect(request.bodyFields['code_verifier'], isNotEmpty);
      return http.Response('{"access_token":"$fixtureToken"}', 200);
    });

    tester.view.physicalSize = const Size(375, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await http.runWithClient(() async {
        await _openSignIn(tester);
        expect(
          find.text('Вход отменён. Можно попробовать снова.'),
          findsOneWidget,
        );
        await _tapText(tester, 'Попробовать войти снова');

        expect(openedUrls, hasLength(2));
        final first = openedUrls.first.queryParameters;
        final second = openedUrls.last.queryParameters;
        expect(first['state'], isNot(second['state']));
        expect(first['code_challenge'], isNot(second['code_challenge']));
        expect(await AuthTokenVault.readToken(), fixtureToken);
        expect(find.byType(PinSetupScreen), findsOneWidget);

        for (final digit in '12091209'.split('')) {
          await _tapText(tester, digit);
        }
        await _tapText(tester, 'Нет, оставить только PIN');
        expect(find.byType(DocumentsScreen), findsOneWidget);

        await tester.tap(find.byTooltip('Копировать токен'));
        await tester.pumpAndSettle();
        expect(copiedToken, fixtureToken);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const AstralKeyTestApp());
        await tester.pumpAndSettle();
        expect(find.byType(AppLockScreen), findsOneWidget);
        for (final digit in '1209'.split('')) {
          await _tapText(tester, digit);
        }
        expect(find.byType(DocumentsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final text = find.text(label);
  await tester.ensureVisible(text);
  await tester.tap(text);
  await tester.pumpAndSettle();
}

Future<void> _openSignIn(WidgetTester tester) async {
  await tester.pumpWidget(const AstralKeyTestApp());
  await tester.pumpAndSettle();
  final signIn = find.text('Войти с Астрал');
  await tester.ensureVisible(signIn);
  await tester.tap(signIn);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
