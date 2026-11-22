// Widget test for the live-OCR overlay: the source text and the
// translation are shown, the translation line can be turned off, and
// double-tapping dismisses the overlay.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/live_ocr_overlay.dart';

void main() {
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required String source,
    String? translation,
    String? error,
    bool showTranslation = true,
    VoidCallback? onDismiss,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LiveOcrOverlay(
                sourceText: source,
                translation: translation,
                error: error,
                showTranslation: showTranslation,
                onDismiss: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows the source text', (tester) async {
    await pumpOverlay(tester, source: '日本語');
    expect(find.text('日本語'), findsOneWidget);
  });

  testWidgets('shows the translation under the source', (tester) async {
    await pumpOverlay(tester, source: '日本語', translation: 'Japanese');
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('hides the translation when it is switched off', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      source: '日本語',
      translation: 'Japanese',
      showTranslation: false,
    );
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('Japanese'), findsNothing);
  });

  testWidgets('does not show a translation identical to the source', (
    tester,
  ) async {
    await pumpOverlay(tester, source: '日本語', translation: '日本語');
    expect(find.text('日本語'), findsOneWidget);
  });

  testWidgets('shows no translation line while it is pending', (
    tester,
  ) async {
    await pumpOverlay(tester, source: '日本語');
    expect(find.text('日本語'), findsOneWidget);
  });

  testWidgets('double tap dismisses the overlay', (tester) async {
    var dismissed = false;
    await pumpOverlay(
      tester,
      source: '日本語',
      onDismiss: () => dismissed = true,
    );

    await tester.tap(find.text('日本語'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('日本語'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(dismissed, isTrue);
    // let the double-tap timer expire so none is pending at teardown
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows the error instead of the text when it fails', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      source: '',
      error: 'Screen capture failed',
    );
    expect(find.textContaining('Screen capture failed'), findsOneWidget);
  });

  testWidgets('the error prefix follows the app language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              const LiveOcrOverlay(
                sourceText: '',
                error: 'Screen capture failed',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('ライブOCR'), findsOneWidget);
  });

  testWidgets('works when nested in an AnimatedBuilder under a Stack', (
    tester,
  ) async {
    // this mirrors how the app shell mounts the overlay: the builder
    // sits between the Stack and the Positioned overlay
    var text = '日本語';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AnimatedBuilder(
                animation: ValueNotifier<int>(0),
                builder: (context, _) {
                  return LiveOcrOverlay(sourceText: text);
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('日本語'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overlay can be dragged', (tester) async {
    await pumpOverlay(tester, source: '日本語');
    final before = tester.getTopLeft(find.text('日本語'));

    await tester.drag(find.text('日本語'), const Offset(60, 40));
    await tester.pump();
    // the gesture detector's double-tap timer outlives the drag: let it
    // expire so no timer is pending when the tree is torn down
    await tester.pump(const Duration(seconds: 1));

    final after = tester.getTopLeft(find.text('日本語'));
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });
}
