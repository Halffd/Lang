import 'package:flutter/material.dart';

class KanaKit {
  static const Map<String, String> _hiraganaToRomaji = {
    'あ': 'a',
    'い': 'i',
    'う': 'u',
    'え': 'e',
    'お': 'o',
    'か': 'ka',
    'き': 'ki',
    'く': 'ku',
    'け': 'ke',
    'こ': 'ko',
    'さ': 'sa',
    'し': 'shi',
    'す': 'su',
    'せ': 'se',
    'そ': 'so',
    'た': 'ta',
    'ち': 'chi',
    'つ': 'tsu',
    'て': 'te',
    'と': 'to',
    'な': 'na',
    'に': 'ni',
    'ぬ': 'nu',
    'ね': 'ne',
    'の': 'no',
    'は': 'ha',
    'ひ': 'hi',
    'ふ': 'fu',
    'へ': 'he',
    'ほ': 'ho',
    'ま': 'ma',
    'み': 'mi',
    'む': 'mu',
    'め': 'me',
    'も': 'mo',
    'や': 'ya',
    'ゆ': 'yu',
    'よ': 'yo',
    'ら': 'ra',
    'り': 'ri',
    'る': 'ru',
    'れ': 're',
    'ろ': 'ro',
    'わ': 'wa',
    'を': 'wo',
    'ん': 'n',
    'が': 'ga',
    'ぎ': 'gi',
    'ぐ': 'gu',
    'げ': 'ge',
    'ご': 'go',
    'ざ': 'za',
    'じ': 'ji',
    'ず': 'zu',
    'ぜ': 'ze',
    'ぞ': 'zo',
    'だ': 'da',
    'ぢ': 'ji',
    'づ': 'zu',
    'で': 'de',
    'ど': 'do',
    'ば': 'ba',
    'び': 'bi',
    'ぶ': 'bu',
    'べ': 'be',
    'ぼ': 'bo',
    'ぱ': 'pa',
    'ぴ': 'pi',
    'ぷ': 'pu',
    'ぺ': 'pe',
    'ぽ': 'po',
    'きゃ': 'kya',
    'きゅ': 'kyu',
    'きょ': 'kyo',
    'しゃ': 'sha',
    'しゅ': 'shu',
    'しょ': 'sho',
    'ちゃ': 'cha',
    'ちゅ': 'chu',
    'ちょ': 'cho',
    'にゃ': 'nya',
    'にゅ': 'nyu',
    'にょ': 'nyo',
    'ひゃ': 'hya',
    'ひゅ': 'hyu',
    'ひょ': 'hyo',
    'みゃ': 'mya',
    'みゅ': 'myu',
    'みょ': 'myo',
    'りゃ': 'rya',
    'りゅ': 'ryu',
    'りょ': 'ryo',
    'ぎゃ': 'gya',
    'ぎゅ': 'gyu',
    'ぎょ': 'gyo',
    'じゃ': 'ja',
    'じゅ': 'ju',
    'じょ': 'jo',
    'びゃ': 'bya',
    'びゅ': 'byu',
    'びょ': 'byo',
    'ぴゃ': 'pya',
    'ぴゅ': 'pyu',
    'ぴょ': 'pyo',
    'っ': '',
    'ッ': '',
    'ゃ': 'ya',
    'ゅ': 'yu',
    'ょ': 'yo',
    'ャ': 'ya',
    'ュ': 'yu',
    'ョ': 'yo',
  };

