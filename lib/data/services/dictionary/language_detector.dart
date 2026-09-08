import 'package:lang/utils/chinese_util.dart';
import 'package:lang/utils/japanese_utils.dart';

/// Service for detecting the language/script of input text
class LanguageDetector {
  static final LanguageDetector _instance = LanguageDetector._internal();
  factory LanguageDetector() => _instance;
  LanguageDetector._internal();

  final KanaKit _kanaKit = KanaKit();

  /// Detect the language/script of input text
  /// Returns ISO 639-1 language code (ja, zh, en, ko, etc.)
  String detect(String text) {
    if (text.isEmpty) return 'en';

    // Check for specific character ranges
    if (ChineseUtil.containsChinese(text)) {
      return 'zh';
    }

    // Japanese - hiragana, katakana
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) {
      return 'ja';
    }

    // Korean Hangul
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) {
      return 'ko';
    }

    // Arabic script
    if (RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text)) {
      return 'ar';
    }

    // Hebrew
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(text)) {
      return 'he';
    }

    // Cyrillic (Russian, etc.)
    if (RegExp(r'[\u0400-\u04FF\u0500-\u052F]').hasMatch(text)) {
      return 'ru';
    }

    // Devanagari (Hindi, etc.)
    if (RegExp(r'[\u0900-\u097F\u1CD0-\u1CFF]').hasMatch(text)) {
      return 'hi';
    }

    // Greek
    if (RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').hasMatch(text)) {
      return 'el';
    }

    // Georgian
    if (RegExp(r'[\u10A0-\u10FF\u2D00-\u2D2F]').hasMatch(text)) {
      return 'ka';
    }

    // Armenian
    if (RegExp(r'[\u0530-\u058F\uFB13-\uFB17]').hasMatch(text)) {
      return 'hy';
    }

    // Thai
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) {
      return 'th';
    }

    // Khmer
    if (RegExp(r'[\u1780-\u17FF\u19E0-\u19FF]').hasMatch(text)) {
      return 'km';
    }

    // Sinhala
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) {
      return 'si';
    }

    // Myanmar
    if (RegExp(r'[\u1000-\u109F]').hasMatch(text)) {
      return 'my';
    }

    // Default to English for Latin-based scripts
    return 'en';
  }

  /// Check if text is primarily European (Latin-based) text
  bool isEuropeanText(String text) {
    if (text.isEmpty) return false;

    int latinCount = 0;
    int otherCount = 0;

    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if ((codeUnit >= 65 && codeUnit <= 122) || // A-Z, a-z
          (codeUnit >= 48 && codeUnit <= 57) || // 0-9
          codeUnit == 32 || // space
          (codeUnit >= 192 && codeUnit <= 687)) {
        // Extended Latin characters used in European languages
        latinCount++;
      } else {
        otherCount++;
      }
    }

    // If more than 50% are Latin characters, consider it European text
    return latinCount > 0 && otherCount < latinCount;
  }

  /// Check if text is primarily Japanese (contains hiragana/katakana)
  bool isJapaneseText(String text) {
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text);
  }

  /// Check if text contains Chinese characters
  bool isChineseText(String text) {
    return ChineseUtil.containsChinese(text);
  }

  /// Check if text is purely romaji (latin characters for Japanese)
  bool isRomaji(String text) {
    return !text.contains(RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]'));
  }

  /// Convert romaji to hiragana
  String romajiToHiragana(String text) {
    return _kanaKit.toHiragana(text);
  }

  /// Convert romaji to katakana
  String romajiToKatakana(String text) {
    return _kanaKit.toKatakana(text);
  }
}
