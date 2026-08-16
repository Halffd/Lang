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