  String toHiragana(String input) {
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 0x30A0 && c <= 0x30F6) {
        buf.writeCharCode(c - 0x60);
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  String toKatakana(String input) {
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 0x3040 && c <= 0x3096) {
        buf.writeCharCode(c + 0x60);
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  String toRomaji(String input) {
    final hiragana = toHiragana(input);
    final result = StringBuffer();
    int i = 0;
    while (i < hiragana.length) {
      // Check for two-character combinations (like きゃ, しゃ, etc.)
      if (i + 1 < hiragana.length) {
        final twoChars = hiragana.substring(i, i + 2);
        if (_hiraganaToRomaji.containsKey(twoChars)) {
          result.write(_hiraganaToRomaji[twoChars]!);
          i += 2;
          continue;
        }
      }
      final char = hiragana[i];
      if (_hiraganaToRomaji.containsKey(char)) {
        result.write(_hiraganaToRomaji[char]!);
      } else {
        result.write(char);
      }
      i++;
    }
    return result.toString();
  }

  bool isKana(String input) {
    return input.runes.every(
      (r) => (r >= 0x3040 && r <= 0x309F) || (r >= 0x30A0 && r <= 0x30FF),
    );
  }

  // Romaji -> kana tables (longest match first)
  static const Map<String, String> _romajiToHiragana = {
    // 3+ char
    'chya': 'ちゃ', 'chyu': 'ちゅ', 'cho': 'ちょ', 'chyi': 'ちぃ', 'che': 'ちぇ',
    'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ', 'shi': 'し',
    'tsu': 'つ',
    'cha': 'ちゃ', 'chu': 'ちゅ', 'chi': 'ち',
    'jya': 'じゃ', 'jyu': 'じゅ', 'jyo': 'じょ', 'ja': 'じゃ', 'ji': 'じ', 'ju': 'じゅ', 'jo': 'じょ',
    'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
    'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
    'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
    'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
    'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
    'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
    'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
    'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
    'fya': 'ふゃ', 'fyu': 'ふゅ', 'fyo': 'ふょ',
    'hwa': 'ふぁ', 'hwi': 'ふぃ', 'hwe': 'ふぇ', 'hwo': 'ふぉ', 'hu': 'ふ', 'fu': 'ふ', 'fa': 'ふぁ', 'fi': 'ふぃ', 'fe': 'ふぇ', 'fo': 'ふぉ',
    // 2 char (long vowels: use ou/oo for おう/おお)
    'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
    'sa': 'さ', 'su': 'す', 'se': 'せ', 'so': 'そ',
    'ta': 'た', 'ti': 'ち', 'te': 'て', 'to': 'と',
    'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
    'ha': 'は', 'hi': 'ひ', 'he': 'へ', 'ho': 'ほ',
    'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
    'ya': 'や', 'yu': 'ゆ', 'yo': 'よ',
    'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
    'wa': 'わ', 'wo': 'を', 'wi': 'うぃ', 'we': 'うぇ',
    'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
    'za': 'ざ', 'zi': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
    'da': 'だ', 'di': 'ぢ', 'du': 'づ', 'de': 'で', 'do': 'ど',
    'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
    'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
    'va': 'ゔぁ', 'vi': 'ゔぃ', 'vu': 'ゔ', 've': 'ゔぇ', 'vo': 'ゔぉ',
    'xa': 'ぁ', 'xi': 'ぃ', 'xu': 'ぅ', 'xe': 'ぇ', 'xo': 'ぉ', 'xtu': 'っ', 'xya': 'ゃ', 'xyu': 'ゅ', 'xyo': 'ょ',
    // n' handling: nn -> ん, n followed by consonant -> ん
    // 1 char
    'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
    '-': 'ー',
  };

  static const List<String> _romajiConsonants = [
    'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z',
  ];

  /// Convert romaji to hiragana. Caps lock or shifted input can be
  /// converted to katakana via [katakana].
  String romajiToKana(String input, {bool katakana = false}) {
    if (input.isEmpty) return input;
    final lower = input.toLowerCase();
    final result = StringBuffer();
    int i = 0;

    while (i < lower.length) {
      // Try longest match (4 chars down to 1)
      String? matched;
      int matchLen = 0;
      for (int len = 4; len >= 1; len--) {
        if (i + len > lower.length) continue;
        final sub = lower.substring(i, i + len);
        if (_romajiToHiragana.containsKey(sub)) {
          matched = _romajiToHiragana[sub]!;
          matchLen = len;
          break;
        }
      }

      if (matched != null) {
        result.write(matched);
        i += matchLen;
        continue;
      }

      // 'n' followed by consonant or end = ん
      if (lower[i] == 'n') {
        final next = (i + 1 < lower.length) ? lower[i + 1] : '';
        if (next.isEmpty || _romajiConsonants.contains(next)) {
          if (next == 'n' && i + 2 < lower.length && lower[i + 2] == 'y') {
            // "nny" - treat first n as ん then handle n+y
            result.write('ん');
            i += 1;
            continue;
          }
          result.write('ん');
          i += 1;
          continue;
        }
      }

      // consonant doubling (sokuon) e.g. "kk" -> っk
      if (i + 1 < lower.length &&
          lower[i] == lower[i + 1] &&
          _romajiConsonants.contains(lower[i]) &&
          lower[i] != 'n') {
        result.write('っ');
        i += 1;
        continue;
      }

      // unknown char, pass through
      result.write(input[i]);
      i += 1;
    }

    final out = result.toString();
    return katakana ? toKatakana(out) : out;
  }
}

class JapaneseUtils {
  static final KanaKit _kanaKit = KanaKit();

  static final List<String> particles = [
    'は',
    'が',
    'を',
    'に',
    'へ',
    'で',
    'と',
    'から',
    'まで',
    'より',
    'の',
    'や',
    'か',
    'も',
    'ね',
    'よ',
    'な',
    'さ',
    'わ',
    'ぞ',
    'ば',
    'と',
    'なら',
    'し',
    'だけ',
    'ばかり',
    'など',
    'くらい',
    'ほど',
    'きり',
    'しか',
    'こそ',
    'さえ',
    'すら',
    'でも',
    'だの',
    'やら',
    'なり',
    'ながら',
    'つつ',
    'ところ',
    'ものの',
    'ために',
    'のに',
    'ので',
    'のみ',
  ];

  static bool containsJapanese(String text) {
    final japaneseRegex = RegExp(
      r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF\uFF00-\uFFEF\u4E00-\u9FAF]',
    );
    return japaneseRegex.hasMatch(text);
  }

  static String toHiragana(String text) {
    return _kanaKit.toHiragana(text);
  }

  static String toKatakana(String text) {
    return _kanaKit.toKatakana(text);
  }

  static String toRomaji(String text) {
    return _kanaKit.toRomaji(text);
  }

  /// Convert romaji input to kana. [katakana] true converts to katakana
  /// (used when shift/caps is held).
  static String romajiToKana(String text, {bool katakana = false}) {
    return _kanaKit.romajiToKana(text, katakana: katakana);
  }

  static List<TextSpan> highlightParticles(String text) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final particle in particles) {
      int searchStartIndex = 0;

      while (true) {
        final particleIndex = text.indexOf(particle, searchStartIndex);
        if (particleIndex == -1) break;

        if (particleIndex > currentIndex) {
          spans.add(
            TextSpan(text: text.substring(currentIndex, particleIndex)),
          );
        }

        spans.add(
          TextSpan(
            text: particle,
            style: const TextStyle(
              color: Color(0xFF3F51B5),
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x1A3F51B5),
            ),
          ),
        );

        currentIndex = particleIndex + particle.length;
        searchStartIndex = currentIndex;
      }
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }

  static List<String> extractKanji(String text) {
    final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
    final Set<String> kanjiSet = {};

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (kanjiRegex.hasMatch(char)) {
        kanjiSet.add(char);
      }
    }

    return kanjiSet.toList();
  }

  static bool isKanji(String char) {
    if (char.length != 1) return false;
    final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
    return kanjiRegex.hasMatch(char);
  }

  static bool isHiragana(String char) {
    if (char.length != 1) return false;
    final hiraganaRegex = RegExp(r'[\u3040-\u309F]');
    return hiraganaRegex.hasMatch(char);
  }

  static bool isKatakana(String char) {
    if (char.length != 1) return false;
    final katakanaRegex = RegExp(r'[\u30A0-\u30FF]');
    return katakanaRegex.hasMatch(char);
  }
}
