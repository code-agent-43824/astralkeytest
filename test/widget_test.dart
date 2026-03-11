import 'package:astralkeytest/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders expected fields', (WidgetTester tester) async {
    await tester.pumpWidget(const AstralKeyTestApp());

    expect(find.text('Добро пожаловать'), findsOneWidget);
    expect(find.text('E-mail'), findsNWidgets(2)); // сегмент и label поля
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('v.0.0.2'), findsOneWidget);
  });
}
