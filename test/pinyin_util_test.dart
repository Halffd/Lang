// PinyinUtil tone-number -> tone-mark conversion. Covers the tone
// placement rules (a first, o/e, ü, iu/ui, you) and the ü input
// substitutions.

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/utils/pinyin_util.dart';

void main() {
  group('convertToneNumbers', () {
    test('basic syllables', () {
      expect(PinyinUtil.convertToneNumbers('ni3'), 'nǐ');
      expect(PinyinUtil.convertToneNumbers('hao3'), 'hǎo');
      expect(PinyinUtil.convertToneNumbers('zhong1'), 'zhōng');
      expect(PinyinUtil.convertToneNumbers('wen2'), 'wén');
      expect(PinyinUtil.convertToneNumbers('shi4'), 'shì');
    });

    test('multi-syllable words', () {
      expect(PinyinUtil.convertToneNumbers('ni3hao3'), 'nǐhǎo');
      expect(PinyinUtil.convertToneNumbers('zhong1wen2'), 'zhōngwén');
      expect(PinyinUtil.convertToneNumbers('xie4xie'), 'xièxie');
    });

    test('space separated words keep separators', () {
      expect(PinyinUtil.convertToneNumbers('ni3 hao3'), 'nǐ hǎo');
    });

    test('tone 5 (neutral) has no mark', () {
      expect(PinyinUtil.convertToneNumbers('ma5'), 'ma');
      expect(PinyinUtil.convertToneNumbers('le5'), 'le');
    });

    test('vowel priority: a wins', () {
      expect(
        PinyinUtil.convertToneNumbers('hao3'),
        'hǎo',
      ); // not hǎo on a? yes a
      expect(PinyinUtil.convertToneNumbers('dai4'), 'dài');
    });

    test('you marks the o (iou spelling)', () {
      expect(PinyinUtil.convertToneNumbers('you1'), 'yōu');
      expect(PinyinUtil.convertToneNumbers('you2'), 'yóu');
      expect(PinyinUtil.convertToneNumbers('you3'), 'yǒu');
    });

    test('iu marks the u', () {
      expect(PinyinUtil.convertToneNumbers('liu2'), 'liú');
      expect(PinyinUtil.convertToneNumbers('xiu1'), 'xiū');
    });

    test('ui marks the i', () {
      expect(PinyinUtil.convertToneNumbers('gui4'), 'guì');
      expect(PinyinUtil.convertToneNumbers('shui3'), 'shuǐ');
    });

    test('ou marks the o', () {
      expect(PinyinUtil.convertToneNumbers('mou2'), 'móu');
      expect(PinyinUtil.convertToneNumbers('zhou1'), 'zhōu');
    });

    test('ü input via u: and v', () {
      expect(PinyinUtil.convertToneNumbers('lv4'), 'lǜ');
      expect(PinyinUtil.convertToneNumbers('nu:3'), 'nǚ');
      expect(PinyinUtil.convertToneNumbers('jue2'), 'jué');
    });

    test('input without tone numbers passes through', () {
      expect(PinyinUtil.convertToneNumbers('nihao'), 'nihao');
      expect(PinyinUtil.convertToneNumbers('Ni3Hao3'), 'nǐhǎo');
    });

    test('empty string', () {
      expect(PinyinUtil.convertToneNumbers(''), '');
    });
  });

  group('getPinyin', () {
    test('mock dictionary lookups', () {
      expect(PinyinUtil.getPinyin('你好'), 'nǐhǎo');
      expect(PinyinUtil.getPinyin('谢谢'), 'xièxie');
      expect(PinyinUtil.getPinyin('中国'), isNull); // not in mock dict
    });
  });

  group('isChinese', () {
    test('detects han characters', () {
      expect(PinyinUtil.isChinese('你好'), isTrue);
      expect(PinyinUtil.isChinese('abc 你'), isTrue);
    });

    test('rejects non-han', () {
      expect(PinyinUtil.isChinese('hello'), isFalse);
      expect(PinyinUtil.isChinese(''), isFalse);
      expect(PinyinUtil.isChinese('ひらがな'), isFalse);
    });
  });
}
