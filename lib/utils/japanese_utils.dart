import 'package:flutter/material.dart';

class KanaKit {
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
    return input;
  }

  bool isKana(String input) {
    return input.runes.every((r) => (r >= 0x3040 && r <= 0x309F) || (r >= 0x30A0 && r <= 0x30FF));
  }
}

class JapaneseUtils {
  static final KanaKit _kanaKit = KanaKit();

  static final List<String> particles = [
    'は', 'が', 'を', 'に', 'へ', 'で', 'と', 'から', 'まで', 'より',
    'の', 'や', 'か', 'も', 'ね', 'よ', 'な', 'さ', 'わ', 'ぞ',
    'ば', 'と', 'なら', 'し', 'だけ', 'ばかり', 'など', 'くらい', 'ほど',
    'きり', 'しか', 'こそ', 'さえ', 'すら', 'でも', 'だの', 'やら', 'なり',
    'ながら', 'つつ', 'ところ', 'ものの', 'ために', 'のに', 'ので', 'のみ',
  ];

  static bool containsJapanese(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF\uFF00-\uFFEF\u4E00-\u9FAF]');
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
          spans.add(TextSpan(
            text: text.substring(currentIndex, particleIndex),
          ));
        }

        spans.add(TextSpan(
          text: particle,
          style: const TextStyle(
            color: Color(0xFF3F51B5),
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x1A3F51B5),
          ),
        ));

        currentIndex = particleIndex + particle.length;
        searchStartIndex = currentIndex;
      }
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
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