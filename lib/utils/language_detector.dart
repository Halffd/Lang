import 'chinese_util.dart';

class LanguageDetector {
  static String detect(String text) {
    if (ChineseUtil.containsChinese(text)) return 'zh';
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) return 'ja'; // Hiragana/Katakana
    if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text)) return 'ar'; // Arabic
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(text)) return 'he'; // Hebrew
    if (RegExp(r'[\u0400-\u04FF\u0500-\u052F]').hasMatch(text)) return 'ru'; // Cyrillic
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko'; // Korean Hangul
    if (RegExp(r'[\u1780-\u17FF\u19E0-\u19FF]').hasMatch(text)) return 'km'; // Khmer
    if (RegExp(r'[\u0900-\u097F\u1CD0-\u1CFF]').hasMatch(text)) return 'hi'; // Devanagari (Hindi, etc.)
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) return 'si'; // Sinhala
    if (RegExp(r'[\u1000-\u109F]').hasMatch(text)) return 'my'; // Myanmar
    // Default to 'en' for Latin-based scripts
    return 'en';
  }

  static Map<String, String> getLanguageInfo(String text) {
    final code = detect(text);
    final names = {
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'he': 'Hebrew',
      'ru': 'Russian',
      'ko': 'Korean',
      'km': 'Khmer',
      'hi': 'Hindi',
      'si': 'Sinhala',
      'my': 'Myanmar',
      'en': 'English',
    };
    return {
      'code': code,
      'name': names[code] ?? 'Unknown',
    };
  }
}