import 'package:astralkeytest/main.dart';
import 'package:astralkeytest/src/widgets/duo_display_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/duo_regions.dart';

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
    const innerDisplay = Size(2007, 2853);
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

    tester.view.physicalSize = innerDisplay;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopLeft(first).dx),
    );

    tester.view.physicalSize = innerDisplay.flipped;
    _setSafeArea(
      tester,
      const FakeViewPadding(left: 120, right: 120, bottom: 72),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dx, greaterThan(40));
    expect(tester.getTopRight(second).dx, lessThan(911));
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);

    tester.view.physicalSize = const Size(870, 2007);
    await tester.pumpAndSettle();
    expect(find.text('Документ №2'), findsOneWidget);
    final sign = find.widgetWithText(FilledButton, 'Подписать');
    expect(tester.getBottomRight(sign).dy, lessThan(669 - 24));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
  });

  testWidgets('Duo fold keeps actions and the open document on one pane', (
    tester,
  ) async {
    _configureView(tester);
    tester.view.physicalSize = const Size(2853, 2007);
    _setSafeArea(tester, const FakeViewPadding(left: 210, top: 60, bottom: 72));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var requests = 0;
    messenger.setMockMethodCallHandler(duoRegionChannel, (call) async {
      expect(call.method, 'requestRegions');
      requests++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(duoRegionChannel, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            _largeText(context, DuoDisplayLayout(child: child!)),
        home: const DocumentsScreen(authToken: 'fixture-token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);
    final first = find.widgetWithText(FilledButton, 'Документ №1');
    final second = find.widgetWithText(FilledButton, 'Документ №2');
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);

    const vertical = Rect.fromLTRB(444, 20, 464, 645);
    await sendDuoRegions([vertical]);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dx, greaterThan(vertical.right));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(find.byTooltip('Копировать токен').hitTestable(), findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();

    const horizontal = Rect.fromLTRB(70, 300, 940, 320);
    await sendDuoRegions([horizontal]);
    await tester.pumpAndSettle();
    expect(find.byType(DocumentDetailsScreen), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppBar)).dy, horizontal.bottom);
    final sign = find.widgetWithText(FilledButton, 'Подписать');
    expect(tester.getBottomRight(sign).dy, lessThan(669 - 24));

    await sendDuoRegions([]);
    await tester.pumpAndSettle();
    expect(find.text('Документ №2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
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
