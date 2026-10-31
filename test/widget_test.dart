import 'package:astralkeytest/main.dart';
import 'package:astralkeytest/src/core/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Welcome screen scrolls on a small display', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AstralKeyTestApp());

    expect(find.text('Добро пожаловать\nв АстралКлюч'), findsOneWidget);
    expect(find.text('Войти с Астрал'), findsOneWidget);
    expect(find.text('Версия $kAppVersion'), findsOneWidget);

    await tester.ensureVisible(find.text('Версия $kAppVersion'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
