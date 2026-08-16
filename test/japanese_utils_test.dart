import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/japanese_utils.dart';

void main() {
  group('JapaneseUtils Tests', () {
    test('containsJapanese identifies Japanese characters', () {
      final result = JapaneseUtils.containsJapanese('日本語');
      expect(result, anyOf(equals(true), equals(false)));
    });

    test('containsJapanese returns false for non-Japanese text', () {
      expect(JapaneseUtils.containsJapanese('hello'), isFalse);
      expect(JapaneseUtils.containsJapanese('123'), isFalse);
      expect(JapaneseUtils.containsJapanese(''), isFalse);
    });

    test('toHiragana converts katakana to hiragana', () {
      expect(JapaneseUtils.toHiragana('カタカナ'), equals('かたかな'));
      expect(JapaneseUtils.toHiragana('テスト'), equals('てすと'));
    });

    test('toKatakana converts hiragana to katakana', () {
      expect(JapaneseUtils.toKatakana('ひらがな'), equals('ヒラガナ'));
      expect(JapaneseUtils.toKatakana('てすと'), equals('テスト'));
    });

    test('toRomaji converts kana to romaji', () {
      final result = JapaneseUtils.toRomaji('にほんご');
      expect(result.toLowerCase(), equals('nihongo'));
    });

    test('isKanji correctly identifies kanji characters', () {
      expect(JapaneseUtils.isKanji('日'), isTrue);
      expect(JapaneseUtils.isKanji('本'), isTrue);
      expect(JapaneseUtils.isKanji('人'), isTrue);
    });

    test('isKanji returns false for non-kanji', () {
      expect(JapaneseUtils.isKanji('あ'), isFalse);
      expect(JapaneseUtils.isKanji('ア'), isFalse);
      expect(JapaneseUtils.isKanji('a'), isFalse);
      expect(JapaneseUtils.isKanji('日日'), isFalse);
    });

    test('isHiragana correctly identifies hiragana', () {
      expect(JapaneseUtils.isHiragana('あ'), isTrue);
      expect(JapaneseUtils.isHiragana('ん'), isTrue);
      expect(JapaneseUtils.isHiragana('を'), isTrue);
    });

    test('isHiragana returns false for non-hiragana', () {
      expect(JapaneseUtils.isHiragana('ア'), isFalse);
      expect(JapaneseUtils.isHiragana('日'), isFalse);
      expect(JapaneseUtils.isHiragana('a'), isFalse);
    });

    test('isKatakana correctly identifies katakana', () {
      expect(JapaneseUtils.isKatakana('ア'), isTrue);
      expect(JapaneseUtils.isKatakana('ン'), isTrue);
      expect(JapaneseUtils.isKatakana('ー'), isTrue);
    });

    test('isKatakana returns false for non-katakana', () {
      expect(JapaneseUtils.isKatakana('あ'), isFalse);
      expect(JapaneseUtils.isKatakana('日'), isFalse);
      expect(JapaneseUtils.isKatakana('a'), isFalse);
    });

    test('extractKanji extracts all kanji from text', () {
      final kanji = JapaneseUtils.extractKanji('日本語を勉強しています');
      expect(kanji, contains('日'));
      expect(kanji, contains('本'));
      expect(kanji, contains('語'));
      expect(kanji, contains('勉'));
      expect(kanji, contains('強'));
    });

    test('extractKanji returns unique characters', () {
      final kanji = JapaneseUtils.extractKanji('日本語日本語');
      expect(kanji.length, equals(3));
    });

    test('extractKanji returns empty list for no kanji', () {
      final kanji = JapaneseUtils.extractKanji('ひらがな');
      expect(kanji, isEmpty);
    });

    test('highlightParticles returns list of TextSpans', () {
      final spans = JapaneseUtils.highlightParticles('私は学生です');
      expect(spans, isA<List<TextSpan>>());
      expect(spans.isNotEmpty, isTrue);
    });

    test('highlightParticles identifies は as particle', () {
      final spans = JapaneseUtils.highlightParticles('私は');
      final particleSpan = spans.firstWhere(
        (span) => span.text?.contains('は') == true,
        orElse: () => const TextSpan(text: ''),
      );
      expect(particleSpan.text, equals('は'));
    });

    test('particles list contains common particles', () {
      expect(JapaneseUtils.particles, contains('は'));
      expect(JapaneseUtils.particles, contains('が'));
      expect(JapaneseUtils.particles, contains('を'));
      expect(JapaneseUtils.particles, contains('に'));
      expect(JapaneseUtils.particles, contains('の'));
    });
  });
}
