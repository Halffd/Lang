import '../../domain/entities/srs_card.dart';
import '../../domain/entities/dictionary.dart';

/// Utility functions for converting between different data types and SRS cards
class SRSConversionUtils {
  /// Convert a dictionary entry to an SRS card
  static SRSCard dictionaryEntryToSRSCard(DictionaryEntry entry, {int priority = 3, int difficulty = 3}) {
    String meaning = entry.definitions.isNotEmpty ? entry.definitions.first : 'No definition available';
    
    if (entry.definitions.length > 1) {
      meaning = entry.definitions.take(2).join('; ');
      if (entry.definitions.length > 2) {
        meaning += '...';
      }
    }
    
    return SRSCard(
      id: entry.term + (entry.reading ?? ''),
      word: entry.term,
      reading: entry.reading ?? '',
      meaning: meaning,
      priority: priority,
      languageLevel: difficulty,
    );
  }

  /// Convert a map of word details to an SRS card
  static SRSCard wordDetailsToSRSCard(String word, Map<String, dynamic> details, {int priority = 3, int difficulty = 3}) {
    String reading = details['reading'] ?? '';
    String meaning = details['definitions'] != null && details['definitions'] is List
        ? (details['definitions'] as List).take(2).join('; ') + ((details['definitions'] as List).length > 2 ? '...' : '')
        : 'No definition available';
    
    return SRSCard(
      id: word + reading,
      word: word,
      reading: reading,
      meaning: meaning,
      priority: priority,
      languageLevel: difficulty,
    );
  }
}