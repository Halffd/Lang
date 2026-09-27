import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_zoom.dart';
import 'package:lang/presentation/widgets/font_zoom_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage);
  });

  Future<void> pumpZoom(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: FontZoomScope(child: Scaffold(body: Text('sample'))),
        ),
      ),
    );
    await tester.pump();
  }

  /// Sends a real ctrl+wheel notch through the framework's pointer-signal
  /// path. [dy] negative = wheel up.
  Future<void> ctrlScroll(WidgetTester tester, double dy) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final signal = PointerScrollEvent(
      position: tester.getCenter(find.text('sample')),
      scrollDelta: Offset(0, dy),
      kind: PointerDeviceKind.mouse,
    );
    tester.binding.handlePointerEvent(signal);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // the handler debounces for 60ms before applying
    await tester.pump(const Duration(milliseconds: 80));
  }

  group('ctrl+scroll zoom', () {
    testWidgets('scroll up increases the font, scroll down decreases it', (
      tester,
    ) async {
      await pumpZoom(tester);
      expect(appState.fontSizeMultiplier, 1.0);

      // negative dy = wheel away from the user = zoom in (browser behaviour)
      await ctrlScroll(tester, -40);
      expect(
        appState.fontSizeMultiplier,
        greaterThan(1.0),
        reason: 'wheel up must zoom in',
      );

      final up = appState.fontSizeMultiplier;
      await ctrlScroll(tester, 40);
      expect(
        appState.fontSizeMultiplier,
        lessThan(up),
        reason: 'wheel down must zoom out',
      );
    });

    testWidgets('one notch moves the zoom by the configured step', (
      tester,
    ) async {
      await pumpZoom(tester);
      await ctrlScroll(tester, -40);
      expect(
        appState.fontSizeMultiplier,
        closeTo(1.0 + FontZoom.defaultStep, 0.001),
      );

      appState.setFontZoomStep(0.25);
      await ctrlScroll(tester, -40);
      expect(appState.fontSizeMultiplier, closeTo(1.35, 0.001));
    });

    testWidgets('clamps at both ends', (tester) async {
      await pumpZoom(tester);
      appState.setFontSizeMultiplier(FontZoom.maxMultiplier);
      await ctrlScroll(tester, -40);
      expect(appState.fontSizeMultiplier, FontZoom.maxMultiplier);

      appState.setFontSizeMultiplier(FontZoom.minMultiplier);
      await ctrlScroll(tester, 40);
      expect(appState.fontSizeMultiplier, FontZoom.minMultiplier);
    });

    testWidgets('scroll without ctrl does not zoom', (tester) async {
      await pumpZoom(tester);
      final signal = PointerScrollEvent(
        position: tester.getCenter(find.text('sample')),
        scrollDelta: const Offset(0, -40),
        kind: PointerDeviceKind.mouse,
      );
      tester.binding.handlePointerEvent(signal);
      await tester.pump(const Duration(milliseconds: 80));
      expect(appState.fontSizeMultiplier, 1.0);
    });

    testWidgets('1.75x preset is reachable and clamps in range', (
      tester,
    ) async {
      await pumpZoom(tester);
      expect(FontZoom.presets, contains(1.75));
      appState.setFontZoomPreset(1.75);
      expect(appState.fontSizeMultiplier, 1.75);
    });
  });
}
