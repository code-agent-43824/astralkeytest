import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:astralkeytest/src/core/app_version.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const AstralKeyTestApp());
}

class AstralKeyTestApp extends StatelessWidget {
  const AstralKeyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astral Key Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthMethodScreen(),
    );
  }
}

enum EnvironmentMode { demo, prod }

enum LoginMethod { email, phone }

class AuthResultData {
  const AuthResultData({
    required this.flow,
    required this.ok,
    required this.message,
    this.errorCode,
  });

  final String flow;
  final bool ok;
  final String message;
  final String? errorCode;
}

class AuthMethodScreen extends StatefulWidget {
  const AuthMethodScreen({super.key});

  @override
  State<AuthMethodScreen> createState() => _AuthMethodScreenState();
}

class _AuthMethodScreenState extends State<AuthMethodScreen> {
  EnvironmentMode _mode = EnvironmentMode.demo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Astral Key Test')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FlutterLogo(size: 84),
                const SizedBox(height: 16),
                Text(
                  'Выбор способа аутентификации',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                // ignore: deprecated_member_use
                RadioListTile<EnvironmentMode>(
                  value: EnvironmentMode.demo,
                  // ignore: deprecated_member_use
                  groupValue: _mode,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mode = value);
                    }
                  },
                  title: const Text('Demo'),
                ),
                // ignore: deprecated_member_use
                RadioListTile<EnvironmentMode>(
                  value: EnvironmentMode.prod,
                  // ignore: deprecated_member_use
                  groupValue: _mode,
                  // ignore: deprecated_member_use
                  onChanged: null,
                  title: const Text('Prod (пока недоступно)'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ApiAuthScreen(),
                      ),
                    );
                  },
                  child: const Text('API Auth'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WebAuthScreen(),
                      ),
                    );
                  },
                  child: const Text('Web Auth'),
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    kAppVersion,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';

    final part1 = digits.substring(0, digits.length.clamp(0, 3));
    final part2 = digits.length > 3
        ? digits.substring(3, digits.length.clamp(3, 6))
        : '';
    final part3 = digits.length > 6
        ? digits.substring(6, digits.length.clamp(6, 8))
        : '';
    final part4 = digits.length > 8
        ? digits.substring(8, digits.length.clamp(8, 10))
        : '';

    final buffer = StringBuffer('($part1');
    if (digits.length >= 3) buffer.write(')');
    if (part2.isNotEmpty) buffer.write(' $part2');
    if (part3.isNotEmpty) buffer.write('-$part3');
    if (part4.isNotEmpty) buffer.write('-$part4');

    return buffer.toString();
  }
}

class ApiAuthScreen extends StatefulWidget {
  const ApiAuthScreen({super.key});

  @override
  State<ApiAuthScreen> createState() => _ApiAuthScreenState();
}

class _ApiAuthScreenState extends State<ApiAuthScreen> {
  static const _baseUrl = 'https://identity.demo.astral-dev.ru';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginMethod _method = LoginMethod.email;
  bool _isSubmitting = false;

  bool get _isLoginValid {
    final login = _loginController.text.trim();
    if (_method == LoginMethod.email) {
      return _validateEmail(login) == null;
    }

    final digits = _extractDigits(login);
    return digits.length == 10;
  }

  bool get _canSubmit =>
      !_isSubmitting && _isLoginValid && _passwordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loginController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  @override
  void dispose() {
    _loginController.removeListener(_refresh);
    _passwordController.removeListener(_refresh);
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String _extractDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Введите e-mail';
    final at = value.indexOf('@');
    final lastDot = value.lastIndexOf('.');

    if (at <= 0 || lastDot <= at + 1 || lastDot >= value.length - 1) {
      return 'Некорректный e-mail';
    }

    return null;
  }

  String? _validatePhone(String value) {
    final digits = _extractDigits(value);
    if (digits.length != 10) {
      return 'Введите 10 цифр номера';
    }
    return null;
  }

