import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:astralkeytest/src/core/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class AuthTokenVault {
  AuthTokenVault._();

  static const _tokenKey = 'auth_access_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> save(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }
}

class AuthMethodScreen extends StatefulWidget {
  const AuthMethodScreen({super.key});

  @override
  State<AuthMethodScreen> createState() => _AuthMethodScreenState();
}

class _AuthMethodScreenState extends State<AuthMethodScreen> {
  static const _autoOpenWebAuth =
      bool.fromEnvironment('ASTRAL_E2E_AUTO_WEBAUTH', defaultValue: false);

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/auth_logo.png',
                  height: 140,
                ),
                const SizedBox(height: 20),
                Text(
                  'Добро пожаловать\nв АстралКлюч',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Войдите в аккаунт или зарегистрируйтесь, чтобы начать работу',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WebAuthScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Войти с Астрал'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('ID'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Создать новый аккаунт'),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            'Demo',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Prod',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Версия $kAppVersion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Есть вопросы? Напишите нам support@astral.ru',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
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

class WebAuthScreen extends StatefulWidget {
  const WebAuthScreen({super.key});

  @override
  State<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends State<WebAuthScreen> {
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
    if (kIsWeb) {
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

    if (defaultTargetPlatform == TargetPlatform.windows) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WindowsTokenAuthScreen()),
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
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

class WindowsTokenAuthScreen extends StatefulWidget {
  const WindowsTokenAuthScreen({super.key});

  @override
  State<WindowsTokenAuthScreen> createState() => _WindowsTokenAuthScreenState();
}

class _WindowsTokenAuthScreenState extends State<WindowsTokenAuthScreen> {
  final _tokenController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submitToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вставь token')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthTokenVault.save(token);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => DocumentsScreen(
            authBanner: 'Windows Token Auth: Авторизация успешна',
            authToken: token,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить token: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Windows Token Auth')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Вставь access token и нажми «Открыть документы».',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Access token',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submitToken,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Открыть документы'),
                ),
              ],
            ),
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
  void _finishFlow(String banner, String token) {
    if (_finished || _showDocuments) return;
    if (!mounted) return;
    setState(() {
      _finished = true;
      _successBanner = banner;
      _authToken = token;
      _showDocuments = true;
    });
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
  bool _showDocuments = false;
  String? _lastRedirectUri;
  String? _successBanner;
  String? _authToken;
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
    if (!_isRedirectUri(uri) || _finished || _isSubmitting) return;

    final raw = uri.toString();
    if (_lastRedirectUri == raw) return;
    _lastRedirectUri = raw;

    _codeController.text = raw;
    unawaited(_exchangeCode());
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
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_isSubmitting || _finished || _showDocuments) {
        return;
      }
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

  String? _extractAccessToken(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final token = decoded['access_token'];
        if (token is String && token.isNotEmpty) {
          return token;
        }
      }
    } catch (_) {
      // ignore invalid json bodies
    }
    return null;
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
      setState(() {
        _status = 'Таймаут обмена кода на токен (TOKEN_EXCHANGE_TIMEOUT)';
      });
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

      final accessToken = _extractAccessToken(response.body);
      final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
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
        await AuthTokenVault.save(accessToken!);
        _finishFlow('Web Auth: Авторизация успешна', accessToken);
      } else if (mounted && response.statusCode == 200) {
        setState(() {
          _status =
              'Ответ token endpoint: HTTP_200, но access_token не найден (TOKEN_MISSING)';
        });
      } else if (mounted) {
        setState(() {
          _status =
              'Ошибка обмена кода: HTTP_${response.statusCode}${response.body.isNotEmpty ? ', ${response.body}' : ''}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ошибка обмена: $e';
        });
      }
    } finally {
      watchdog.cancel();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showDocuments) {
      return DocumentsScreen(
        authBanner: _successBanner,
        authToken: _authToken,
      );
    }

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
                      if (!_isSubmitting && !_finished)
                        FilledButton.tonal(
                          onPressed: _openAuth,
                          child: const Text('Открыть авторизацию снова'),
                        ),
                      if (!_isSubmitting && !_finished && _codeController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton(
                            onPressed: _exchangeCode,
                            child: const Text('Повторить обмен'),
                          ),
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

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.authBanner, this.authToken});

  final String? authBanner;
  final String? authToken;

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
      appBar: AppBar(
        title: const Text('Электронные перевозочные документы'),
        bottom: widget.authToken == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Token: ${widget.authToken}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                      Text(
                        'Скопировать токен →',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.white70),
                      ),
                      IconButton(
                        tooltip: 'Копировать токен',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.authToken!),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Токен скопирован')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
      ),
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
