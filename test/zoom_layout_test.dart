import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_zoom.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout regression harness for the global text zoom.
///
/// Item 2: text and widgets went out of bounds when zoomed in. Zoom scales
/// glyphs via [fs] but not the boxes around them, so the check is simply:
/// render the screen at the maximum zoom on the narrowest supported surface
/// and assert Flutter reports no overflow.
void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage);
  });

  Future<void> pumpAtZoom(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(320, 640),
  }) async {
    appState.setFontSizeMultiplier(FontZoom.maxMultiplier);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  group('zoomed layout does not overflow', () {
    testWidgets('a row of icons keeps its actions on screen', (tester) async {
      await pumpAtZoom(
        tester,
        Row(
          children: [
            for (final label in ['a', 'bb', 'ccc', 'dddd']) ...[
              Text(label, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fixed-width row overflows, proving the harness works', (
      tester,
    ) async {
      // Guards against a false-negative harness: this layout *must* be
      // reported so we know takeException() is wired up.
      await pumpAtZoom(
        tester,
        Row(
          children: [
            for (final label in ['a', 'bb', 'ccc', 'dddd', 'eeeee'])
              SizedBox(width: 90, child: Text(label)),
          ],
        ),
      );
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('long text wraps instead of overflowing', (tester) async {
      await pumpAtZoom(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'a very long single line of text that would overflow a row',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('zoom bounds are respected by the settings widgets', () {
    testWidgets('a slider at max zoom stays inside its parent', (tester) async {
      await pumpAtZoom(
        tester,
        Row(
          children: [
            const SizedBox(width: 110, child: Text('Ctrl+scroll step')),
            Expanded(
              child: Slider(
                value: 0.5,
                min: 0.02,
                max: 0.5,
                divisions: 24,
                onChanged: (_) {},
              ),
            ),
            SizedBox(
              width: 52,
              child: Text('+0.50x', style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('real screens survive max zoom', () {
    testWidgets('document reader at max zoom on a narrow phone', (
      tester,
    ) async {
      await pumpAtZoom(
        tester,
        const DocumentReaderScreen(),
        size: const Size(320, 640),
      );
      // with text entered, the reader view is on screen too
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Paste or type text to read\u2026',
        ),
        'これはzoomed textのテストです。',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
