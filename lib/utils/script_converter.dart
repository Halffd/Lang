import 'japanese_utils.dart';
import 'pinyin_util.dart';
import 'chinese_util.dart';

enum ScriptType { latin, hiragana, katakana, kanji, hanzi, bopomofo, mixed, unknown }

class ScriptConverter {
  static final KanaKit _kanaKit = KanaKit();

  static const Map<String, String> _romajiToHiragana = {
    'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
    'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
    'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
    'sa': 'さ', 'shi': 'し', 'su': 'す', 'se': 'せ', 'so': 'そ',
    'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ',
    'ta': 'た', 'chi': 'ち', 'tsu': 'つ', 'te': 'て', 'to': 'と',
    'cha': 'ちゃ', 'chu': 'ちゅ', 'cho': 'ちょ',
    'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
    'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
    'ha': 'は', 'hi': 'ひ', 'fu': 'ふ', 'he': 'へ', 'ho': 'ほ',
    'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
    'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
    'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
    'ya': 'や', 'yu': 'ゆ', 'yo': 'よ',
    'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
    'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
    'wa': 'わ', 'wo': 'を', 'n': 'ん',
    'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
    'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
    'za': 'ざ', 'ji': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
    'ja': 'じゃ', 'ju': 'じゅ', 'jo': 'じょ',
    'da': 'だ', 'dji': 'ぢ', 'dzu': 'づ', 'de': 'で', 'do': 'ど',
    'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
    'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
    'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
    'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
    'kka': 'っか', 'kki': 'っき', 'kku': 'っく', 'kke': 'っけ', 'kko': 'っこ',
    'ssa': 'っさ', 'sshi': 'っし', 'ssu': 'っす', 'sse': 'っせ', 'sso': 'っそ',
    'tta': 'った', 'tchi': 'っち', 'ttsu': 'っつ', 'tte': 'って', 'tto': 'っと',
  };

  static Map<String, String>? _hiraganaToRomaji;

  static Map<String, String> get _kanaToRomaji {
    _hiraganaToRomaji ??= {for (final e in _romajiToHiragana.entries) e.value: e.key};
    return _hiraganaToRomaji!;
  }

  static const Map<String, String> _bopomofoToPinyin = {
    'ㄅ': 'b', 'ㄆ': 'p', 'ㄇ': 'm', 'ㄈ': 'f',
    'ㄉ': 'd', 'ㄊ': 't', 'ㄋ': 'n', 'ㄌ': 'l',
    'ㄍ': 'g', 'ㄎ': 'k', 'ㄏ': 'h',
    'ㄐ': 'j', 'ㄑ': 'q', 'ㄒ': 'x',
    'ㄓ': 'zh', 'ㄔ': 'ch', 'ㄕ': 'sh', 'ㄖ': 'r',
    'ㄗ': 'z', 'ㄘ': 'c', 'ㄙ': 's',
    'ㄚ': 'a', 'ㄛ': 'o', 'ㄜ': 'e', 'ㄝ': 'e',
    'ㄞ': 'ai', 'ㄟ': 'ei', 'ㄠ': 'ao', 'ㄡ': 'ou',
    'ㄢ': 'an', 'ㄣ': 'en', 'ㄤ': 'ang', 'ㄥ': 'eng',
    'ㄦ': 'er',
    'ㄧ': 'i', 'ㄨ': 'u', 'ㄩ': 'ü',
    'ㄪ': 'v', 'ㄫ': 'ng', 'ㄬ': 'gn',
  };

  static Map<String, String>? _pinyinToBopomofo;

  static Map<String, String> get _pinyinToBopomofoMap {
    _pinyinToBopomofo ??= {for (final e in _bopomofoToPinyin.entries) e.value: e.key};
    return _pinyinToBopomofo!;
  }

