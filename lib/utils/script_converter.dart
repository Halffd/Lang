import 'japanese_utils.dart';
import 'pinyin_util.dart';
import 'chinese_util.dart';

enum ScriptType {
  latin,
  hiragana,
  katakana,
  kanji,
  hanzi,
  bopomofo,
  hangul,
  cyrillic,
  greek,
  georgian,
  armenian,
  hebrew,
  arabic,
  devanagari,
  thai,
  mixed,
  unknown,
}

class ScriptConverter {
  static final KanaKit _kanaKit = KanaKit();

  static const Map<String, String> _romajiToHiragana = {
    'a': 'あ',
    'i': 'い',
    'u': 'う',
    'e': 'え',
    'o': 'お',
    'ka': 'か',
    'ki': 'き',
    'ku': 'く',
    'ke': 'け',
    'ko': 'こ',
    'kya': 'きゃ',
    'kyu': 'きゅ',
    'kyo': 'きょ',
    'sa': 'さ',
    'shi': 'し',
    'su': 'す',
    'se': 'せ',
    'so': 'そ',
    'sha': 'しゃ',
    'shu': 'しゅ',
    'sho': 'しょ',
    'ta': 'た',
    'chi': 'ち',
    'tsu': 'つ',
    'te': 'て',
    'to': 'と',
    'cha': 'ちゃ',
    'chu': 'ちゅ',
    'cho': 'ちょ',
    'na': 'な',
    'ni': 'に',
    'nu': 'ぬ',
    'ne': 'ね',
    'no': 'の',
    'nya': 'にゃ',
    'nyu': 'にゅ',
    'nyo': 'にょ',
    'ha': 'は',
    'hi': 'ひ',
    'fu': 'ふ',
    'he': 'へ',
    'ho': 'ほ',
    'hya': 'ひゃ',
    'hyu': 'ひゅ',
    'hyo': 'ひょ',
    'ma': 'ま',
    'mi': 'み',
    'mu': 'む',
    'me': 'め',
    'mo': 'も',
    'mya': 'みゃ',
    'myu': 'みゅ',
    'myo': 'みょ',
    'ya': 'や',
    'yu': 'ゆ',
    'yo': 'よ',
    'ra': 'ら',
    'ri': 'り',
    'ru': 'る',
    're': 'れ',
    'ro': 'ろ',
    'rya': 'りゃ',
    'ryu': 'りゅ',
    'ryo': 'りょ',
    'wa': 'わ',
    'wo': 'を',
    'n': 'ん',
    'ga': 'が',
    'gi': 'ぎ',
    'gu': 'ぐ',
    'ge': 'げ',
    'go': 'ご',
    'gya': 'ぎゃ',
    'gyu': 'ぎゅ',
    'gyo': 'ぎょ',
    'za': 'ざ',
    'ji': 'じ',
    'zu': 'ず',
    'ze': 'ぜ',
    'zo': 'ぞ',
    'ja': 'じゃ',
    'ju': 'じゅ',
    'jo': 'じょ',
    'da': 'だ',
    'dji': 'ぢ',
    'dzu': 'づ',
    'de': 'で',
    'do': 'ど',
    'ba': 'ば',
    'bi': 'び',
    'bu': 'ぶ',
    'be': 'べ',
    'bo': 'ぼ',
    'bya': 'びゃ',
    'byu': 'びゅ',
    'byo': 'びょ',
    'pa': 'ぱ',
    'pi': 'ぴ',
    'pu': 'ぷ',
    'pe': 'ぺ',
    'po': 'ぽ',
    'pya': 'ぴゃ',
    'pyu': 'ぴゅ',
    'pyo': 'ぴょ',
    'kka': 'っか',
    'kki': 'っき',
    'kku': 'っく',
    'kke': 'っけ',
    'kko': 'っこ',
    'ssa': 'っさ',
    'sshi': 'っし',
    'ssu': 'っす',
    'sse': 'っせ',
    'sso': 'っそ',
    'tta': 'った',
    'tchi': 'っち',
    'ttsu': 'っつ',
    'tte': 'って',
    'tto': 'っと',
  };

  static Map<String, String>? _hiraganaToRomaji;

  static Map<String, String> get _kanaToRomaji {
    _hiraganaToRomaji ??= {
      for (final e in _romajiToHiragana.entries) e.value: e.key,
    };
    return _hiraganaToRomaji!;
  }