  String _extractErrorMessage(String rawBody, int statusCode) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] is String &&
            (decoded['detail'] as String).trim().isNotEmpty) {
          return decoded['detail'] as String;
        }
        if (decoded['title'] is String &&
            (decoded['title'] as String).trim().isNotEmpty) {
          return decoded['title'] as String;
        }
      }
    } catch (_) {
      // ignore parse errors
    }

    return 'Ошибка авторизации';
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse(
        _method == LoginMethod.email
            ? '$_baseUrl/api/accounts/email/login'
            : '$_baseUrl/api/accounts/phone/login',
      );

      final loginValue = _method == LoginMethod.email
          ? _loginController.text.trim()
          : '+7${_extractDigits(_loginController.text)}';

      final payload = {
        _method == LoginMethod.email ? 'email' : 'phone': loginValue,
        'password': _passwordController.text,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _openResult(
          const AuthResultData(
            flow: 'API Auth',
            ok: true,
            message: 'Авторизация успешна',
          ),
        );
      } else {
        _openResult(
          AuthResultData(
            flow: 'API Auth',
            ok: false,
            message: _extractErrorMessage(response.body, response.statusCode),
            errorCode: 'HTTP_${response.statusCode}',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _openResult(
        AuthResultData(
          flow: 'API Auth',
          ok: false,
          message: 'Сетевая ошибка: $e',
          errorCode: 'NETWORK',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openResult(AuthResultData result) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthResultScreen(result: result)),
      (route) => route.isFirst,
    );
  }

  void _switchMethod(LoginMethod method) {
    if (_method == method) return;

    setState(() {
      _method = method;
      _loginController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Auth')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<LoginMethod>(
                    segments: const [
                      ButtonSegment(
                        value: LoginMethod.email,
                        icon: Icon(Icons.alternate_email),
                        label: Text('E-mail'),
                      ),
                      ButtonSegment(
                        value: LoginMethod.phone,
                        icon: Icon(Icons.phone),
                        label: Text('Телефон'),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (selection) {
                      _switchMethod(selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginController,
                    keyboardType: _method == LoginMethod.phone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    inputFormatters: _method == LoginMethod.phone
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            _PhoneMaskFormatter(),
                          ]
                        : const [],
                    decoration: InputDecoration(
                      labelText: _method == LoginMethod.email ? 'E-mail' : 'Телефон',
                      hintText: _method == LoginMethod.email
                          ? 'user@example.com'
                          : '+7 (XXX) XXX-XX-XX',
                      prefixText: _method == LoginMethod.phone ? '+7 ' : null,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_method == LoginMethod.email) {
                        return _validateEmail((value ?? '').trim());
                      }
                      return _validatePhone(value ?? '');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _canSubmit ? _onLoginPressed : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WebAuthScreen extends StatefulWidget {
  const WebAuthScreen({super.key});

  @override
  State<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends State<WebAuthScreen> {
  static const _baseUrl = 'https://identity.demo.astral-dev.ru';
  static const _redirectUri = 'astralkeytest://oauth/callback';
  static const _clientId = String.fromEnvironment('ASTRAL_OIDC_CLIENT_ID');

  late final WebViewController _controller;
  String _status = 'Инициализация...';

  String? _state;
  String? _codeVerifier;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    unawaited(_startAuth());
  }

  Future<void> _startAuth() async {
    if (_clientId.isEmpty) {
      _finish(
        const AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: 'Не задан ASTRAL_OIDC_CLIENT_ID для Web Auth',
          errorCode: 'CLIENT_NOT_CONFIGURED',
        ),
      );
      return;
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _randomBase64Url(24);

    _codeVerifier = codeVerifier;
    _state = state;

    final authorizeUri = Uri.parse('$_baseUrl/connect/authorize').replace(
      queryParameters: {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': 'openid profile email',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    setState(() => _status = 'Открываем страницу входа...');
    await _controller.loadRequest(authorizeUri);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (request.url.startsWith(_redirectUri)) {
      final uri = Uri.parse(request.url);
      unawaited(_handleRedirect(uri));
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleRedirect(Uri uri) async {
    if (_finished) return;

    final error = uri.queryParameters['error'];
    if (error != null) {
      _finish(
        AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: uri.queryParameters['error_description'] ?? 'Ошибка web auth',
          errorCode: error,
        ),
      );
      return;
    }

    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];

    if (code == null || returnedState == null || _state != returnedState) {
      _finish(
        const AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: 'Некорректный redirect от сервера',
          errorCode: 'BAD_REDIRECT',
        ),
      );
      return;
    }

    setState(() => _status = 'Обмениваем code на token...');
    await _exchangeCode(code);
  }

  Future<void> _exchangeCode(String code) async {
    final verifier = _codeVerifier;
    if (verifier == null) {
      _finish(
        const AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: 'Отсутствует code_verifier',
          errorCode: 'PKCE_VERIFIER_MISSING',
        ),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/connect/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'code': code,
        'redirect_uri': _redirectUri,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode == 200) {
      _finish(
        const AuthResultData(
          flow: 'Web Auth',
          ok: true,
          message: 'Авторизация успешна',
        ),
      );
      return;
    }

    String errorCode = 'HTTP_${response.statusCode}';
    String message = 'Ошибка обмена токена';

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] is String) {
        errorCode = data['error'] as String;
      }
      if (data['error_description'] is String) {
        message = data['error_description'] as String;
      }
    } catch (_) {
      // keep defaults
    }

    _finish(
      AuthResultData(
        flow: 'Web Auth',
        ok: false,
        message: message,
        errorCode: errorCode,
      ),
    );
  }

  void _finish(AuthResultData result) {
    if (_finished || !mounted) return;
    _finished = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthResultScreen(result: result)),
      (route) => route.isFirst,
    );
  }

  String _generateCodeVerifier() => _randomBase64Url(64);

  String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _randomBase64Url(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Auth')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black12,
            padding: const EdgeInsets.all(10),
            child: Text(_status),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

class AuthResultScreen extends StatelessWidget {
  const AuthResultScreen({required this.result, super.key});

  final AuthResultData result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Результат аутентификации')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  result.flow,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  result.ok ? 'OK' : 'ERROR',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: result.ok ? Colors.green : Colors.red,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Код ошибки: ${result.errorCode ?? '-'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const AuthMethodScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Назад к выбору'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
