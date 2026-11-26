import 'package:astralkeytest/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('A Keychain error after token exchange leaves sign-in retryable', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.astralkey.astralkeytest/oauth'),
      (call) async {
        final parameters = Uri.parse(
          call.arguments['url'] as String,
        ).queryParameters;
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

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'read') return null;
        expect(call.method, 'write');
        expect(call.arguments['value'], 'fixture-token');
        throw PlatformException(
          code: 'Unexpected security result code',
          details: -34018,
        );
      },
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: MobileWebAuthScreen(
                clientId: 'fixture-client',
                clientSecret: 'fixture-client-secret',
                redirectUri: 'astralkey://oauth.callback',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Не удалось сохранить вход в защищённом хранилище (код -34018).',
            ),
            findsOneWidget,
          );
          final retry = find.widgetWithText(
            FilledButton,
            'Попробовать войти снова',
          );
          expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
          expect(find.byType(DocumentsScreen), findsNothing);
        },
        () => MockClient((_) async {
          return http.Response('{"access_token":"fixture-token"}', 200);
        }),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
