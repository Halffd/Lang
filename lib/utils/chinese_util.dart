enum PinyinFormat { WITH_TONE_MARK, WITHOUT_TONE, WITH_TONE_NUMBER }

class PinyinHelper {
  static String getPinyin(
    String text, {
    String separator = '',
    PinyinFormat format = PinyinFormat.WITH_TONE_MARK,
  }) {
    return text;
  }
}

class ChineseUtil {
  // Basic pinyin mapping for common characters
  static const Map<String, String> _pinyinMap = {
    '中': 'zhōng',
    '文': 'wén',
    '你': 'nǐ',
    '好': 'hǎo',
    '国': 'guó',
    '日': 'rì',
    '本': 'běn',
    '语': 'yǔ',
    '人': 'rén',
    '我': 'wǒ',
    '们': 'men',
    '是': 'shì',
    '的': 'de',
    '一': 'yī',
    '不': 'bù',
    '在': 'zài',
    '有': 'yǒu',
    '他': 'tā',
    '这': 'zhè',
    '个': 'gè',
    '上': 'shàng',
    '来': 'lái',
    '去': 'qù',
    '大': 'dà',
    '小': 'xiǎo',
    '多': 'duō',
    '少': 'shǎo',
    '坏': 'huài',
    '新': 'xīn',
    '旧': 'jiù',
    '长': 'cháng',
    '短': 'duǎn',
    '高': 'gāo',
    '低': 'dī',
    '快': 'kuài',
    '慢': 'màn',
    '早': 'zǎo',
    '晚': 'wǎn',
    '前': 'qián',
    '后': 'hòu',
    '左': 'zuǒ',
    '右': 'yòu',
    '东': 'dōng',
    '西': 'xī',
    '南': 'nán',
    '北': 'běi',
    '心': 'xīn',
    '手': 'shǒu',
    '脚': 'jiǎo',
    '眼': 'yǎn',
    '耳': 'ěr',
    '口': 'kǒu',
    '鼻': 'bí',
    '头': 'tóu',
    '发': 'fā',
    '身': 'shēn',
    '体': 'tǐ',
    '家': 'jiā',
    '学': 'xué',
    '校': 'xiào',
    '生': 'shēng',
    '老': 'lǎo',
    '师': 'shī',
    '书': 'shū',
    '笔': 'bǐ',
    '纸': 'zhǐ',
    '字': 'zì',
    '词': 'cí',
    '句': 'jù',
    '读': 'dú',
    '写': 'xiě',
    '说': 'shuō',
    '听': 'tīng',
    '看': 'kàn',
    '吃': 'chī',
    '喝': 'hē',
    '睡': 'shuì',
    '醒': 'xǐng',
    '起': 'qǐ',
    '走': 'zǒu',
    '跑': 'pǎo',
    '坐': 'zuò',
    '站': 'zhàn',
    '买': 'mǎi',
    '卖': 'mài',
    '给': 'gěi',
    '拿': 'ná',
    '放': 'fàng',
    '开': 'kāi',
    '关': 'guān',
    '用': 'yòng',
    '做': 'zuò',
    '作': 'zuò',
    '习': 'xí',
    '知': 'zhī',
    '道': 'dào',
    '想': 'xiǎng',
    '觉': 'jué',
    '得': 'dé',
    '错': 'cuò',
    '对': 'duì',
    '非': 'fēi',
    '真': 'zhēn',
    '假': 'jiǎ',
    '美': 'měi',
    '丑': 'chǒu',
    '热': 'rè',
    '冷': 'lěng',
    '粗': 'cū',
    '细': 'xì',
    '宽': 'kuān',
    '窄': 'zhǎi',
    '厚': 'hòu',
    '薄': 'báo',
    '重': 'zhòng',
    '轻': 'qīng',
  };

  static String _getPinyin(String char) {
    return _pinyinMap[char] ?? char;
  }

