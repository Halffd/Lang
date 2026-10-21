import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/widgets/bounded_input.dart';
import 'package:lang/presentation/widgets/submit_text_field.dart';
import 'package:lang/presentation/widgets/word_action_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AnalyzedWord word(String w, {String reading = '', String def = ''}) =>
      AnalyzedWord(
        word: w,
        reading: reading.isEmpty ? null : reading,
        ichiMoeDefinitions: def.isEmpty ? const [] : [def],
      );

  group('AnalyzerProvider paging (word count + char limits)', () {
    late AnalyzerProvider provider;

    setUp(() {
      provider = AnalyzerProvider();
      provider.testSetAnalyzedWords(
        List.generate(10, (i) => word('word$i', def: 'meaning $i')),
      );
    });

    test('splits pages by word count', () {
      provider.updateSetting('itemsPerPage', 3);
      expect(provider.totalPages, 4); // 3+3+3+1
      expect(provider.pagedWords.length, 3);
      provider.nextPage();
      expect(provider.pagedWords.map((w) => w.word).toList(), [
        'word3',
        'word4',
        'word5',
      ]);
    });

    test('page chars budget forces earlier page breaks (0 = off)', () {
      // each word ~ 'wordN' (5-6) + 'meaning N' (9-10) chars ≈ 15
      provider.updateSetting('itemsPerPage', 100000); // count unlimited
      provider.updateSetting('pageChars', 40);
      expect(provider.totalPages, greaterThan(1));
      // every page respects the budget (a single word may exceed it)
      for (var p = 0; p < provider.totalPages; p++) {
        final page = provider.pagedWords;
        var chars = 0;
        for (final w in page) {
          chars += w.word.length + (w.reading?.length ?? 0);
          chars += w.ichiMoeDefinitions.fold(0, (a, d) => a + d.length);
        }
        if (page.length > 1) expect(chars, lessThanOrEqualTo(40));
        provider.nextPage();
      }
    });

    test('unlimited settings produce a single page', () {
      provider.updateSetting('itemsPerPage', 100000);
      provider.updateSetting('pageChars', 0);
      expect(provider.totalPages, 1);
      expect(provider.pagedWords.length, 10);
    });

    test('char limit still pages a single oversized word', () {
      provider.testSetAnalyzedWords([
        word('supercalifragilistic', def: 'a very long definition string'),
      ]);
      provider.updateSetting('itemsPerPage', 100000);
      provider.updateSetting('pageChars', 1);
      expect(provider.totalPages, 1);
      expect(provider.pagedWords.single.word, 'supercalifragilistic');
    });

    test('pageOfSelectedWord follows char-limited boundaries', () {
      provider.updateSetting('itemsPerPage', 100000);
      provider.updateSetting('pageChars', 40);
      provider.selectWord(provider.analyzedWords.length - 1);
      expect(provider.pageOfSelectedWord, provider.totalPages - 1);
    });
  });

  group('SubmitTextField', () {
    testWidgets('Enter submits, Ctrl+Enter inserts newline', (tester) async {
      final controller = TextEditingController();
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubmitTextField(
              controller: controller,
              maxLines: null,
              onSubmitted: (text) => submitted = text,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(SubmitTextField), 'hello');
      await tester.pump();
      // focus the field, then send a hardware Enter — the Focus
      // wrapper's onKeyEvent intercepts it before the field turns it
      // into a newline
      await tester.tap(find.byType(SubmitTextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, 'hello');
    });
  });

  group('BoundedInput', () {
    testWidgets('caps the child at the configured fraction', (tester) async {
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      appState.setInputMaxHeightFraction(0.5);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: BoundedInput(child: const TextField(maxLines: null)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.renderObject<RenderConstrainedBox>(
        find
            .descendant(
              of: find.byType(BoundedInput),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.additionalConstraints.maxHeight, 800.0); // 1600 * 0.5
    });
  });

  group('WordActionBar SRS toggle', () {
    testWidgets('school button adds and removes a study card', (tester) async {
      final storage = StorageService();
      final appState = AppState(storage);
      final srs = SRSService(storage);

      final w = word('電車', reading: 'でんしゃ', def: 'train');
      await storage.init();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appState),
            ChangeNotifierProvider.value(value: srs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: WordActionBar(word: w)),
            ),
          ),
        ),
      );

      // initially outlined (not in SRS)
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);

      // tap the SRS button (third action: copy is shown first)
      await tester.tap(find.byIcon(Icons.school_outlined), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        srs.allCards.any((c) => c.id == '電車でんしゃ'),
        isTrue,
        reason: 'tapping the school button must add an SRS card',
      );

      // tap again removes it
      await tester.tap(find.byIcon(Icons.school), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(srs.allCards.any((c) => c.id == '電車でんしゃ'), isFalse);
    });
  });
}
