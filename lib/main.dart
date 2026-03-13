import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:astralkeytest/src/core/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _autoOpenWebAuth =
      bool.fromEnvironment('ASTRAL_E2E_AUTO_WEBAUTH', defaultValue: false);

  EnvironmentMode _mode = EnvironmentMode.demo;

  @override
  void initState() {
    super.initState();
    if (_autoOpenWebAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WebAuthScreen()),
        );
      });
    }
  }

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
      MaterialPageRoute(
        builder: (_) => DocumentsScreen(
          authBanner: '${result.flow}: ${result.message}${result.errorCode != null ? ' (${result.errorCode})' : ''}',
        ),
      ),
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
  static const _clientId =
      String.fromEnvironment('ASTRAL_OIDC_CLIENT_ID', defaultValue: 'astral_key');
  static const _clientSecret = String.fromEnvironment(
    'ASTRAL_OIDC_CLIENT_SECRET',
    defaultValue: 'JAskxk427kP5Hj21',
  );
  static const _redirectUri = String.fromEnvironment(
    'ASTRAL_OIDC_REDIRECT_URI',
    defaultValue: 'astralkey://oauth.callback',
  );

  String _status = 'Подготовка Web Auth...';

  @override
  void initState() {
    super.initState();
    _runAuth();
  }

  Future<void> _runAuth() async {
    final supportedPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (!supportedPlatform) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DocumentsScreen(
            authBanner:
                'Web Auth: Web Auth поддерживается на Android/iOS/Windows (PLATFORM_NOT_SUPPORTED)',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MobileWebAuthScreen(
          clientId: _clientId,
          clientSecret: _clientSecret,
          redirectUri: _redirectUri,
        ),
      ),
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

class MobileWebAuthScreen extends StatefulWidget {
  const MobileWebAuthScreen({
    super.key,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  final String clientId;
  final String clientSecret;
  final String redirectUri;

  @override
  State<MobileWebAuthScreen> createState() => _MobileWebAuthScreenState();
}

class _MobileWebAuthScreenState extends State<MobileWebAuthScreen> {
  void _finishFlow(String banner) {
    if (_finished) return;
    _finished = true;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DocumentsScreen(authBanner: banner),
      ),
    );
  }

  static const _authorizeEndpoint =
      'https://identity.demo.astral-dev.ru/connect/authorize';
  static const _tokenEndpoint =
      'https://identity.demo.astral-dev.ru/connect/token';

  final _codeController = TextEditingController();
  final _state = _randomToken();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _isSubmitting = false;
  bool _finished = false;
  String _status = 'Открываем страницу авторизации...';

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Uri get _authUri {
    return Uri.parse(_authorizeEndpoint).replace(
      queryParameters: {
        'client_id': widget.clientId,
        'redirect_uri': widget.redirectUri,
        'response_type': 'code',
        'scope': 'openid',
        'response_mode': 'query',
        'state': _state,
      },
    );
  }

  bool _isRedirectUri(Uri uri) {
    final redirectBase = widget.redirectUri.split('?').first;
    return uri.toString().startsWith(redirectBase);
  }

  void _handleRedirectUri(Uri uri) {
    if (!_isRedirectUri(uri) || _finished) return;
    _codeController.text = uri.toString();
    _exchangeCode();
  }

  Future<void> _startMobileFlow() async {
    Uri? initialUri;
    try {
      initialUri = await _appLinks.getInitialLink();
    } on PlatformException catch (e) {
      dev.log('WEB_AUTH_INITIAL_LINK_ERROR: ${e.code}', name: 'WEB_AUTH');
    }

    if (!mounted || _finished) return;

    if (initialUri != null && _isRedirectUri(initialUri)) {
      _handleRedirectUri(initialUri);
      return;
    }

    await _openAuth();
  }

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _sub = _appLinks.uriLinkStream.listen(_handleRedirectUri);
      unawaited(_startMobileFlow());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openAuth() async {
    final ok = await launchUrl(_authUri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _status = 'Не удалось открыть браузер');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть браузер')),
      );
    } else if (mounted) {
      setState(() => _status = 'Ожидаем callback после входа...');
    }
  }

  String _extractCode(String input) {
    final value = input.trim();
    if (value.contains('://')) {
      final uri = Uri.tryParse(value);
      return uri?.queryParameters['code']?.trim() ?? '';
    }
    return value;
  }

  bool _hasAccessToken(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final token = decoded['access_token'];
        return token is String && token.isNotEmpty;
      }
    } catch (_) {
      // ignore invalid json bodies
    }
    return false;
  }

  Future<void> _exchangeCode() async {
    if (_isSubmitting || _finished) return;

    final input = _codeController.text.trim();
    final code = _extractCode(input);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вставь code или полный redirect URL')),
      );
      return;
    }

    if (input.contains('://')) {
      final uri = Uri.tryParse(input);
      final returnedState = uri?.queryParameters['state'];
      if (returnedState != null && returnedState.isNotEmpty && returnedState != _state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('State не совпадает, авторизация отклонена')),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _status = 'Обмениваем код на токен...';
    });

    final watchdog = Timer(const Duration(seconds: 25), () {
      if (!mounted || _finished) return;
      _finishFlow('Web Auth: Таймаут обмена кода на токен (TOKEN_EXCHANGE_TIMEOUT)');
    });

    try {
      final basicAuth = base64Encode(
        utf8.encode('${widget.clientId}:${widget.clientSecret}'),
      );

      final response = await http
          .post(
            Uri.parse(_tokenEndpoint),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Basic $basicAuth',
            },
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': widget.redirectUri,
            },
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => http.Response('TOKEN_EXCHANGE_TIMEOUT', 598),
          );

      final hasAccessToken = _hasAccessToken(response.body);
      dev.log(
        'WEB_AUTH_TOKEN_RESULT status=${response.statusCode} token=${hasAccessToken ? 'present' : 'missing'}',
        name: 'WEB_AUTH',
      );

      if (mounted) {
        setState(() {
          final tokenSuffix = response.statusCode == 200
              ? (hasAccessToken ? ', token получен' : ', token не найден')
              : '';
          _status = 'Ответ token endpoint: HTTP_${response.statusCode}$tokenSuffix';
        });
      }

      if (response.statusCode == 200 && hasAccessToken) {
        _finishFlow('Web Auth: Авторизация успешна');
      } else if (response.statusCode == 200) {
        _finishFlow('Web Auth: HTTP_200, но access_token не найден (TOKEN_MISSING)');
      } else {
        _finishFlow(
          'Web Auth: Ошибка обмена кода (HTTP_${response.statusCode}) ${response.body.isNotEmpty ? response.body : ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ошибка обмена: $e';
        });
      }
      _finishFlow('Web Auth: Сетевая ошибка ($e)');
    } finally {
      watchdog.cancel();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Auth')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _isMobile
                  ? [
                      if (_isSubmitting)
                        const CircularProgressIndicator()
                      else
                        const Icon(Icons.info_outline, size: 36),
                      const SizedBox(height: 16),
                      Text(_status, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      if (!_isSubmitting && !_finished && _codeController.text.isNotEmpty)
                        FilledButton(
                          onPressed: _exchangeCode,
                          child: const Text('Повторить обмен'),
                        ),
                    ]
                  : [
                      const Text(
                        '1) Нажми кнопку ниже и войди в браузере.\n2) Скопируй параметр code из адресной строки redirect (или весь redirect URL).\n3) Вставь сюда и нажми Обменять код.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openAuth,
                        child: const Text('Открыть Web Auth в браузере'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code или полный redirect URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _exchangeCode,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Обменять код'),
                      ),
                    ],
            ),
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
        builder: (_) => const DocumentsScreen(
          authBanner: 'Web Auth (w/o client id): Токен не получен (TOKEN_NOT_RECEIVED)',
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

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.authBanner});

  final String? authBanner;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const _documents = [
    'Документ №1',
    'Документ №2',
    'Документ №3',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.authBanner != null && widget.authBanner!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.authBanner!)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Электронные перевозочные документы')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final title = _documents[index];
          return SizedBox(
            height: 96,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentDetailsScreen(title: title),
                  ),
                );
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({required this.title, super.key});

  final String title;

  static const _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. '
      'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. '
      'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(_lorem, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: null,
              child: const Text('Подписать'),
            ),
          ],
        ),
      ),
    );
  }
}
