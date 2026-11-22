// Keyboard shortcuts on the analyse screen:
//   +/-            definition text size
//   Shift +/-      card column count
//   Ctrl  +/-      every text size
// Plus the collapsible search bar (collapse button + auto-hide while
// scrolling down).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';

void main() {
  late StorageService storage;
  late SRSService srs;
  late AppState appState;
  late AnalyzerProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    srs = SRSService(storage);
    await srs.initialize();
    appState = AppState(storage);
    provider = AnalyzerProvider();
    provider.testSetAnalyzedWords(List.generate(12, (i) => AnalyzedWord(word: '単語$i')));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: ChangeNotifierProvider<SRSService>.value(
          value: srs,
          child: ChangeNotifierProvider<AnalyzerProvider>.value(
            value: provider,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AnalyzeScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Press [key] with the given modifiers.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
    bool ctrl = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  group('analyse screen zoom shortcuts', () {
    testWidgets('plus/minus changes the definition text size', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(appState.fontSettings.translations, 1.0);

      await press(tester, LogicalKeyboardKey.equal);
      expect(appState.fontSettings.translations, greaterThan(1.0));

      await press(tester, LogicalKeyboardKey.minus);
      expect(appState.fontSettings.translations, closeTo(1.0, 0.001));
    });

    testWidgets('shift plus/minus changes the column count', (tester) async {
      await pumpScreen(tester);
      final before = provider.itemsPerRow;

      await press(tester, LogicalKeyboardKey.equal, shift: true);
      expect(provider.itemsPerRow, before + 1);

      await press(tester, LogicalKeyboardKey.minus, shift: true);
      expect(provider.itemsPerRow, before);
    });

    testWidgets('ctrl plus/minus changes every text size', (tester) async {
      await pumpScreen(tester);
      expect(appState.fontSizeMultiplier, 1.0);

      await press(tester, LogicalKeyboardKey.equal, ctrl: true);
      expect(appState.fontSizeMultiplier, greaterThan(1.0));

      await press(tester, LogicalKeyboardKey.minus, ctrl: true);
      expect(appState.fontSizeMultiplier, closeTo(1.0, 0.001));
    });

    testWidgets('the column count stays within bounds', (tester) async {
      await pumpScreen(tester);

      // shrink to the minimum
      for (var i = 0; i < 20; i++) {
        await press(tester, LogicalKeyboardKey.minus, shift: true);
      }
      expect(provider.itemsPerRow, 1);

      // grow to the maximum
      for (var i = 0; i < 20; i++) {
        await press(tester, LogicalKeyboardKey.equal, shift: true);
      }
      expect(provider.itemsPerRow, 12);
    });
  });

  group('analyse screen collapsible search bar', () {
    testWidgets('the collapse button hides the input field', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse search bar'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Expand search bar'), findsOneWidget);
    });

    testWidgets('the expand button brings the input field back', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Collapse search bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand search bar'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