  static ScriptType detect(String text) {
    if (text.isEmpty) return ScriptType.unknown;
    bool hasLatin = false;
    bool hasHiragana = false;
    bool hasKatakana = false;
    bool hasKanji = false;
    bool hasHanzi = false;
    bool hasBopomofo = false;

    for (final rune in text.runes) {
      if (rune >= 0x3040 && rune <= 0x309F) hasHiragana = true;
      else if (rune >= 0x30A0 && rune <= 0x30FF) hasKatakana = true;
      else if (rune >= 0x3400 && rune <= 0x4DBF) hasKanji = true;
      else if (rune >= 0x4E00 && rune <= 0x9FFF) hasKanji = hasHanzi = true;
      else if (rune >= 0x3105 && rune <= 0x312F) hasBopomofo = true;
      else if (rune >= 0x41 && rune <= 0x5A || rune >= 0x61 && rune <= 0x7A) hasLatin = true;
    }

    final unique = [hasLatin, hasHiragana, hasKatakana, hasKanji || hasHanzi, hasBopomofo];
    final count = unique.where((b) => b).length;
    if (count > 1) return ScriptType.mixed;

    if (hasLatin) return ScriptType.latin;
    if (hasHiragana) return ScriptType.hiragana;
    if (hasKatakana) return ScriptType.katakana;
    if (hasKanji && !hasHanzi) return ScriptType.kanji;
    if (hasHanzi) return ScriptType.hanzi;
    if (hasBopomofo) return ScriptType.bopomofo;
    return ScriptType.unknown;
  }

  static String romajiToHiragana(String input) {
    final result = StringBuffer();
    int i = 0;
    while (i < input.length) {
      String? match;
      int matchLen = 0;
      for (int len = 4; len >= 1; len--) {
        if (i + len <= input.length) {
          final sub = input.substring(i, i + len).toLowerCase();
          if (_romajiToHiragana.containsKey(sub)) {
            match = _romajiToHiragana[sub];
            matchLen = len;
            break;
          }
        }
      }
      if (match != null) {
        result.write(match);
        i += matchLen;
      } else {
        result.write(input[i]);
        i++;
      }
    }
    return result.toString();
  }

  static String romajiToKatakana(String input) {
    return _kanaKit.toKatakana(romajiToHiragana(input));
  }

  static String kanaToRomaji(String input) {
    final result = StringBuffer();
    int i = 0;
    while (i < input.length) {
      String? match;
      int matchLen = 0;
      for (int len = 2; len >= 1; len--) {
        if (i + len <= input.length) {
          final sub = input.substring(i, i + len);
          if (_kanaToRomaji.containsKey(sub)) {
            match = _kanaToRomaji[sub];
            matchLen = len;
            break;
          }
        }
      }
      if (match != null) {
        result.write(match);
        i += matchLen;
      } else {
        result.write(input[i]);
        i++;
      }
    }
    return result.toString();
  }

  static String hiraganaToKatakana(String input) => _kanaKit.toKatakana(input);
  static String katakanaToHiragana(String input) => _kanaKit.toHiragana(input);

  static String pinyinToToneMarks(String input) {
    return PinyinUtil.convertToneNumbers(input);
  }

  static String bopomofoToPinyin(String input) {
    final result = StringBuffer();
    for (final char in input.split('')) {
      if (_bopomofoToPinyin.containsKey(char)) {
        result.write(_bopomofoToPinyin[char]);
      } else {
        result.write(char);
      }
    }
    return result.toString();
  }

  static String pinyinToBopomofo(String input) {
    final result = StringBuffer();
    int i = 0;
    while (i < input.length) {
      String? match;
      int matchLen = 0;
      for (int len = 2; len >= 1; len--) {
        if (i + len <= input.length) {
          final sub = input.substring(i, i + len).toLowerCase();
          if (_pinyinToBopomofoMap.containsKey(sub)) {
            match = _pinyinToBopomofoMap[sub];
            matchLen = len;
            break;
          }
        }
      }
      if (match != null) {
        result.write(match);
        i += matchLen;
      } else {
        result.write(input[i]);
        i++;
      }
    }
    return result.toString();
  }

  static Future<String> hanziToPinyin(String text) async {
    final parts = <String>[];
    for (final char in text.split('')) {
      if (ChineseUtil.containsChinese(char)) {
        final pinyin = PinyinUtil.getPinyin(char);
        parts.add(pinyin ?? char);
      } else {
        parts.add(char);
      }
    }
    return parts.join(' ');
  }

  static bool looksLikeRomaji(String text) {
    return RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(text);
  }

  static bool looksLikePinyin(String text) {
    return ChineseUtil.looksLikeChinesePinyin(text);
  }
}