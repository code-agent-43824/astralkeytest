import 'dart:convert';

import 'package:astralkeytest/src/core/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
                      MaterialPageRoute(builder: (_) => const ApiAuthScreen()),
                    );
                  },
                  child: const Text('API Auth'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WebAuthScreen()),
                    );
                  },
                  child: const Text('Web Auth'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WebAuthNoClientIdScreen(),
                      ),
                    );
                  },
                  child: const Text('Web Auth (w/o client id)'),
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

  String _extractErrorMessage(String rawBody) {
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
            message: _extractErrorMessage(response.body),
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
  static const _discoveryUrl =
      'https://identity.demo.astral-dev.ru/.well-known/openid-configuration';
  static const _clientId = String.fromEnvironment('ASTRAL_OIDC_CLIENT_ID');
  static const _redirectUri =
      String.fromEnvironment('ASTRAL_OIDC_REDIRECT_URI', defaultValue: 'astralkeytest://oauth/callback');

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  String _status = 'Подготовка Web Auth...';

  @override
  void initState() {
    super.initState();
    _runAuth();
  }

  Future<void> _runAuth() async {
    if (_clientId.isEmpty) {
      _finish(
        const AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: 'Не задан ASTRAL_OIDC_CLIENT_ID',
          errorCode: 'CLIENT_NOT_CONFIGURED',
        ),
      );
      return;
    }

    try {
      setState(() => _status = 'Открываем системный экран аутентификации...');

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          discoveryUrl: _discoveryUrl,
          scopes: const ['openid', 'profile', 'email'],
          promptValues: const ['login'],
        ),
      );

      if (result.accessToken != null) {
        _finish(
          const AuthResultData(
            flow: 'Web Auth',
            ok: true,
            message: 'Авторизация успешна',
          ),
        );
      } else {
        _finish(
          const AuthResultData(
            flow: 'Web Auth',
            ok: false,
            message: 'Токен не получен',
            errorCode: 'TOKEN_EMPTY',
          ),
        );
      }
    } on PlatformException catch (e) {
      _finish(
        AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: e.message ?? 'Ошибка системной аутентификации',
          errorCode: e.code,
        ),
      );
    } catch (e) {
      _finish(
        AuthResultData(
          flow: 'Web Auth',
          ok: false,
          message: 'Ошибка: $e',
          errorCode: 'UNEXPECTED',
        ),
      );
    }
  }

  void _finish(AuthResultData result) {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthResultScreen(result: result)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Auth')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebAuthNoClientIdScreen extends StatefulWidget {
  const WebAuthNoClientIdScreen({super.key});

  @override
  State<WebAuthNoClientIdScreen> createState() => _WebAuthNoClientIdScreenState();
}

class _WebAuthNoClientIdScreenState extends State<WebAuthNoClientIdScreen> {
  static const _loginPageUrl = 'https://identity.demo.astral-dev.ru/account/login';

  Future<void> _openBrowser() async {
    final ok = await launchUrl(
      Uri.parse(_loginPageUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть браузер')),
      );
    }
  }

  void _finishWithoutToken() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AuthResultScreen(
          result: AuthResultData(
            flow: 'Web Auth (w/o client id)',
            ok: false,
            message: 'Токен не получен',
            errorCode: 'TOKEN_NOT_RECEIVED',
          ),
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Auth (w/o client id)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Открой страницу аутентификации в браузере, пройди вход и капчу вручную. После этого вернись и заверши шаг без токена.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _openBrowser,
                  child: const Text('Открыть страницу в браузере'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _finishWithoutToken,
                  child: const Text('Завершить без токена'),
                ),
              ],
            ),
          ),
        ),
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
