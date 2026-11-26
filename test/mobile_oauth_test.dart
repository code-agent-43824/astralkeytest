import 'dart:convert';

import 'package:astralkeytest/src/auth/mobile_oauth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const redirect = 'astralkey://oauth.callback';
  late MobileOAuthAttempt attempt;

  setUp(() {
    attempt = MobileOAuthAttempt(
      clientId: 'fixture-client',
      clientSecret: 'fixture-client-password',
      redirectUri: redirect,
    );
  });

  test('Redeems the valid callback with the original PKCE verifier', () async {
    final authorization = attempt.authorizationUri;
    final parameters = authorization.queryParameters;
    expect(authorization.scheme, 'https');
    expect(authorization.host, 'identity.demo.astral-dev.ru');
    expect(authorization.path, '/connect/authorize');
    expect(parameters['redirect_uri'], redirect);
    expect(parameters['response_type'], 'code');
    expect(parameters['code_challenge_method'], 'S256');

    final callback = Uri.parse(redirect).replace(
      queryParameters: {'code': 'fixture-code', 'state': parameters['state']},
    );
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.scheme, 'https');
      expect(request.url.host, authorization.host);
      expect(request.url.path, '/connect/token');
      expect(request.bodyFields['code'], 'fixture-code');
      expect(request.bodyFields['redirect_uri'], redirect);
      final verifier = request.bodyFields['code_verifier']!;
      expect(verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43,128}$')));
      final challenge = base64UrlEncode(
        sha256.convert(utf8.encode(verifier)).bytes,
      ).replaceAll('=', '');
      expect(challenge, parameters['code_challenge']);
      return http.Response('{"access_token":"fixture-token"}', 200);
    });

    final token = await http.runWithClient(
      () => attempt.exchangeCallback(callback),
      () => client,
    );
    expect(token, 'fixture-token');
  });

  test('Rejects callbacks that do not match this attempt', () async {
    final state = attempt.authorizationUri.queryParameters['state'];
    final cases = [
      '$redirect?code=fixture-code',
      '$redirect?code=fixture-code&state=another-attempt',
      '$redirect?code=fixture-code&state=$state&state=$state',
      '$redirect/other?code=fixture-code&state=$state',
      '$redirect.other?code=fixture-code&state=$state',
      '$redirect?code=fixture-code&state=$state#fragment',
      '$redirect?code=fixture-code&code=another&state=$state',
      '$redirect?error=access_denied&state=$state',
    ];
    var tokenRequests = 0;
    await http.runWithClient(
      () async {
        for (final value in cases) {
          await expectLater(
            attempt.exchangeCallback(Uri.parse(value)),
            throwsA(isA<OAuthSignInException>()),
          );
        }
      },
      () => MockClient((_) async {
        tokenRequests++;
        return http.Response('{"access_token":"unexpected"}', 200);
      }),
    );
    expect(tokenRequests, 0);
  });

  test(
    'Reports a transport failure without exposing the request URL',
    () async {
      final callback = Uri.parse(redirect).replace(
        queryParameters: {
          'code': 'fixture-code',
          'state': attempt.authorizationUri.queryParameters['state'],
        },
      );
      await http.runWithClient(
        () async {
          await expectLater(
            attempt.exchangeCallback(callback),
            throwsA(
              isA<OAuthSignInException>().having(
                (error) => error.message,
                'message',
                'Не удалось связаться со стендом для получения токена.',
              ),
            ),
          );
        },
        () => MockClient((request) async {
          throw http.ClientException('fixture connection failure', request.url);
        }),
      );
    },
  );
}
