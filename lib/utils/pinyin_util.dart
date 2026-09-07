
/// Simple Pinyin converter with tone marks
/// In a production app, you would use a proper library like pinyin4dart
class PinyinUtil {
  /// Basic tone mark mapping for demonstration
  /// This is a simplified version - real implementation would be more complex
  static const Map<String, String> _toneMarks = {
    'a1': 'ā', 'a2': 'á', 'a3': 'ǎ', 'a4': 'à',
    'e1': 'ē', 'e2': 'é', 'e3': 'ě', 'e4': 'è',
    'i1': 'ī', 'i2': 'í', 'i3': 'ǐ', 'i4': 'ì',
    'o1': 'ō', 'o2': 'ó', 'o3': 'ǒ', 'o4': 'ò',
    'u1': 'ū', 'u2': 'ú', 'u3': 'ǔ', 'u4': 'ù',
    'ü1': 'ǖ', 'ü2': 'ǘ', 'ü3': 'ǚ', 'ü4': 'ǜ',
  };

  /// Convert pinyin with tone numbers to tone marks
  /// Example: "ni3hao3" -> "nǐhǎo"
  static String convertToneNumbers(String pinyinWithNumbers) {
    String result = pinyinWithNumbers.toLowerCase();
    
    _toneMarks.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    return result;
  }

  /// Simple mock pinyin lookup for common words
  /// In production, this would query a proper pinyin dictionary
  static String? getPinyin(String chineseWord) {
    // Mock dictionary for demonstration
    final Map<String, String> mockPinyin = {
      '你好': 'nǐhǎo',
      '谢谢': 'xièxie',
      '再见': 'zàijiàn',
      '请': 'qǐng',
      '谢谢': 'xièxie',
      '不': 'bù',
      '是': 'shì',
      '的': 'de',
      '在': 'zài',
      '有': 'yǒu',
      '一': 'yī',
      '了': 'le',
      '我': 'wǒ',
      '们': 'men',
      '你': 'nǐ',
      '好': 'hǎo',
      '很': 'hěn',
      '大': 'dà',
      '小': 'xiǎo',
      '多': 'duō',
      '少': 'shǎo',
      '上': 'shàng',
      '下': 'xià',
      '左': 'zuǒ',
      '右': 'yòu',
      '中': 'zhōng',
      '国': 'guó',
      '人': 'rén',
      '中': 'zhōng',
      '文': 'wén',
      '字': 'zì',
      '学': 'xué',
      '习': 'xí',
      '语': 'yǔ',
      '言': 'yán',
    };

    return mockPinyin[chineseWord];
  }

  /// Check if a string contains Chinese characters
  static bool isChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }
}