import 'package:flutter/material.dart';
import 'package:kana_kit/kana_kit.dart';

class JapaneseUtils {
  static final KanaKit _kanaKit = KanaKit();
  
  // List of Japanese particles
  static final List<String> particles = [
    'は', 'が', 'を', 'に', 'へ', 'で', 'と', 'から', 'まで', 'より',
    'の', 'や', 'か', 'も', 'ね', 'よ', 'な', 'さ', 'わ', 'ぞ',
    'ば', 'と', 'なら', 'し', 'だけ', 'ばかり', 'など', 'くらい', 'ほど',
    'きり', 'しか', 'こそ', 'さえ', 'すら', 'でも', 'だの', 'やら', 'なり',
    'ながら', 'つつ', 'ところ', 'ものの', 'ために', 'のに', 'ので', 'のみ',
  ];
  
  // Check if text contains Japanese characters
  static bool containsJapanese(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF\uFF00-\uFFEF\u4E00-\u9FAF]');
    return japaneseRegex.hasMatch(text);
  }
  
  // Convert romaji to hiragana
  static String toHiragana(String text) {
    return _kanaKit.toHiragana(text);
  }
  
  // Convert romaji to katakana
  static String toKatakana(String text) {
    return _kanaKit.toKatakana(text);
  }
  
  // Convert Japanese to romaji
  static String toRomaji(String text) {
    return _kanaKit.toRomaji(text);
  }
  
  // Highlight particles in a Japanese text
  static List<TextSpan> highlightParticles(String text) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;
    
    for (final particle in particles) {
      int searchStartIndex = 0;
      
      while (true) {
        final particleIndex = text.indexOf(particle, searchStartIndex);
        if (particleIndex == -1) break;
        
        // Add text before the particle
        if (particleIndex > currentIndex) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, particleIndex),
          ));
        }
        
        // Add the highlighted particle
        spans.add(TextSpan(
          text: particle,
          style: const TextStyle(
            color: Color(0xFF3F51B5),
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x1A3F51B5), // Light blue background
          ),
        ));
        
        currentIndex = particleIndex + particle.length;
        searchStartIndex = currentIndex;
      }
    }
    
    // Add any remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }
    
    return spans;
  }
  
  // Extract kanji from text
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
  
  // Check if a character is a kanji
  static bool isKanji(String char) {
    if (char.length != 1) return false;
    final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
    return kanjiRegex.hasMatch(char);
  }
  
  // Check if a character is hiragana
  static bool isHiragana(String char) {
    if (char.length != 1) return false;
    final hiraganaRegex = RegExp(r'[\u3040-\u309F]');
    return hiraganaRegex.hasMatch(char);
  }
  
  // Check if a character is katakana
  static bool isKatakana(String char) {
    if (char.length != 1) return false;
    final katakanaRegex = RegExp(r'[\u30A0-\u30FF]');
    return katakanaRegex.hasMatch(char);
  }
}
