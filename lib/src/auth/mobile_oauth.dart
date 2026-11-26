import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

final class MobileOAuthAttempt {
  MobileOAuthAttempt({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  }) : _redirect = Uri.parse(redirectUri);

  static const _host = 'identity.demo.astral-dev.ru';

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final Uri _redirect;
  final String _state = _randomString(24);
  final String _verifier = _randomString(32);

  String get callbackScheme => _redirect.scheme;

  Uri get authorizationUri => Uri.https(_host, '/connect/authorize', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'openid',
    'response_mode': 'query',
    'state': _state,
    'code_challenge': _base64Url(sha256.convert(utf8.encode(_verifier)).bytes),
    'code_challenge_method': 'S256',
  });

  bool acceptsCallback(Uri callback) {
    if (callback.scheme != _redirect.scheme ||
        callback.authority != _redirect.authority ||
        callback.path != _redirect.path ||
        callback.hasFragment) {
      return false;
    }

    try {
      final parameters = callback.queryParametersAll;
      final state = parameters['state'];
      if (state == null || state.length != 1 || state.single != _state) {
        return false;
      }
      for (final entry in _redirect.queryParametersAll.entries) {
        final values = parameters[entry.key];
        if (values == null || values.length != entry.value.length) return false;
        for (var i = 0; i < values.length; i++) {
          if (values[i] != entry.value[i]) return false;
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<String> exchangeCallback(Uri callback) async {
    if (!acceptsCallback(callback)) {
      throw const OAuthSignInException(
        'Не удалось подтвердить возврат из входа.',
      );
    }

    final parameters = callback.queryParametersAll;
    if (parameters.containsKey('error')) {
      throw const OAuthSignInException('Вход отменён или доступ отклонён.');
    }
    final code = parameters['code'];
    if (code == null || code.length != 1 || code.single.isEmpty) {
      throw const OAuthSignInException('Стенд не вернул код входа.');
    }

    final client = http.Client();
    final request = http.Request('POST', Uri.https(_host, '/connect/token'))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      ..bodyFields = {
        'grant_type': 'authorization_code',
        'code': code.single,
        'redirect_uri': redirectUri,
        'code_verifier': _verifier,
      };
    final credentials =
        '${Uri.encodeQueryComponent(clientId)}:'
        '${Uri.encodeQueryComponent(clientSecret)}';
    request.headers['Authorization'] =
        'Basic ${base64Encode(utf8.encode(credentials))}';

    final http.Response response;
    try {
      response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const OAuthSignInException('Стенд не ответил вовремя.');
    } catch (_) {
      throw const OAuthSignInException(
        'Не удалось связаться со стендом для получения токена.',
      );
    } finally {
      client.close();
    }

    if (response.statusCode != 200) {
      throw OAuthSignInException(
        'Стенд отклонил обмен кода на токен (HTTP ${response.statusCode}).',
      );
    }

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final token = body['access_token'];
        if (token is String && token.isNotEmpty) return token;
      }
      throw const OAuthSignInException('Стенд не вернул токен доступа.');
    } on FormatException {
      throw const OAuthSignInException(
        'Стенд вернул ответ в неверном формате.',
      );
    }
  }

  static String _randomString(int length) {
    final random = Random.secure();
    return _base64Url(List.generate(length, (_) => random.nextInt(256)));
  }

  static String _base64Url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');
}

final class OAuthSignInException implements Exception {
  const OAuthSignInException(this.message);

  final String message;
}
