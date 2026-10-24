import 'package:flutter_test/flutter_test.dart';
import 'package:lang_core/lang_core.dart';

void main() {
  group('LanguageDetector (lang_core)', () {
    final detector = LanguageDetector();

    test('kana means japanese even without kanji', () {
      expect(detector.detect('こんにちは'), 'ja');
    });

    test('han-only text is chinese, not japanese', () {
      expect(detector.detect('中文测试'), 'zh');
    });

    test('hangul, cyrillic, latin', () {
      expect(detector.detect('한국어'), 'ko');
      expect(detector.detect('привет'), 'ru');
      expect(detector.detect('hello world'), 'en');
    });
  });

  group('Tokenizer (lang_core)', () {
    test('european text splits on whitespace with offsets', () async {
      final tokenizer = Tokenizer(); // no db: latin path needs none
      final tokens = await tokenizer.tokenize('hello world');
      expect(tokens.map((t) => t.surface), ['hello', 'world']);
      expect(tokens[0].startIndex, 0);
      expect(tokens[1].startIndex, 6);
    });

    test('chinese segments per character', () async {
      final tokenizer = Tokenizer();
      final tokens = await tokenizer.tokenize('中文');
      expect(tokens.map((t) => t.surface), ['中', '文']);
      expect(tokens.every((t) => t.partOfSpeech == 'character'), isTrue);
    });

    test('japanese longest-match uses the DictionaryDb port', () async {
      final tokenizer = Tokenizer(db: _FakeDb());
      final tokens = await tokenizer.tokenize('電車で行く');
      // the fake db knows 電車 (2 chars) and 行く (2 chars); で is a
      // single unmatched kana character
      expect(tokens.map((t) => t.surface).toList(), ['電車', 'で', '行く']);
      expect(tokens[0].partOfSpeech, 'word');
      expect(tokens[0].reading, 'でんしゃ');
      expect(tokens[1].partOfSpeech, 'character');
    });

    test('splitSentences maps surface runs to sentence text', () async {
      final tokenizer = Tokenizer();
      final tokens = await tokenizer.tokenize('Hello world. Second sentence!');
      final sentences = tokenizer.splitSentences(tokens);
      // keys are concatenated surfaces (lookup keys, like CJK); values
      // render inter-token gaps as spaces so Latin text stays readable
      expect(sentences.keys, contains('Helloworld.'));
      expect(sentences['Helloworld.'], 'Hello world.');
    });
  });

  group('SrsScheduler (lang_core)', () {
    test('first successful review: 1 day, learning', () {
      final r = SrsScheduler.schedule(
        easeFactor: 2.5,
        reviewCount: 0,
        quality: 4,
      );
      expect(r.intervalDays, 1);
      expect(r.newCard, isTrue);
      expect(r.reviewCount, 1);
    });

    test('second review: 6 days, review state', () {
      final r = SrsScheduler.schedule(
        easeFactor: 2.5,
        reviewCount: 1,
        quality: 4,
      );
      expect(r.intervalDays, 6);
      expect(r.newCard, isFalse);
    });

    test('later reviews grow by ease factor', () {
      final r = SrsScheduler.schedule(
        easeFactor: 2.5,
        reviewCount: 3,
        quality: 5,
      );
      expect(r.intervalDays, (3 * 2.5).round()); // 8
    });

    test('failures reset repetition and return to learning', () {
      final r = SrsScheduler.schedule(
        easeFactor: 2.5,
        reviewCount: 5,
        quality: 1,
      );
      expect(r.intervalDays, 0);
      expect(r.reviewCount, 0);
      expect(r.newCard, isTrue);
    });

    test('ease factor never drops below the floor', () {
      var ease = 1.35;
      for (var i = 0; i < 10; i++) {
        ease = SrsScheduler.schedule(
          easeFactor: ease,
          reviewCount: 2,
          quality: 0,
        ).easeFactor;
      }
      expect(ease, greaterThanOrEqualTo(1.3));
    });

    test('suspended cards pass through unchanged', () {
      final r = SrsScheduler.schedule(
        easeFactor: 2.0,
        reviewCount: 4,
        quality: 5,
        suspended: true,
      );
      expect(r.easeFactor, 2.0);
      expect(r.reviewCount, 4);
    });
  });
}

/// Minimal DictionaryDb fake: knows 電車 and 行く only.
class _FakeDb implements DictionaryDb {
  final Map<String, DictMatch> _entries = {
    '電車': const DictMatch(term: '電車', reading: 'でんしゃ', definition: 'train'),
    '行く': const DictMatch(term: '行く', reading: 'いく', definition: 'to go'),
  };

  @override
  Future<DictMatch?> longestMatch(List<String> candidates) async {
    for (final c in candidates) {
      // candidates arrive longest-first
      if (_entries.containsKey(c)) return _entries[c];
    }
    return null;
  }
}
