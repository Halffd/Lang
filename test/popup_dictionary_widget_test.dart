// Integration: PopupDictionaryScope + controller end-to-end flow.
// Pumps the real scope wrapper, drives pointer events through the
// Listener, and verifies the popup overlay appears, dedupes and
// closes.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PopupDictionaryController controller;

  setUp(() {
    controller = PopupDictionaryController.instance;
    controller.lookupBuilder = (context, lookup) async {
      return Text('popup:${lookup.term}');
    };
  });

  tearDown(() {
    controller.lookupBuilder = null;
    controller.config = PopupDictionaryConfig();
    controller.currentRouteName = '';
    controller.hide();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    PopupDictionaryConfig? config,
  }) async {
    controller.config =
        config ??
        PopupDictionaryConfig(
          trigger: PopupTrigger.click,
          scanLength: 16,
          scanDepth: 0,
        );
    controller.currentRouteName = 'analyze';
    await tester.pumpWidget(
      const MaterialApp(
        home: PopupDictionaryScope(
          child: Scaffold(body: Center(child: Text('日本語のテスト'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('click trigger opens popup with extracted term', (tester) async {
    await pumpApp(tester);

    // click on the text
    await tester.tap(find.text('日本語のテスト'));
    await tester.pumpAndSettle();

    expect(controller.isPopupOpen, isTrue);
    expect(find.text('popup:日本語のテスト'), findsOneWidget);
  });

  testWidgets('route gate blocks popup on other screens', (tester) async {
    await pumpApp(
      tester,
      config: PopupDictionaryConfig(
        trigger: PopupTrigger.click,
        allowedScreens: {PopupScreenScope.reader},
      ),
    );

    await tester.tap(find.text('日本語のテスト'));
    await tester.pumpAndSettle();

    expect(controller.isPopupOpen, isFalse);
    expect(find.text('popup:日本語のテスト'), findsNothing);
  });

  testWidgets('dismiss catcher closes the popup', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('日本語のテスト'));
    await tester.pumpAndSettle();
    expect(controller.isPopupOpen, isTrue);

    // tap the full-screen dismiss catcher (far from the popup card)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(controller.isPopupOpen, isFalse);
    expect(find.text('popup:日本語のテスト'), findsNothing);
  });

  testWidgets('double click trigger needs two clicks', (tester) async {
    await pumpApp(
      tester,
      config: PopupDictionaryConfig(trigger: PopupTrigger.doubleClick),
    );

    // mouse pointer: the double-click trigger only accepts mice
    final center = tester.getCenter(find.text('日本語のテスト'));

    // first click: no popup (double-click window is 350ms)
    final g1 = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.isPopupOpen, isFalse);

    // second click within the window: popup
    final g2 = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await g2.up();
    await tester.pumpAndSettle();
    expect(controller.isPopupOpen, isTrue);
    expect(find.text('popup:日本語のテスト'), findsOneWidget);
  });

  testWidgets('builder returning null keeps popup closed', (tester) async {
    controller.lookupBuilder = (context, lookup) async => null;
    await pumpApp(tester);

    await tester.tap(find.text('日本語のテスト'));
    await tester.pumpAndSettle();

    expect(controller.isPopupOpen, isFalse);
  });

  testWidgets('hide during in-flight lookup does not resurrect popup', (
    tester,
  ) async {
    final completer = Completer<Widget?>();
    controller.lookupBuilder = (context, lookup) => completer.future;

    await pumpApp(tester);
    await tester.tap(find.text('日本語のテスト'));
    await tester.pump(); // lookup now in flight
    expect(controller.isPopupOpen, isFalse);

    // dismiss while lookup is in flight
    controller.hide();
    completer.complete(Text('popup:${'日本語のテスト'}'));
    await tester.pumpAndSettle();

    expect(controller.isPopupOpen, isFalse);
    expect(find.text('popup:日本語のテスト'), findsNothing);
  });
}
