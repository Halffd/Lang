import '../../domain/entities/srs_card.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/domain/entities/analyzed_word.dart';

/// Utility functions for converting between different data types and SRS cards
class SRSConversionUtils {
  /// Convert a dictionary entry to an SRS card
  static SRSCard dictionaryEntryToSRSCard(
    DictionaryEntry entry, {
    int priority = 3,
    int difficulty = 3,
  }) {
    String meaning = entry.definitions.isNotEmpty
        ? entry.definitions.first
        : 'No definition available';

    if (entry.definitions.length > 1) {
      meaning = entry.definitions.take(2).join('; ');
      if (entry.definitions.length > 2) {
        meaning += '...';
      }
    }

    return SRSCard.newCard(
      id: entry.term + entry.reading,
      word: entry.term,
      reading: entry.reading,
      meaning: meaning,
    );
  }

  /// Convert an analysed word to an SRS card. Uses the same
  /// `term + reading` id convention as [dictionaryEntryToSRSCard] so a word
  /// added from the analyse screen is the same card as one added from a
  /// dictionary entry.
  static SRSCard analyzedWordToSRSCard(
    AnalyzedWord word, {
    int priority = 3,
    int difficulty = 3,
  }) {
    final definitions = word.ichiMoeDefinitions
        .where((d) => d.isNotEmpty)
        .toList();

    var meaning = definitions.isNotEmpty
        ? definitions.first
        : 'No definition available';
    if (definitions.length > 1) {
      meaning = definitions.take(2).join('; ');
      if (definitions.length > 2) meaning += '...';
    }

    return SRSCard.newCard(
      id: word.word + (word.reading ?? ''),
      word: word.word,
      reading: word.reading ?? '',
      meaning: meaning,
    );
  }

  /// Convert a map of word details to an SRS card
  static SRSCard wordDetailsToSRSCard(
    String word,
    Map<String, dynamic> details, {
    int priority = 3,
    int difficulty = 3,
  }) {
    final String reading = details['reading']?.toString() ?? '';
    String meaning =
        details['definitions'] != null && details['definitions'] is List
        ? (details['definitions'] as List).take(2).join('; ') +
              ((details['definitions'] as List).length > 2 ? '...' : '')
        : 'No definition available';

    return SRSCard.newCard(
      id: word + reading,
      word: word,
      reading: reading,
      meaning: meaning,
    );
  }
}
