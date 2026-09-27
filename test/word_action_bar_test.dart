import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/presentation/widgets/word_action_bar.dart';
import 'package:lang/utils/srs_conversion_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState appState;
  late SRSService srs;

  final word = AnalyzedWord(
    word: '日本語',
    reading: 'にほんご',
    ichiMoeDefinitions: ['Japanese language', 'the Japanese language'],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage);
    srs = SRSService(storage);
    await srs.initialize();
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<SRSService>.value(value: srs),
        ],
        child: MaterialApp(
          home: Scaffold(body: WordActionBar(word: word)),
        ),
      ),
    );
    await tester.pump();
  }

  group('WordActionBar', () {
    testWidgets('offers copy, favorites, anki and learned', (tester) async {
      await pumpBar(tester);

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('icons are 60% of the previous 20px', (tester) async {
      await pumpBar(tester);

      expect(kWordActionIconSize, 12.0);
      final icon = tester.widget<Icon>(find.byIcon(Icons.copy));
      expect(icon.size, kWordActionIconSize);
    });

    testWidgets('tap targets stay larger than the glyph', (tester) async {
      await pumpBar(tester);

      // shrinking the icon must not shrink the touch area below 32px
      expect(kWordActionTapTarget.width, greaterThan(kWordActionIconSize));
      expect(kWordActionTapTarget.height, greaterThan(kWordActionIconSize));
    });

    testWidgets('favorite toggles on and off', (tester) async {
      await pumpBar(tester);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(appState.favoriteWords, contains('日本語'));
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      expect(appState.favoriteWords, isNot(contains('日本語')));
    });

    testWidgets('anki toggles on and off', (tester) async {
      await pumpBar(tester);

      await tester.tap(find.byIcon(Icons.book_outlined));
      await tester.pump();
      expect(appState.ankiWords, contains('日本語'));

      await tester.tap(find.byIcon(Icons.book));
      await tester.pump();
      expect(appState.ankiWords, isNot(contains('日本語')));
    });

    testWidgets('learned adds an SRS card keyed by term+reading', (
      tester,
    ) async {
      await pumpBar(tester);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();

      expect(srs.allCards.any((c) => c.id == '日本語にほんご'), isTrue);
      expect(find.byIcon(Icons.school), findsOneWidget);

      await tester.tap(find.byIcon(Icons.school));
      await tester.pump();
      expect(srs.allCards.any((c) => c.id == '日本語にほんご'), isFalse);
    });

    testWidgets('copy puts word and reading on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpBar(tester);
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(copied, '日本語 (にほんご)');
    });

    testWidgets('showSave:false hides the duplicate save button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<SRSService>.value(value: srs),
          ],
          child: MaterialApp(
            home: Scaffold(body: WordActionBar(word: word, showSave: false)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      // the four requested actions are still there
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });
  });

  group('SRSConversionUtils.analyzedWordToSRSCard', () {
    test('uses the same id convention as the dictionary converter', () {
      final card = SRSConversionUtils.analyzedWordToSRSCard(word);
      expect(card.id, '日本語にほんご');
      expect(card.word, '日本語');
      expect(card.reading, 'にほんご');
    });

    test('joins the first two definitions', () {
      final card = SRSConversionUtils.analyzedWordToSRSCard(word);
      expect(card.meaning, 'Japanese language; the Japanese language');
    });

    test('falls back when there are no definitions', () {
      final card = SRSConversionUtils.analyzedWordToSRSCard(
        AnalyzedWord(word: 'x'),
      );
      expect(card.meaning, 'No definition available');
      expect(card.reading, '');
    });

    test('marks a long definition list as truncated', () {
      final card = SRSConversionUtils.analyzedWordToSRSCard(
        AnalyzedWord(word: 'x', ichiMoeDefinitions: ['a', 'b', 'c']),
      );
      expect(card.meaning, 'a; b...');
    });

    test('analyzed word is an SRSCard', () {
      expect(SRSConversionUtils.analyzedWordToSRSCard(word), isA<SRSCard>());
    });
  });
}
