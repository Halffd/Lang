import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';

void main() {
  AnalyzedWord word(String w) => AnalyzedWord(word: w);

  group('DictionaryEntry structured definitions', () {
    // Regression: structured-content nodes went through Map.toString(),
    // producing Dart literal syntax that no jsonDecode can parse, so the
    // renderer fell back to showing the raw JSON string on the card.

    test('json-string columns with node elements round-trip as json', () {
      const raw =
          '[{"tag":"ul","lang":"ja","data":{"content":"sense-note"},'
          '"content":[{"tag":"li","content":"gone"}]}]';
      final entry = DictionaryEntry.fromJson({
        'term': 'example',
        'reading': 'ignored',
        'definitions': raw,
      });
      expect(entry.definitions, hasLength(1));
      // critical: the definition must parse back as valid JSON
      expect(() => jsonDecode(entry.definitions.first), returnsNormally);
      final decoded = jsonDecode(entry.definitions.first);
      expect((decoded as List).first['tag'], 'ul');
    });

    test('already-decoded lists with nodes are re-encoded as json', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'example',
        'reading': 'ignored',
        'definitions': [
          {'tag': 'li', 'content': 'sense-a'},
        ],
      });
      expect(entry.definitions, hasLength(1));
      expect(() => jsonDecode(entry.definitions.first), returnsNormally);
    });

    test('plain gloss lists stay as plain strings', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'dog',
        'reading': 'dog',
        'definitions': '["a cat", "a dog"]',
      });
      expect(entry.definitions, ['a cat', 'a dog']);
    });

    test('non-json strings pass through untouched', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'dog',
        'reading': 'dog',
        'definitions': 'just a gloss',
      });
      expect(entry.definitions, ['just a gloss']);
    });

    test('tag lists of plain strings keep working', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'x',
        'reading': 'r',
        'definitions': [],
        'termTags': '["noun", "common"]',
      });
      expect(entry.termTags, ['noun', 'common']);
    });
  });

  group('measureSearchFieldMaxHeight (pinned search bar field cap)', () {
    test('shrinks when results appear so the chips row still fits', () {
      final bare = measureSearchFieldMaxHeight(
        hasResults: false,
        maxHeightFraction: 0.5,
        viewportHeight: 800,
      );
      final withResults = measureSearchFieldMaxHeight(
        hasResults: true,
        maxHeightFraction: 0.5,
        viewportHeight: 800,
      );
      expect(withResults, lessThan(bare));
      // 800 * 0.5 = 400 budget; chips reserve 50 + padding 28 + 28.
      expect(withResults, 400 - 50 - 28 - 28);
    });

    test('follows the user-configured viewport fraction', () {
      final half = measureSearchFieldMaxHeight(
        maxHeightFraction: 0.5,
        viewportHeight: 800,
      );
      final quarter = measureSearchFieldMaxHeight(
        maxHeightFraction: 0.25,
        viewportHeight: 800,
      );
      expect(quarter, lessThan(half));
      // never below the minimum single-line height
      expect(
        measureSearchFieldMaxHeight(
          maxHeightFraction: 0.1,
          viewportHeight: 400,
        ),
        greaterThanOrEqualTo(52),
      );
    });
  });

  group('AnalyzeScreen search bar layout', () {
    // Regression (screenshot bug): the pinned header forced its content
    // into a pre-measured fixed height; whenever the estimate came up
    // short (zoomed "Analyze Text" button wider than the assumed 130px,
    // theme contentPadding scaling with zoom) the Column painted past
    // the header extent: "BOTTOM OVERFLOWED BY 42 PIXELS". The bar is now
    // a self-sizing box above the scroll area, so it cannot clip itself.
    //
    // No FlutterError.onError override is needed: the test binding
    // already fails the test on any framework exception, including
    // RenderFlex overflow errors. Overriding onError here would break
    // the binding's own error plumbing (it needs onError to record
    // _pendingExceptionDetails).
    testWidgets('no overflow with zoomed text and results at 1274x640', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final srs = SRSService(storage);
      await srs.initialize();
      // Same shape as the bug screenshot: 1274x640 window, zoomed font
      // (1.75x ui multiplier), analysis results present.
      final appState = AppState(storage);
      appState.setFontSizeMultiplier(1.75);
      final provider = AnalyzerProvider();
      provider.testSetAnalyzedWords(List.generate(24, (i) => word('単語$i')));
      provider.testSetSentences({'単語0': '古くからの友人として'});

      await tester.binding.setSurfaceSize(const Size(1274, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      // If the search bar overflowed, the binding records the RenderFlex
      // overflow error and fails this test during pumpAndSettle.
      await tester.pumpAndSettle();

      // The bar and its content made it through layout without errors;
      // sanity-check the pieces the bug screenshot showed.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('24'),
        findsWidgets,
        reason: 'words-analyzed stat chip is visible',
      );
      expect(find.text('Analyze Text'), findsOneWidget);
    });
  });
}
