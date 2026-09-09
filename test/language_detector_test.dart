import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';

void main() {
  final detector = LanguageDetector();

  group('LanguageDetector.detect', () {
    test('japanese kana', () {
      expect(detector.detect('こんにちは'), 'ja');
      expect(detector.detect('カタカナ'), 'ja');
    });

    test('korean hangul', () {
      expect(detector.detect('안녕'), 'ko');
    });

    test('chinese hanzi', () {
      expect(detector.detect('你好'), 'zh');
    });

    test('arabic', () {
      expect(detector.detect('مرحبا'), 'ar');
    });

    test('hebrew', () {
      expect(detector.detect('שלום'), 'he');
    });

    test('cyrillic (russian and ukrainian share script)', () {
      expect(detector.detect('привет'), 'ru');
      // і is a Ukrainian letter but the detector is script-level
      expect(detector.detect('привіт'), 'ru');
    });

    test('devanagari (hindi)', () {
      expect(detector.detect('नमस्ते'), 'hi');
    });

    test('khmer', () {
      expect(detector.detect('សួស្តី'), 'km');
    });

    test('sinhala', () {
      expect(detector.detect('ආයුබෝවන්'), 'si');
    });

    test('myanmar', () {
      expect(detector.detect('မင်္ဂလာပါ'), 'my');
    });

    test('greek', () {
      expect(detector.detect('ελληνικά'), 'el');
    });

    test('georgian', () {
      expect(detector.detect('გამარჯობა'), 'ka');
    });

    test('armenian', () {
      expect(detector.detect('բարև'), 'hy');
    });

    test('thai', () {
      expect(detector.detect('สวัสดี'), 'th');
    });

    test('latin defaults to english', () {
      expect(detector.detect('hello'), 'en');
    });

    test('empty defaults to english', () {
      expect(detector.detect(''), 'en');
    });
  });

  group('LanguageDetector.isEuropeanText', () {
    test('latin text is european', () {
      expect(detector.isEuropeanText('hello world'), true);
    });

    test('numbers and spaces count as latin', () {
      expect(detector.isEuropeanText('abc 123'), true);
    });

    test('japanese is not european', () {
      expect(detector.isEuropeanText('こんにちは'), false);
    });

    test('empty is not european', () {
      expect(detector.isEuropeanText(''), false);
    });
  });
}
