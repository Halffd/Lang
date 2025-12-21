import 'package:pinyin/pinyin.dart';

class ChineseUtil {
  /// Check if a text contains Chinese characters (Hanzi)
  static bool containsChinese(String text) {
    return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text);
  }

  /// Check if a text contains Japanese Kanji characters
  static bool containsJapaneseKanji(String text) {
    return RegExp(r'[\u4E00-\u9FBF]').hasMatch(text);
  }

  /// Check if a text contains any ideographic characters (Chinese, Japanese, Korean)
  static bool containsIdeographic(String text) {
    // Unicode ranges for CJK (Chinese, Japanese, Korean) Unified Ideographs
    return RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]').hasMatch(text);
  }

  /// Convert Chinese characters to Pinyin
  static String toPinyin(String text, {PinyinFormat format = PinyinFormat.WITH_TONE_MARK}) {
    return PinyinHelper.getPinyin(text, separator: '', format: format);
  }

  /// Get Pinyin with spaces between words for search purposes
  static String toSpacedPinyin(String text, {PinyinFormat format = PinyinFormat.WITH_TONE_MARK}) {
    final pinyin = PinyinHelper.getPinyin(text, separator: ' ', format: format);
    return pinyin.replaceAll(RegExp(r'\s+'), ' ').trim(); // Remove extra spaces
  }

  /// Get Pinyin without tone marks, useful for flexible matching
  static String toPinyinWithoutTone(String text) {
    return PinyinHelper.getPinyin(text, separator: ' ', format: PinyinFormat.WITHOUT_TONE);
  }

  /// Get Pinyin with tone numbers (e.g., ni3 for ǐ)
  static String toPinyinWithToneNumber(String text) {
    return PinyinHelper.getPinyin(text, separator: ' ', format: PinyinFormat.WITH_TONE_NUMBER);
  }

  /// Get initial consonants of Pinyin for broader search
  static String getPinyinInitials(String text) {
    final pinyin = PinyinHelper.getPinyin(text, separator: '');
    final StringBuffer initials = StringBuffer();
    
    for (int i = 0; i < pinyin.length; i++) {
      final char = pinyin[i];
      if (_isChineseInitial(char)) {
        initials.write(char);
      }
    }
    
    return initials.toString();
  }

  static bool _isChineseInitial(String char) {
    return 'bpmfdtnlgkhjqxzcsrwy'.contains(char.toLowerCase());
  }

  /// Normalize text by removing spaces and converting to appropriate form
  static String normalizeForSearch(String text) {
    // If text contains Chinese, return both the original and Pinyin version
    if (containsChinese(text)) {
      // Return original text plus spaced Pinyin
      final pinyin = toSpacedPinyin(text, format: PinyinFormat.WITHOUT_TONE);
      return '$text $pinyin'.trim();
    }
    return text;
  }

  /// Check if a query might be looking for Chinese by checking for Pinyin-like patterns
  static bool looksLikeChinesePinyin(String query) {
    // Check if query looks like Pinyin (Roman letters with possible numbers for tones)
    final cleanQuery = query.toLowerCase().trim();
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(cleanQuery);
    final hasValidPinyinChars = RegExp(r'^[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ\s]+$').hasMatch(cleanQuery);
    
    return hasLetters && hasValidPinyinChars && !hasNumbersOrOtherCharacters(query);
  }

  static bool hasNumbersOrOtherCharacters(String query) {
    // Check if query has numbers but not for Pinyin (which can have tone numbers)
    final hasNonPinyinNumbers = RegExp(r'[0-9]').hasMatch(query) && 
        !RegExp(r'^[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ0-9\s]+$').hasMatch(query);
    return hasNonPinyinNumbers;
  }
  
  /// Get all possible variations for Chinese text search
  static List<String> getAllSearchVariations(String text) {
    final variations = <String>[];
    
    if (containsChinese(text)) {
      variations.add(text); // Original Chinese
      variations.add(toPinyinWithoutTone(text)); // Pinyin without tone marks
      variations.add(toPinyinWithToneNumber(text)); // Pinyin with tone numbers
      variations.add(getPinyinInitials(text)); // Pinyin initials
    }
    
    return variations;
  }
}