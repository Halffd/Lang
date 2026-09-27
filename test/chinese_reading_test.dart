import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/utils/chinese_util.dart';
import 'package:lang/utils/language_detector.dart' as utils;

void main() {
  group('kana takes precedence over the shared CJK block', () {
    final dict = LanguageDetector();

    test('japanese with kanji is detected as japanese', () {
      // Regression: these all used to return 'zh' because the CJK
      // ideograph check ran before the kana check.
      expect(dict.detect('日本語を勉強する'), 'ja');
      expect(dict.detect('私はコーヒーを飲みます'), 'ja');
      expect(dict.detect('漢字'), 'zh'); // no kana at all -> ambiguous -> zh
    });

    test('both detectors agree', () {
      for (final s in [
        '日本語を勉強する',
        '私はコーヒーを飲みます',
        '你好世界',
        '学习中文',
        'こんにちは',
        'hello',
      ]) {
        expect(utils.LanguageDetector.detect(s), dict.detect(s), reason: s);
      }
    });

    test('pure chinese is still chinese', () {
      expect(dict.detect('你好世界'), 'zh');
      expect(dict.detect('学习中文'), 'zh');
      expect(dict.detect('中文'), 'zh');
    });

    test('pure japanese kana is still japanese', () {
      expect(dict.detect('こんにちは'), 'ja');
      expect(dict.detect('カタカナ'), 'ja');
    });
  });

  group('ChineseUtil.containsKana', () {
    test('detects hiragana and katakana only', () {
      expect(ChineseUtil.containsKana('こんにちは'), true);
      expect(ChineseUtil.containsKana('カタカナ'), true);
      expect(ChineseUtil.containsKana('你好'), false);
      expect(ChineseUtil.containsKana(''), false);
    });
  });

  group('AnalyzedWord.readingFor', () {
    test('japanese keeps its kana reading', () {
      expect(
        AnalyzedWord.readingFor(
          language: 'ja',
          term: '日本語',
          yomichanReading: 'にほんご',
        ),
        'にほんご',
      );
    });

    test('chinese does not show the japanese kana reading', () {
      // The core complaint: a Chinese term looked up in a Japanese
      // Yomichan dictionary must not display furigana.
      expect(
        AnalyzedWord.readingFor(
          language: 'zh',
          term: '中文',
          yomichanReading: 'ちゅうwen',
        ),
        isNot('ちゅうwen'),
      );
    });

    test('chinese uses pinyin when fully covered', () {
      expect(
        AnalyzedWord.readingFor(
          language: 'zh',
          term: '中文',
          yomichanReading: 'ちゅうぶん',
        ),
        'zhōng wén',
      );
    });

    test('chinese shows no reading when pinyin is unavailable', () {
      // Prefer an absent reading over a wrong Japanese one.
      expect(
        AnalyzedWord.readingFor(
          language: 'zh',
          term: '龘',
          yomichanReading: 'たつ',
        ),
        isNull,
      );
    });
  });

  group('ChineseUtil.toPinyinIfComplete', () {
    test('returns null when any character is unmapped', () {
      expect(ChineseUtil.toPinyinIfComplete('龘'), isNull);
      expect(ChineseUtil.toPinyinIfComplete(''), isNull);
    });

    test('returns spaced pinyin when fully covered', () {
      expect(ChineseUtil.toPinyinIfComplete('中文'), 'zhōng wén');
    });
  });
}