  static String _removeTone(String pinyin) {
    return pinyin
        .replaceAll('ā', 'a').replaceAll('á', 'a').replaceAll('ǎ', 'a').replaceAll('à', 'a')
        .replaceAll('ē', 'e').replaceAll('é', 'e').replaceAll('ě', 'e').replaceAll('è', 'e')
        .replaceAll('ī', 'i').replaceAll('í', 'i').replaceAll('ǐ', 'i').replaceAll('ì', 'i')
        .replaceAll('ō', 'o').replaceAll('ó', 'o').replaceAll('ǒ', 'o').replaceAll('ò', 'o')
        .replaceAll('ū', 'u').replaceAll('ú', 'u').replaceAll('ǔ', 'u').replaceAll('ù', 'u')
        .replaceAll('ǖ', 'v').replaceAll('ǘ', 'v').replaceAll('ǚ', 'v').replaceAll('ǜ', 'v');
  }

  static String _toToneNumber(String pinyin) {
    return pinyin
        .replaceAll('ā', 'a1').replaceAll('á', 'a2').replaceAll('ǎ', 'a3').replaceAll('à', 'a4')
        .replaceAll('ē', 'e1').replaceAll('é', 'e2').replaceAll('ě', 'e3').replaceAll('è', 'e4')
        .replaceAll('ī', 'i1').replaceAll('í', 'i2').replaceAll('ǐ', 'i3').replaceAll('ì', 'i4')
        .replaceAll('ō', 'o1').replaceAll('ó', 'o2').replaceAll('ǒ', 'o3').replaceAll('ò', 'o4')
        .replaceAll('ū', 'u1').replaceAll('ú', 'u2').replaceAll('ǔ', 'u3').replaceAll('ù', 'u4')
        .replaceAll('ǖ', 'v1').replaceAll('ǘ', 'v2').replaceAll('ǚ', 'v3').replaceAll('ǜ', 'v4');
  }

  static bool containsChinese(String text) {
    return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text);
  }

  static bool containsJapaneseKanji(String text) {
    return RegExp(r'[\u4E00-\u9FBF]').hasMatch(text);
  }

  static bool containsIdeographic(String text) {
    return RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]').hasMatch(text);
  }

  static String toPinyin(String text, {PinyinFormat format = PinyinFormat.WITH_TONE_MARK}) {
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final pinyin = _getPinyin(char);
      if (buffer.isNotEmpty) buffer.write(' ');
      switch (format) {
        case PinyinFormat.WITHOUT_TONE:
          buffer.write(_removeTone(pinyin));
          break;
        case PinyinFormat.WITH_TONE_NUMBER:
          buffer.write(_toToneNumber(pinyin));
          break;
        case PinyinFormat.WITH_TONE_MARK:
        default:
          buffer.write(pinyin);
          break;
      }
    }
    return buffer.toString();
  }

  static String toPinyinWithoutTone(String text) {
    return toPinyin(text, format: PinyinFormat.WITHOUT_TONE);
  }

  static String toSpacedPinyin(String text, {PinyinFormat format = PinyinFormat.WITH_TONE_MARK}) {
    return toPinyin(text, format: format);
  }

  static String toPinyinWithToneNumber(String text) {
    return toPinyin(text, format: PinyinFormat.WITH_TONE_NUMBER);
  }

  static String getPinyinInitials(String text) {
    if (text.isEmpty) return '';
    final initials = <String>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final pinyin = _getPinyin(char);
      if (pinyin.isNotEmpty && pinyin != char) {
        initials.add(pinyin[0].toUpperCase());
      }
    }
    return initials.join('');
  }

  static String toPinyinWithTone(String text) {
    return toPinyin(text, format: PinyinFormat.WITH_TONE_MARK);
  }

  static bool looksLikeChinesePinyin(String text) {
    if (text.isEmpty) return false;
    final words = text.split(RegExp(r'\s'));
    if (words.length > 10) return false;
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(text) && words.any((w) => w.length > 1);
  }

  static String normalizeForSearch(String text) {
    if (text.isEmpty) return text;
    if (containsChinese(text)) {
      final pinyin = toPinyinWithoutTone(text);
      return '$text $pinyin'.trim();
    }
    return text;
  }

  static List<String> getAllSearchVariations(String text) {
    if (!containsChinese(text)) return [];
    final variations = <String>[text];
    final pinyin = toPinyinWithoutTone(text);
    if (pinyin != text) {
      variations.add(pinyin);
    }
    return variations;
  }
}
