import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/japanese_utils.dart';

void main() {
  group('KanaKit.romajiToKana', () {
    final kit = KanaKit();

    test('basic hiragana', () {
      expect(kit.romajiToKana('konnichiha'), 'こんにちは');
    });

    test('katakana mode', () {
      expect(kit.romajiToKana('konnichiha', katakana: true), 'コンニチハ');
      expect(kit.romajiToKana('neko', katakana: true), 'ネコ');
    });

    test('small tsu doubling', () {
      expect(kit.romajiToKana('kk'), 'っk');
    });

    test('n handling', () {
      expect(kit.romajiToKana('kanji'), 'かんじ');
      expect(kit.romajiToKana('nn'), 'んん');
    });

    test('mixed with non-romaji passthrough', () {
      expect(kit.romajiToKana('neko 猫'), 'ねこ 猫');
    });

    test('long vowel dash', () {
      expect(kit.romajiToKana('-'), 'ー');
    });

    test('already kana unchanged', () {
      expect(kit.romajiToKana('ねこ'), 'ねこ');
    });

    test('shifted input converts to katakana', () {
      // caps input lowercased internally
      expect(kit.romajiToKana('NEKO', katakana: true), 'ネコ');
    });
  });
}
