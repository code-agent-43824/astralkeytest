import 'package:astralkeytest/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Sign in opens the browser on ${platform.name}', (
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
        const MethodChannel('com.llfbandit.app_links/messages'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.app_links/events'),
        (_) async => null,
      );

      FlutterSecureStorage.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _openSignIn(tester);

        expect(find.byType(MobileWebAuthScreen), findsOneWidget);
        expect(find.byType(WebAuthScreen), findsNothing);
        expect(openedUrls.single.path, '/connect/authorize');
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
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