  static const Map<String, String> _bopomofoToPinyin = {
    'ㄅ': 'b',
    'ㄆ': 'p',
    'ㄇ': 'm',
    'ㄈ': 'f',
    'ㄉ': 'd',
    'ㄊ': 't',
    'ㄋ': 'n',
    'ㄌ': 'l',
    'ㄍ': 'g',
    'ㄎ': 'k',
    'ㄏ': 'h',
    'ㄐ': 'j',
    'ㄑ': 'q',
    'ㄒ': 'x',
    'ㄓ': 'zh',
    'ㄔ': 'ch',
    'ㄕ': 'sh',
    'ㄖ': 'r',
    'ㄗ': 'z',
    'ㄘ': 'c',
    'ㄙ': 's',
    'ㄚ': 'a',
    'ㄛ': 'o',
    'ㄜ': 'e',
    'ㄝ': 'e',
    'ㄞ': 'ai',
    'ㄟ': 'ei',
    'ㄠ': 'ao',
    'ㄡ': 'ou',
    'ㄢ': 'an',
    'ㄣ': 'en',
    'ㄤ': 'ang',
    'ㄥ': 'eng',
    'ㄦ': 'er',
    'ㄧ': 'i',
    'ㄨ': 'u',
    'ㄩ': 'ü',
    'ㄪ': 'v',
    'ㄫ': 'ng',
    'ㄬ': 'gn',
  };

  static Map<String, String>? _pinyinToBopomofo;

