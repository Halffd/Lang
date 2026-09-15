import 'package:lang/data/datasources/kanji_decomposition_data.dart';

import 'chinese_util.dart';

class IdeographicUtil {
  /// Find all ideographic components/particles in a given character.
  /// Delegates to the curated decomposition table; falls back to
  /// the character itself for unknown characters.
  static List<String> getComponents(String character) {
    if (character.isEmpty) return [];
    final comps = KanjiDecompositionData.getComponents(character);
    return comps.isEmpty ? [character] : comps;
  }

  /// Search for characters containing specific radical/particle
  static List<String> findCharactersByParticle(
    String particle,
    List<String> allCharacters,
  ) {
    return allCharacters.where((char) {
      if (char == particle) return true;
      if (char.contains(particle)) return true;
      return getComponents(char).contains(particle);
    }).toList();
  }

  /// Get decomposition of a character into radicals/components
  static Map<String, dynamic> decomposeCharacter(String character) {
    final components = getComponents(character);

    return {
      'character': character,
      'components': components,
      'hasComponents': components.length > 1,
      'componentCount': components.length,
    };
  }

  /// Search for characters that share common components
  static List<String> findSimilarByStructure(
    String character,
    List<String> allCharacters,
  ) {
    final targetComponents = getComponents(character);
    final similar = <String>{};

    for (final c in allCharacters) {
      if (c == character) continue; // Skip the same character

      final components = getComponents(c);
      // Find intersection of components
      final commonComponents = targetComponents.toSet().intersection(
        components.toSet(),
      );

      if (commonComponents.isNotEmpty) {
        similar.add(c);
      }
    }

    return similar.toList();
  }

  /// Check if text contains ideographic characters (Chinese, Kanji, Hanja)
  static bool containsIdeographic(String text) {
    return ChineseUtil.containsIdeographic(text);
  }

  /// Check if text contains Chinese characters specifically
  static bool containsChinese(String text) {
    return ChineseUtil.containsChinese(text);
  }

  /// Check if text contains Japanese Kanji characters
  static bool containsKanji(String text) {
    return ChineseUtil.containsJapaneseKanji(text);
  }
}
