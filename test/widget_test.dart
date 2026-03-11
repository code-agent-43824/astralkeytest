import 'package:astralkeytest/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Auth method screen renders controls', (WidgetTester tester) async {
    await tester.pumpWidget(const AstralKeyTestApp());

    expect(find.text('Выбор способа аутентификации'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Prod (пока недоступно)'), findsOneWidget);
    expect(find.text('API Auth'), findsOneWidget);
    expect(find.text('Web Auth'), findsOneWidget);
    expect(find.text('v.0.0.5'), findsOneWidget);
  });
}