  static Map<String, String> get _pinyinToBopomofoMap {
    _pinyinToBopomofo ??= {
      for (final e in _bopomofoToPinyin.entries) e.value: e.key,
    };
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
    bool hasHangul = false;
    bool hasCyrillic = false;
    bool hasGreek = false;
    bool hasGeorgian = false;
    bool hasArmenian = false;
    bool hasHebrew = false;
    bool hasArabic = false;
    bool hasDevanagari = false;
    bool hasThai = false;

    for (final rune in text.runes) {
      if (rune >= 0x3040 && rune <= 0x309F) {
        hasHiragana = true;
      } else if (rune >= 0x30A0 && rune <= 0x30FF)
        hasKatakana = true;
      else if (rune >= 0x3400 && rune <= 0x4DBF)
        hasKanji = true;
      else if (rune >= 0x4E00 && rune <= 0x9FFF)
        hasKanji = hasHanzi = true;
      else if (rune >= 0x3105 && rune <= 0x312F)
        hasBopomofo = true;
      else if (rune >= 0xAC00 && rune <= 0xD7AF)
        hasHangul = true;
      else if (rune >= 0x0400 && rune <= 0x04FF)
        hasCyrillic = true;
      else if (rune >= 0x0370 && rune <= 0x03FF)
        hasGreek = true;
      else if (rune >= 0x10A0 && rune <= 0x10FF)
        hasGeorgian = true;
      else if (rune >= 0x0530 && rune <= 0x058F)
        hasArmenian = true;
      else if (rune >= 0x0590 && rune <= 0x05FF)
        hasHebrew = true;
      else if (rune >= 0x0600 && rune <= 0x06FF)
        hasArabic = true;
      else if (rune >= 0x0900 && rune <= 0x097F)
        hasDevanagari = true;
      else if (rune >= 0x0E00 && rune <= 0x0E7F)
        hasThai = true;
      else if (rune >= 0x41 && rune <= 0x5A || rune >= 0x61 && rune <= 0x7A)
        hasLatin = true;
    }

    final unique = [
      hasLatin,
      hasHiragana,
      hasKatakana,
      hasKanji || hasHanzi,
      hasBopomofo,
      hasHangul,
      hasCyrillic,
      hasGreek,
      hasGeorgian,
      hasArmenian,
      hasHebrew,
      hasArabic,
      hasDevanagari,
      hasThai,
    ];
    final count = unique.where((b) => b).length;
    if (count > 1) return ScriptType.mixed;

    if (hasLatin) return ScriptType.latin;
    if (hasHiragana) return ScriptType.hiragana;
    if (hasKatakana) return ScriptType.katakana;
    if (hasHangul) return ScriptType.hangul;
    if (hasCyrillic) return ScriptType.cyrillic;
    if (hasGreek) return ScriptType.greek;
    if (hasGeorgian) return ScriptType.georgian;
    if (hasArmenian) return ScriptType.armenian;
    if (hasHebrew) return ScriptType.hebrew;
    if (hasArabic) return ScriptType.arabic;
    if (hasDevanagari) return ScriptType.devanagari;
    if (hasThai) return ScriptType.thai;
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

  // ============================================================
  // Hangul: romanized latin -> Hangul (Revised Romanization style)
  // ============================================================

  static const Map<String, String> _hangulInitials = {
    'g': 'ㄱ',
    'k': 'ㅋ',
    'n': 'ㄴ',
    'd': 'ㄷ',
    't': 'ㅌ',
    'r': 'ㄹ',
    'm': 'ㅁ',
    'b': 'ㅂ',
    'p': 'ㅍ',
    's': 'ㅅ',
    'ss': 'ㅆ',
    'j': 'ㅈ',
    'jj': 'ㅉ',
    'ch': 'ㅊ',
    'h': 'ㅎ',
    'kk': 'ㄲ',
    'tt': 'ㄸ',
    'pp': 'ㅃ',
  };

  static const Map<String, String> _hangulVowels = {
    'a': 'ㅏ',
    'ya': 'ㅑ',
    'eo': 'ㅓ',
    'yeo': 'ㅕ',
    'o': 'ㅗ',
    'yo': 'ㅛ',
    'u': 'ㅜ',
    'yu': 'ㅠ',
    'eu': 'ㅡ',
    'i': 'ㅣ',
    'ae': 'ㅐ',
    'yae': 'ㅒ',
    'e': 'ㅔ',
    'ye': 'ㅖ',
    'oe': 'ㅚ',
    'wi': 'ㅟ',
    'ui': 'ㅢ',
    'eu-i': 'ㅢ',
  };

  static const Map<String, String> _hangulFinals = {
    '': '',
    'k': 'ㄱ',
    'k-s': 'ㄳ',
    'n': 'ㄴ',
    'n-h': 'ㄵ',
    'n-j': 'ㄶ',
    't': 'ㅅ',
    'l': 'ㄹ',
    'l-k': 'ㄺ',
    'l-m': 'ㄻ',
    'l-p': 'ㄼ',
    'l-s': 'ㄽ',
    'l-t': 'ㄾ',
    'l-p-s': 'ㅀ',
    'l-h': 'ㅀ',
    'm': 'ㅁ',
    'p': 'ㅂ',
    'p-s': 'ㅄ',
    's': 'ㅅ',
    'ng': 'ㅇ',
    't-k': 'ㄱ',
    't-h': 'ㅎ',
  };

  // Assemble a Hangul syllable from jamo (or pass through if impossible)
  static String? _assembleHangul(String cho, String jung, String jong) {
    const choBase = 0x1100;
    const jungBase = 0x1161;
    const jongBase = 0x11A7;
    const syllableBase = 0xAC00;

    final choList = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];
    final jungList = [
      'ㅏ',
      'ㅐ',
      'ㅑ',
      'ㅒ',
      'ㅓ',
      'ㅔ',
      'ㅕ',
      'ㅖ',
      'ㅗ',
      'ㅘ',
      'ㅙ',
      'ㅚ',
      'ㅛ',
      'ㅜ',
      'ㅝ',
      'ㅞ',
      'ㅟ',
      'ㅠ',
      'ㅡ',
      'ㅢ',
      'ㅣ',
    ];
    final jongList = [
      '',
      'ㄱ',
      'ㄲ',
      'ㄳ',
      'ㄴ',
      'ㄵ',
      'ㄶ',
      'ㄷ',
      'ㄹ',
      'ㄺ',
      'ㄻ',
      'ㄼ',
      'ㄽ',
      'ㄾ',
      'ㄿ',
      'ㅀ',
      'ㅁ',
      'ㅂ',
      'ㅄ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    final choIdx = choList.indexOf(cho);
    if (choIdx < 0) return null;
    final jungIdx = jungList.indexOf(jung);
    if (jungIdx < 0) return null;
    final jongIdx = jongList.indexOf(jong);
    if (jongIdx < 0) return null;

    // NOTE: bases unused; compute directly from indices
    // ignore: unused_local_variable
    final _ = (choBase, jungBase, jongBase, syllableBase);

    final code = 0xAC00 + (choIdx * 21 + jungIdx) * 28 + jongIdx;
    return String.fromCharCode(code);
  }

  /// Convert romanized Korean (Revised Romanization) to Hangul.
  /// Syllable-block aware: greedily matches [initial][vowel][final].
  /// Vowel-initial syllables get ㅇ (ieung) as placeholder initial.
  static String latinToHangul(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    int i = 0;
    final lower = input.toLowerCase();

    while (i < lower.length) {
      // skip spaces/punct
      if (!_isLatinChar(lower[i])) {
        result.write(input[i]);
        i++;
        continue;
      }

      // match initial (2-char first for tense consonants)
      String? cho;
      int choLen = 0;
      for (final len in [2, 1]) {
        if (i + len > lower.length) continue;
        final sub = lower.substring(i, i + len);
        if (_hangulInitials.containsKey(sub)) {
          cho = _hangulInitials[sub]!;
          choLen = len;
          break;
        }
      }

      // vowel-initial syllable: use ㅇ placeholder
      if (cho == null) {
        String? vowelFirst;
        int vLen = 0;
        for (final len in [3, 2, 1]) {
          if (i + len > lower.length) continue;
          final sub = lower.substring(i, i + len);
          if (_hangulVowels.containsKey(sub)) {
            vowelFirst = _hangulVowels[sub]!;
            vLen = len;
            break;
          }
        }
        if (vowelFirst != null) {
          cho = 'ㅇ';
          choLen = 0; // no consonant consumed
        } else {
          result.write(input[i]);
          i++;
          continue;
        }
      }

      // match vowel (2-char first for diphthongs)
      String? jung;
      int jungLen = 0;
      int vi = i + choLen;
      for (final len in [3, 2, 1]) {
        if (vi + len > lower.length) continue;
        final sub = lower.substring(vi, vi + len);
        if (_hangulVowels.containsKey(sub)) {
          jung = _hangulVowels[sub]!;
          jungLen = len;
          break;
        }
      }
      if (jung == null) {
        // lone consonant: write as-is (likely standalone or noise)
        result.write(input[i]);
        i++;
        continue;
      }

      // match final (longest first for clusters), but only accept a
      // candidate when what follows it starts with a consonant (or
      // nothing). A consonant followed by a vowel belongs to the
      // next syllable as its initial ("haseyo" -> 하세, not 핫에;
      // "hangul" -> 한글, not 항울).
      String? jong;
      int jongLen = 0;
      int fi = vi + jungLen;
      for (final len in [3, 2, 1]) {
        if (fi + len > lower.length) continue;
        final sub = lower.substring(fi, fi + len);
        if (!_hangulFinals.containsKey(sub)) continue;
        final nextIdx = fi + len;
        final nextIsVowel =
            nextIdx < lower.length &&
            _startsWithHangulVowel(lower.substring(nextIdx));
        if (nextIsVowel) continue; // consonant goes to next syllable
        jong = _hangulFinals[sub]!;
        jongLen = len;
        break;
      }

      final syllable = _assembleHangul(cho, jung, jong ?? '');
      if (syllable != null) {
        result.write(syllable);
        i = fi + jongLen;
      } else {
        result.write(input.substring(i, i + choLen));
        i += choLen == 0 ? 1 : choLen;
      }
    }

    return result.toString();
  }

  static bool _isLatinChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x61 && code <= 0x7A) || (code >= 0x41 && code <= 0x5A);
  }

  /// True when [s] begins with a romanized Hangul vowel.
  static bool _startsWithHangulVowel(String s) {
    for (final len in [3, 2, 1]) {
      if (len > s.length) continue;
      if (_hangulVowels.containsKey(s.substring(0, len))) return true;
    }
    return false;
  }

  // ============================================================
  // Cyrillic: translit latin -> Russian
  // Common scheme (GOST-ish): a->а b->б v->в g->г d->д e->е
  // zh->ж z->з i->и y->й k->к l->л m->м n->н o->о p->п
  // r->р s->с t->т u->у f->ф h->х ts->ц ch->ч sh->ш shch->щ
  // ============================================================

  static const Map<String, String> _latinToCyrillic = {
    // multi-char first (caller iterates longest-first)
    'shch': 'щ', 'zh': 'ж', 'ts': 'ц', 'ch': 'ч', 'sh': 'ш',
    'yu': 'ю', 'ya': 'я',
    // single
    'a': 'а', 'b': 'б', 'v': 'в', 'g': 'г', 'd': 'д', 'e': 'е',
    'z': 'з', 'i': 'и', 'j': 'й', 'k': 'к', 'l': 'л', 'm': 'м',
    'n': 'н', 'o': 'о', 'p': 'п', 'r': 'р', 's': 'с', 't': 'т',
    'u': 'у', 'f': 'ф', 'h': 'х',
    "''": 'ъ', "'": 'ь',
  };

  /// Convert romanized Cyrillic text to Cyrillic script.
  static String latinToCyrillic(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      String? match;
      int len = 0;
      for (int l = 4; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToCyrillic.containsKey(sub)) {
          match = _latinToCyrillic[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    return result.toString();
  }

  // ============================================================
  // Greek: romanized latin -> Greek letters
  // Modern Greek transliteration (ELOT 743-ish)
  // ============================================================

  static const Map<String, String> _latinToGreek = {
    // multi-char digraphs
    'th': 'θ', 'ch': 'χ', 'ps': 'ψ', 'ks': 'ξ', 'ph': 'φ',
    'ai': 'αι', 'ei': 'ει', 'oi': 'οι', 'ou': 'ου', 'au': 'αυ',
    'ng': 'γγ', 'mp': 'μπ', 'nt': 'ντ', 'gg': 'γκ',
    // singles
    'a': 'α', 'b': 'β', 'g': 'γ', 'd': 'δ', 'e': 'ε', 'z': 'ζ',
    'h': 'η', 'i': 'ι', 'k': 'κ', 'l': 'λ', 'm': 'μ', 'n': 'ν',
    'o': 'ο', 'p': 'π', 'r': 'ρ', 's': 'σ', 't': 'τ', 'u': 'υ',
    'f': 'φ', 'x': 'χ', 'y': 'υ', 'c': 'κ', 'v': 'β',
    'w': 'ω',
  };

  /// Convert romanized Greek to Greek script. Final sigma gets its
  /// word-final form (ς).
  static String latinToGreek(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      String? match;
      int len = 0;
      for (int l = 2; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToGreek.containsKey(sub)) {
          match = _latinToGreek[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    // word-final sigma: σ -> ς
    return _applyGreekFinalSigma(result.toString());
  }

  static String _applyGreekFinalSigma(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final isFinal =
          ch == 'σ' && (i + 1 >= s.length || !_isGreekLetter(s[i + 1]));
      buf.write(isFinal ? 'ς' : ch);
    }
    return buf.toString();
  }

  static bool _isGreekLetter(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x0370 && code <= 0x03FF) ||
        (code >= 0x1F00 && code <= 0x1FFF);
  }

  // ============================================================
  // Ukrainian: romanized latin -> Ukrainian Cyrillic
  // ============================================================

  static const Map<String, String> _latinToUkrainian = {
    // multi-char
    'shch': 'щ', 'zh': 'ж', 'ts': 'ц', 'ch': 'ч', 'sh': 'ш',
    'yu': 'ю', 'ya': 'я', 'ye': 'є', 'yi': 'ї',
    // singles (Ukrainian: i = і, g = г, h = г)
    'a': 'а', 'b': 'б', 'v': 'в', 'h': 'г', 'd': 'д', 'e': 'е',
    'g': 'ґ', 'z': 'з', 'y': 'и', 'i': 'і', 'j': 'й', 'k': 'к',
    'l': 'л', 'm': 'м', 'n': 'н', 'o': 'о', 'p': 'п', 'r': 'р',
    's': 'с', 't': 'т', 'u': 'у', 'f': 'ф',
    "'": 'ь',
  };

  /// Convert romanized Ukrainian to Cyrillic script.
  static String latinToUkrainian(String input) {
    return _mapLongestFirst(input, _latinToUkrainian, maxLen: 4);
  }

  // ============================================================
  // Bulgarian: romanized latin -> Bulgarian Cyrillic
  // ============================================================

  static const Map<String, String> _latinToBulgarian = {
    // multi-char
    'sht': 'щ', 'zh': 'ж', 'ts': 'ц', 'ch': 'ч', 'sh': 'ш',
    'yu': 'ю', 'ya': 'я', 'ia': 'я', 'iu': 'ю', 'ai': 'ай',
    // singles (Bulgarian: latin v = в, jat ѣ merged into е/я)
    'a': 'а', 'b': 'б', 'v': 'в', 'g': 'г', 'd': 'д', 'e': 'е',
    'z': 'з', 'i': 'и', 'j': 'й', 'k': 'к', 'l': 'л', 'm': 'м',
    'n': 'н', 'o': 'о', 'p': 'п', 'r': 'р', 's': 'с', 't': 'т',
    'u': 'у', 'f': 'ф', 'h': 'х', 'w': 'в',
    'y': 'ъ',
  };

  /// Convert romanized Bulgarian to Cyrillic script.
  static String latinToBulgarian(String input) {
    return _mapLongestFirst(input, _latinToBulgarian, maxLen: 3);
  }

  // ============================================================
  // Serbian: romanized latin -> Serbian Cyrillic
  // ============================================================

  static const Map<String, String> _latinToSerbian = {
    // multi-char (Serbian lj/nj/dž are single letters)
    'lj': 'љ', 'nj': 'њ', 'dž': 'џ',
    'ž': 'ж', 'č': 'ч', 'š': 'ш', 'ć': 'ћ', 'đ': 'ђ',
    // singles
    'a': 'а', 'b': 'б', 'v': 'в', 'g': 'г', 'd': 'д', 'e': 'е',
    'z': 'з', 'i': 'и', 'j': 'ј', 'k': 'к', 'l': 'л', 'm': 'м',
    'n': 'н', 'o': 'о', 'p': 'п', 'r': 'р', 's': 'с', 't': 'т',
    'u': 'у', 'f': 'ф', 'h': 'х', 'c': 'ц',
  };

  /// Convert romanized Serbian (Serbian Latin/Gaj's Latin) to
  /// Cyrillic script.
  static String latinToSerbian(String input) {
    return _mapLongestFirst(input, _latinToSerbian, maxLen: 2);
  }

  // ============================================================
  // ============================================================
  // Georgian: romanized latin -> Mkhedruli (modern Georgian)
  // National Romanization (georgian.gov.ge scheme)
  // ============================================================

  static const Map<String, String> _latinToGeorgian = {
    // multi-char
    'ts': 'ც', 'ch': 'ჩ', 'sh': 'შ', 'zh': 'ჟ',
    'kh': 'ხ', 'gh': 'ღ', 'dz': 'ძ',
    // singles
    'a': 'ა', 'b': 'ბ', 'g': 'გ', 'd': 'დ', 'e': 'ე', 'v': 'ვ',
    'z': 'ზ', 't': 'ტ', 'i': 'ი', 'k': 'კ', 'l': 'ლ', 'm': 'მ',
    'n': 'ნ', 'o': 'ო', 'p': 'პ', 'j': 'ჯ', 'r': 'რ', 's': 'ს',
    'u': 'უ', 'q': 'ყ', 'h': 'ჰ', 'c': 'ც', 'w': 'ჳ', 'y': 'ჲ',
    'f': 'ჶ',
  };

  /// Convert romanized Georgian to Mkhedruli script.
  static String latinToGeorgian(String input) {
    return _mapLongestFirst(input, _latinToGeorgian, maxLen: 2);
  }

  // ============================================================
  // Armenian: romanized latin -> Armenian letters
  // (classical transliteration scheme)
  // ============================================================

  static const Map<String, String> _latinToArmenian = {
    // multi-char
    'kh': 'խ', 'gh': 'ղ', 'ts': 'ծ', 'dz': 'ձ', 'ch': 'չ',
    'sh': 'շ', 'zh': 'ժ',
    // singles
    'a': 'ա', 'b': 'բ', 'g': 'գ', 'd': 'դ', 'e': 'ե', 'z': 'զ',
    'i': 'ի', 'l': 'լ', 'x': 'խ', 'k': 'կ', 'h': 'հ', 'j': 'ջ',
    'm': 'մ', 'n': 'ն', 'o': 'օ', 'p': 'պ', 'r': 'ր', 's': 'ս',
    'v': 'վ', 't': 'տ', 'u': 'ու', 'q': 'ք', 'c': 'ծ', 'y': 'յ',
  };

  /// Convert romanized Armenian to Armenian script.
  static String latinToArmenian(String input) {
    return _mapLongestFirst(input, _latinToArmenian, maxLen: 2);
  }

  /// Generic longest-first single-pass mapper.
  static String _mapLongestFirst(
    String input,
    Map<String, String> map, {
    int maxLen = 2,
  }) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      String? match;
      int len = 0;
      for (int l = maxLen; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (map.containsKey(sub)) {
          match = map[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    return result.toString();
  }

  // ============================================================
  // Hebrew: romanized latin -> Hebrew letters
  // ============================================================

  static const Map<String, String> _latinToHebrew = {
    // multi
    'tz': 'צ', 'ts': 'צ', 'kh': 'ח', 'ch': 'כ', 'sh': 'ש',
    'ei': 'י',
    // singles - consonants only; Hebrew is an abjad so short
    // vowels a/e/i/o/u are omitted (word-final vowels are
    // written as matres lectionis, handled in latinToHebrew).
    // Medial forms here; final (sofit) forms are applied by
    // _applyHebrewFinalForms after assembly.
    'b': 'ב', 'g': 'ג', 'd': 'ד', 'h': 'ה', 'v': 'ו',
    'z': 'ז', 'k': 'ק', 'y': 'י', 'l': 'ל', 'm': 'מ', 'n': 'נ',
    's': 'ס', 'p': 'פ', 'f': 'פ', 'r': 'ר', 'c': 'כ', 't': 'ת',
    'oo': 'ו', 'ii': 'י',
    'a': '', 'e': '', 'i': '', 'o': '', 'u': '',
  };

  /// Hebrew letters with special word-final (sofit) forms.
  static const Map<String, String> _hebrewSofit = {
    'מ': 'ם',
    'נ': 'ן',
    'צ': 'ץ',
    'פ': 'ף',
    'כ': 'ך',
  };

  /// Convert word-final letters to their sofit forms.
  static String _applyHebrewFinalForms(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final isLast = i + 1 >= s.length || !_isHebrewLetter(s[i + 1]);
      buf.write(isLast ? (_hebrewSofit[ch] ?? ch) : ch);
    }
    return buf.toString();
  }

  static bool _isHebrewLetter(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x05D0 && code <= 0x05EA;
  }

  /// Word-final vowel letters (matres lectionis).
  static const Map<String, String> _hebrewFinalVowels = {
    'a': 'א',
    'o': 'ו',
    'u': 'ו',
    'i': 'י',
    'e': 'א',
  };

  /// Convert romanized Hebrew to Hebrew script. Hebrew is an
  /// abjad - short vowels are typically omitted, but word-final
  /// vowels are written (shalom -> שלום).
  static String latinToHebrew(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      // vowel in the final syllable -> mater lectionis:
      // word-final vowel (ima -> אמא) or vowel followed by the
      // single trailing consonant (shalom -> שלום)
      final isVowel = _hebrewFinalVowels.containsKey(lower[i]);
      if (isVowel) {
        final isWordStart = i == 0 || !_isLatinChar(lower[i - 1]);
        final isWordEnd = i + 1 >= lower.length || !_isLatinChar(lower[i + 1]);
        // vowel + single trailing consonant: shalom -> שלום
        final beforeFinalConsonant = i + 2 == lower.length;
        if (isWordEnd || beforeFinalConsonant) {
          result.write(_hebrewFinalVowels[lower[i]]!);
          i++;
          continue;
        }
        // word-initial vowel followed by a consonant gets an alef
        // carrier: ima -> אמא, even -> אבן-ish
        if (isWordStart &&
            i + 1 < lower.length &&
            _isLatinChar(lower[i + 1]) &&
            !_hebrewFinalVowels.containsKey(lower[i + 1])) {
          result.write(lower[i] == 'o' || lower[i] == 'u' ? 'ו' : 'א');
          i++;
          continue;
        }
      }
      String? match;
      int len = 0;
      for (int l = 2; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToHebrew.containsKey(sub)) {
          match = _latinToHebrew[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        if (match.isNotEmpty) result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    return _applyHebrewFinalForms(result.toString());
  }

  // ============================================================
  // Arabic: romanized latin -> Arabic letters
  // ============================================================

  static const Map<String, String> _latinToArabic = {
    // multi-char
    'th': 'ث', 'kh': 'خ', 'dh': 'ذ', 'sh': 'ش', 'gh': 'غ',
    'aa': 'ا', 'ii': 'ي', 'uu': 'و',
    // singles - consonants
    'b': 'ب', 't': 'ت', 'j': 'ج', 'h': 'ه', 'd': 'د', 'r': 'ر',
    'z': 'ز', 's': 'س', 'f': 'ف', 'q': 'ق', 'k': 'ك', 'l': 'ل',
    'm': 'م', 'n': 'ن', 'w': 'و', 'y': 'ي',
    // short vowels omitted (abjad) - harakat not written
    'a': '', 'i': '', 'u': '',
    "'": 'ء',
  };

  /// Convert romanized Arabic to Arabic script. Short vowels are
  /// omitted (abjad), but a word-final 'a' is written as alif
  /// (marhaba -> مرحبا).
  static String latinToArabic(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      // word-final 'a' -> alif; apostrophe (hamza carrier) keeps
      // the word going so "ta'nin" is not "word-final a"
      final nextCh = i + 1 < lower.length ? lower[i + 1] : '';
      final isWordEnd =
          nextCh.isEmpty || (!_isLatinChar(nextCh) && nextCh != "'");
      if (isWordEnd && lower[i] == 'a') {
        result.write('ا');
        i++;
        continue;
      }
      String? match;
      int len = 0;
      for (int l = 2; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToArabic.containsKey(sub)) {
          match = _latinToArabic[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    return result.toString();
  }

  // ============================================================
  // Devanagari: IAST/romanized -> Devanagari (simple scheme)
  // ============================================================

  static const Map<String, String> _latinToDevanagari = {
    // multi
    'kh': 'ख', 'gh': 'घ', 'ch': 'च', 'chh': 'छ', 'jh': 'झ',
    'th': 'थ', 'dh': 'ध', 'ph': 'फ', 'bh': 'भ',
    'sh': 'श', 'shh': 'ष', 'gy': 'ज्ञ',
    'aa': 'आ', 'ii': 'ई', 'uu': 'ऊ', 'ai': 'ऐ', 'au': 'ओ',
    'ri': 'ऋ',
    // singles
    'k': 'क', 'g': 'ग', 'n': 'न', 'c': 'च', 'j': 'ज', 't': 'त',
    'd': 'द', 'p': 'प', 'b': 'ब', 'm': 'म', 'y': 'य', 'r': 'र',
    'l': 'ल', 'v': 'व', 'w': 'व', 's': 'स', 'h': 'ह',
    'a': 'अ', 'i': 'इ', 'u': 'उ', 'e': 'ए', 'o': 'ओ',
  };

  static const String _virama = '\u094D'; // halant/virama

  /// Convert romanized (ISO 15919-ish) text to Devanagari.
  /// Consonant clusters get virama between consonants.
  static String latinToDevanagari(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    String? lastConsonant;

    while (i < lower.length) {
      String? match;
      int len = 0;
      for (int l = 4; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToDevanagari.containsKey(sub)) {
          match = _latinToDevanagari[sub]!;
          len = l;
          break;
        }
      }

      if (match == null) {
        // flush pending consonant with inherent vowel
        if (lastConsonant != null) {
          result.write(lastConsonant);
          lastConsonant = null;
        }
        result.write(input[i]);
        i++;
        continue;
      }

      // Determine if consonant or vowel
      final isConsonant = _devanagariConsonants.contains(match);
      final isVowel = _devanagariVowels.contains(match);

      if (isConsonant) {
        // flush previous consonant with virama? No - previous
        // consonant gets inherent 'a' unless followed by consonant.
        if (lastConsonant != null) {
          result.write(lastConsonant);
          result.write(_virama);
          lastConsonant = null;
        }
        lastConsonant = match;
        i += len;
      } else if (isVowel) {
        if (lastConsonant != null) {
          // combining vowel sign
          final sign = _devanagariVowelSigns[match] ?? match;
          result.write(lastConsonant);
          result.write(sign);
          lastConsonant = null;
        } else {
          result.write(match);
        }
        i += len;
      } else {
        if (lastConsonant != null) {
          result.write(lastConsonant);
          lastConsonant = null;
        }
        result.write(match);
        i += len;
      }
    }

    // flush trailing consonant
    if (lastConsonant != null) {
      result.write(lastConsonant);
    }

    return result.toString();
  }

  static const List<String> _devanagariConsonants = [
    'क',
    'ख',
    'ग',
    'घ',
    'च',
    'छ',
    'ज',
    'झ',
    'ट',
    'ठ',
    'ड',
    'ढ',
    'ण',
    'त',
    'थ',
    'द',
    'ध',
    'न',
    'प',
    'फ',
    'ब',
    'भ',
    'म',
    'य',
    'र',
    'ल',
    'व',
    'श',
    'ष',
    'स',
    'ह',
    'ऋ',
  ];

  static const List<String> _devanagariVowels = [
    'अ',
    'आ',
    'इ',
    'ई',
    'उ',
    'ऊ',
    'ए',
    'ऐ',
    'ओ',
    'औ',
  ];

  static const Map<String, String> _devanagariVowelSigns = {
    'अ': '',
    'आ': 'ा',
    'इ': 'ि',
    'ई': 'ी',
    'उ': 'ु',
    'ऊ': 'ू',
    'ए': 'े',
    'ऐ': 'ै',
    'ओ': 'ो',
    'औ': 'ौ',
  };

  // ============================================================
  // Thai: romanized -> Thai (approximate, common syllables)
  // ============================================================

  static const Map<String, String> _latinToThai = {
    // multi
    'kh': 'ข', 'ph': 'พ', 'th': 'ท', 'ch': 'ช', 'ng': 'ง',
    'aa': 'า', 'ii': 'ี', 'uu': 'ู', 'ue': 'ื', 'oe': 'ึ',
    'ia': 'เีย', 'ua': 'ัว',
    // singles
    'k': 'ก', 'g': 'ก', 'p': 'ป', 't': 'ต', 'm': 'ม', 'n': 'น',
    'r': 'ร', 'l': 'ล', 'w': 'ว', 'y': 'ย', 'f': 'ฟ', 'h': 'ห',
    's': 'ส', 'j': 'จ', 'd': 'ด', 'b': 'บ',
    'a': 'ะ', 'i': 'ิ', 'u': 'ุ', 'e': 'เ', 'o': 'โ',
  };

  /// Convert romanized Thai to Thai script (approximate).
  static String latinToThai(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    final lower = input.toLowerCase();
    int i = 0;

    while (i < lower.length) {
      String? match;
      int len = 0;
      for (int l = 3; l >= 1; l--) {
        if (i + l > lower.length) continue;
        final sub = lower.substring(i, i + l);
        if (_latinToThai.containsKey(sub)) {
          match = _latinToThai[sub]!;
          len = l;
          break;
        }
      }
      if (match != null) {
        result.write(match);
        i += len;
      } else {
        result.write(input[i]);
        i++;
      }
    }

    return result.toString();
  }

  // ============================================================
  // Chinese pinyin: latin -> tone-marked pinyin (per syllable)
  // e.g. "zhong1wen2" -> "zhōngwén", or "ni hao" -> "nǐ hǎo"
  // ============================================================

  /// Convert numbered pinyin (ma1, zhong1wen2) to tone-marked pinyin.
  static String latinToPinyin(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    for (final word in input.split(' ')) {
      if (result.isNotEmpty) result.write(' ');
      result.write(PinyinUtil.convertToneNumbers(word));
    }
    return result.toString();
  }

  /// Dispatch conversion based on language code.
  /// Returns text converted from romanized latin to the native
  /// script for the given language. Returns input unchanged when
  /// the language has no converter.
  static String latinToScript(String input, String language) {
    switch (language) {
      case 'ja':
        return romajiToHiragana(input);
      case 'zh':
        return latinToPinyin(input);
      case 'ko':
        return latinToHangul(input);
      case 'ru':
        return latinToCyrillic(input);
      case 'uk':
        return latinToUkrainian(input);
      case 'bg':
        return latinToBulgarian(input);
      case 'sr':
        return latinToSerbian(input);
      case 'el':
        return latinToGreek(input);
      case 'ka':
        return latinToGeorgian(input);
      case 'hy':
        return latinToArmenian(input);
      case 'he':
      case 'iw':
        return latinToHebrew(input);
      case 'ar':
        return latinToArabic(input);
      case 'hi':
        return latinToDevanagari(input);
      case 'th':
        return latinToThai(input);
      default:
        return input;
    }
  }

  /// True when [language] has a romanized-input converter.
  static bool supportsLatinToScript(String language) {
    return const [
      'ja',
      'zh',
      'ko',
      'ru',
      'uk',
      'bg',
      'sr',
      'el',
      'ka',
      'hy',
      'he',
      'iw',
      'ar',
      'hi',
      'th',
    ].contains(language);
  }
}
