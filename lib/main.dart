import 'dart:convert';

import 'package:astralkeytest/src/core/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
      home: const LoginScreen(),
    );
  }
}

enum LoginMethod { email, phone }

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _baseUrl = 'https://identity.demo.astral-dev.ru';
  static const _captchaBypassEnabledForDemo = true;

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

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Результат входа'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        final errors = decoded['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
            if (value is String && value.trim().isNotEmpty) {
              return value;
            }
          }
        }
      }
    } catch (_) {
      // ignore parse errors and fallback below
    }

    return 'Ошибка авторизации (HTTP $statusCode)';
  }

  String _extractBypassToken(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      throw Exception('пустой токен обхода капчи');
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {
      // fallback to raw body below
    }

    return trimmed.replaceAll('"', '');
  }

  Future<void> _applyDemoCaptchaBypass() async {
    if (!_captchaBypassEnabledForDemo) return;

    final tokenResponse = await http.get(
      Uri.parse('$_baseUrl/api/integrations/captcha/exclude'),
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception(
        'не удалось получить токен обхода капчи (HTTP ${tokenResponse.statusCode})',
      );
    }

    final bypassToken = _extractBypassToken(tokenResponse.body);

    final disableUri = Uri.parse(
      '$_baseUrl/api/accounts/captcha/disable',
    ).replace(queryParameters: {'token': bypassToken});

    final disableResponse = await http.get(disableUri);
    if (disableResponse.statusCode != 200) {
      throw Exception(
        'не удалось отключить капчу (HTTP ${disableResponse.statusCode})',
      );
    }
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _applyDemoCaptchaBypass();

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

      if (response.statusCode == 200) {
        await _showMessage('OK');
      } else {
        await _showMessage(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      await _showMessage('Сетевая ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
      appBar: AppBar(title: const Text('Astral Key Test')),
      body: Stack(
        children: [
          Center(
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
                      Text(
                        'Добро пожаловать',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
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
                            ? [FilteringTextInputFormatter.digitsOnly, _PhoneMaskFormatter()]
                            : const [],
                        decoration: InputDecoration(
                          labelText:
                              _method == LoginMethod.email ? 'E-mail' : 'Телефон',
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
          Positioned(
            right: 12,
            bottom: 10,
            child: Opacity(
              opacity: 0.7,
              child: Text(
                kAppVersion,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
