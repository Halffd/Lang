import 'script_ranges.dart';

/// Detects the ISO 639-1 code of [text] from its script ranges.
///
/// Pure Dart — moved verbatim from the app's LanguageDetector so
/// detection, tokenization and the host screens agree on one routing
/// decision.
class LanguageDetector {
  static final LanguageDetector _instance = LanguageDetector._internal();
  factory LanguageDetector() => _instance;
  LanguageDetector._internal();

  String detect(String text) {
    if (text.trim().isEmpty) return 'en';

    if (_containsKanaOrBopomofo(text)) {
      return 'ja';
    }

    if (ScriptRanges.containsChinese(text)) {
      return 'zh';
    }

    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) {
      return 'ko';
    }

    if (RegExp(r'[\u3040-\u30FF\u4E00-\u9FAF\uFF66-\uFF9F]').hasMatch(text)) {
      return 'ja';
    }

    if (RegExp(r'[\u0590-\u05FF]').hasMatch(text)) return 'he';
    if (RegExp(r'[\u0400-\u04FF\u0500-\u052F]').hasMatch(text)) return 'ru';
    if (RegExp(r'[\u0900-\u097F\u1CD0-\u1CFF]').hasMatch(text)) return 'hi';
    if (RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').hasMatch(text)) return 'el';
    if (RegExp(r'[\u10A0-\u10FF\u2D00-\u2D2F]').hasMatch(text)) return 'ka';
    if (RegExp(r'[\u0530-\u058F\uFB13-\uFB17]').hasMatch(text)) return 'hy';
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) return 'th';

    return 'en';
  }

  /// Kana with a kanji majority still means Japanese; kana alone also
  /// means Japanese (not Chinese).
  bool _containsKanaOrBopomofo(String text) {
    for (final c in text.runes) {
      if (ScriptRanges.isKana(c)) return true;
    }
    return false;
  }
}
