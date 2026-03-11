import 'package:astralkeytest/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders expected fields', (WidgetTester tester) async {
    await tester.pumpWidget(const AstralKeyTestApp());

    expect(find.text('Добро пожаловать'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
