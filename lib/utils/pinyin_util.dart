/// Simple Pinyin converter with tone marks
/// In a production app, you would use a proper library like pinyin4dart
class PinyinUtil {
  /// Tone marks keyed by vowel letter.
  static const Map<String, List<String>> _vowelTones = {
    'a': ['ā', 'á', 'ǎ', 'à'],
    'e': ['ē', 'é', 'ě', 'è'],
    'i': ['ī', 'í', 'ǐ', 'ì'],
    'o': ['ō', 'ó', 'ǒ', 'ò'],
    'u': ['ū', 'ú', 'ǔ', 'ù'],
    'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
  };

  /// Vowel priority for tone placement (standard pinyin rule:
  /// a first, then o, then e; for ou/iu the mark goes on the
  /// second vowel; ü only when alone).
  static String _toneVowel(String syllable) {
    if (syllable.contains('a')) return 'a';
    if (syllable.contains('o') && !syllable.contains('ou')) return 'o';
    if (syllable.contains('e')) return 'e';
    if (syllable.contains('ü')) return 'ü';
    // iu/ui: mark on u; otherwise mark last vowel present
    if (syllable.contains('iu')) return 'u';
    if (syllable.contains('ui')) return 'i';
    if (syllable.contains('i')) return 'i';
    if (syllable.contains('o')) return 'o'; // ou: mark on o
    if (syllable.contains('u')) return 'u';
    return '';
  }

  /// Convert pinyin with tone numbers to tone marks
  /// Example: "ni3hao3" -> "nǐhǎo", "ni3 hao3" -> "nǐ hǎo"
  static String convertToneNumbers(String pinyinWithNumbers) {
    final result = StringBuffer();
    for (final word in pinyinWithNumbers.toLowerCase().split(' ')) {
      if (result.isNotEmpty) result.write(' ');
      result.write(_convertWord(word));
    }
    return result.toString();
  }

  /// Split a word into digit-terminated syllables and convert each.
  /// "zhong1wen2" -> "zhōngwén"; leftover letters pass through.
  static String _convertWord(String word) {
    final out = StringBuffer();
    final m = RegExp(r'([a-zü:]+?)([1-5])');
    var rest = word;
    while (true) {
      final match = m.firstMatch(rest);
      if (match == null) {
        out.write(rest);
        break;
      }
      out.write(_convertSyllable(match.group(0)!));
      rest = rest.substring(match.end);
    }
    return out.toString();
  }

  static String _convertSyllable(String syllable) {
    // trailing tone digit (1-5; 5 = neutral tone, no mark)
    final m = RegExp(r'^([a-zü:]+)([1-5])$').firstMatch(syllable);
    if (m == null) return syllable;
    // 'v' and 'u:' are common ü substitutes in pinyin input
    final base = m.group(1)!.replaceAll('u:', 'ü').replaceAll('v', 'ü');
    final tone = int.parse(m.group(2)!);

    if (tone == 5 || tone == 0) return base;

    final vowel = _toneVowel(base);
    if (vowel.isEmpty) return syllable;

    final marked = _vowelTones[vowel]![tone - 1];
    final idx = base.indexOf(vowel);
    if (idx < 0) return syllable;
    return base.substring(0, idx) + marked + base.substring(idx + 1);
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
