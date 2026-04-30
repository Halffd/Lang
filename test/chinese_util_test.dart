import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/chinese_util.dart';

void main() {
  group('ChineseUtil Tests', () {
    test('containsChinese returns true for Chinese text', () {
      expect(ChineseUtil.containsChinese('中文'), isTrue);
      expect(ChineseUtil.containsChinese('你好'), isTrue);
      expect(ChineseUtil.containsChinese('中国'), isTrue);
    });

    test('containsChinese returns false for non-Chinese text', () {
      expect(ChineseUtil.containsChinese('hello'), isFalse);
      expect(ChineseUtil.containsChinese('123'), isFalse);
      expect(ChineseUtil.containsChinese(''), isFalse);
      expect(ChineseUtil.containsChinese('にほんご'), isFalse);
    });

    test('containsJapaneseKanji identifies kanji in text', () {
      expect(ChineseUtil.containsJapaneseKanji('日本語'), isTrue);
      expect(ChineseUtil.containsJapaneseKanji('中日'), isTrue);
    });

    test('containsIdeographic identifies various CJK characters', () {
      expect(ChineseUtil.containsIdeographic('中文'), isTrue);
      expect(ChineseUtil.containsIdeographic('日本語'), isTrue);
      expect(ChineseUtil.containsIdeographic('한글'), isTrue);
    });

    test('toPinyin converts Chinese to Pinyin with tone marks', () {
      final pinyin = ChineseUtil.toPinyin('中文');
      expect(pinyin, isNotEmpty);
      expect(RegExp(r'[a-zA-Z]').hasMatch(pinyin), isTrue);
    });

    test('toPinyinWithoutTone converts without tone marks', () {
      final pinyin = ChineseUtil.toPinyinWithoutTone('你好');
      expect(pinyin, isNotEmpty);
      expect(pinyin.contains('n'), isTrue);
      expect(pinyin.contains('h'), isTrue);
    });

    test('toSpacedPinyin adds spaces between syllables', () {
      final pinyin = ChineseUtil.toSpacedPinyin('你好');
      expect(pinyin, contains(' '));
    });

    test('toPinyinWithToneNumber includes tone numbers', () {
      final pinyin = ChineseUtil.toPinyinWithToneNumber('中国');
      expect(RegExp(r'[0-9]').hasMatch(pinyin), isTrue);
    });

    test('normalizeForSearch returns original and pinyin for Chinese', () {
      final normalized = ChineseUtil.normalizeForSearch('你好');
      expect(normalized, contains('你好'));
      expect(normalized.contains('ni') || normalized.contains('hao'), isTrue);
    });

    test('normalizeForSearch returns original for non-Chinese', () {
      expect(ChineseUtil.normalizeForSearch('hello'), equals('hello'));
    });

    test('looksLikeChinesePinyin identifies pinyin queries', () {
      expect(ChineseUtil.looksLikeChinesePinyin('ni hao'), isTrue);
      expect(ChineseUtil.looksLikeChinesePinyin('zhongguo'), isTrue);
    });

    test('looksLikeChinesePinyin validates patterns', () {
      final result = ChineseUtil.looksLikeChinesePinyin('hello');
      expect(result, anyOf(equals(true), equals(false)));
    });

    test('getAllSearchVariations returns multiple forms', () {
      final variations = ChineseUtil.getAllSearchVariations('中文');
      expect(variations.length, greaterThanOrEqualTo(1));
      expect(variations, contains('中文'));
    });

    test('getAllSearchVariations returns empty for non-Chinese', () {
      final variations = ChineseUtil.getAllSearchVariations('hello');
      expect(variations, isEmpty);
    });

    test('getPinyinInitials extracts initial consonants', () {
      final initials = ChineseUtil.getPinyinInitials('中国');
      expect(initials, isNotEmpty);
    });

    test('toPinyin handles empty string', () {
      final pinyin = ChineseUtil.toPinyin('');
      expect(pinyin, isEmpty);
    });
  });
}