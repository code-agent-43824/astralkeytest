import 'package:astralkeytest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Welcome and PIN controls fit a narrow window with large text', (
    tester,
  ) async {
    _configureView(tester);
    tester.view.physicalSize = const Size(1320, 2868);
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(builder: _largeText, home: const AuthMethodScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Войти с Астрал').hitTestable(), findsOneWidget);

    tester.view.physicalSize = const Size(750, 1110);
    _setSafeArea(tester, const FakeViewPadding(left: 48, right: 48));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Войти с Астрал'));
    expect(find.text('Войти с Астрал').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        builder: _largeText,
        home: const PinSetupScreen(
          token: 'fixture-token',
          allowBiometric: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final zero = find.widgetWithText(FilledButton, '0');
    await tester.ensureVisible(zero);
    expect(zero.hitTestable(), findsOneWidget);
    expect(tester.getSize(zero).width, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Documents reflow across Duo displays and protect safe areas', (
    tester,
  ) async {
    _configureView(tester);
    tester.view.physicalSize = const Size(1398, 2034);
    _setSafeArea(tester, const FakeViewPadding(top: 150, bottom: 102));
    await tester.pumpWidget(
      MaterialApp(
        builder: _largeText,
        home: DocumentsScreen(authToken: List.filled(40, 'fixture').join('.')),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.widgetWithText(FilledButton, 'Документ №1');
    final second = find.widgetWithText(FilledButton, 'Документ №2');
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(find.byTooltip('Копировать токен').hitTestable(), findsOneWidget);

    tester.view.physicalSize = const Size(1878, 2670);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopLeft(first).dx),
    );

    tester.view.physicalSize = const Size(2670, 1878);
    _setSafeArea(
      tester,
      const FakeViewPadding(left: 120, right: 120, bottom: 72),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dx, greaterThan(40));
    expect(tester.getTopRight(second).dx, lessThan(850));
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);

    tester.view.physicalSize = const Size(870, 1878);
    await tester.pumpAndSettle();
    expect(find.text('Документ №2'), findsOneWidget);
    final sign = find.widgetWithText(FilledButton, 'Подписать');
    expect(tester.getBottomRight(sign).dy, lessThan(626 - 24));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
  });
}

Widget _largeText(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  );
}

void _configureView(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

void _setSafeArea(WidgetTester tester, FakeViewPadding padding) {
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
}
