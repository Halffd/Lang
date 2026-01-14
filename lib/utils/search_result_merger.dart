import '../services/dictionary_service.dart';

/// Utility class to merge search results, removing duplicates
class SearchResultMerger {
  /// Merge two search results, removing duplicates
  static SearchResult merge(SearchResult? existing, SearchResult newResult) {
    if (existing == null) return newResult;

    // Deduplicate entries
    final combinedEntries = [...existing.entries, ...newResult.entries];
    final seenTerms = <String>{};
    final uniqueEntries = combinedEntries.where((entry) {
      if (seenTerms.contains(entry.term)) return false;
      seenTerms.add(entry.term);
      return true;
    }).toList();

    // Merge maps
    return SearchResult(
      entries: uniqueEntries,
      kanji: [...existing.kanji, ...newResult.kanji],
      pitchAccents: _mergeMaps(existing.pitchAccents, newResult.pitchAccents),
      toneInfo: _mergeMaps(existing.toneInfo, newResult.toneInfo),
      frequencies: _mergeMaps(existing.frequencies, newResult.frequencies),
      dictionaries: _mergeMaps(existing.dictionaries, newResult.dictionaries),
      tags: _mergeMaps(existing.tags, newResult.tags),
      etymology: _mergeMaps(existing.etymology, newResult.etymology),
      wiktionaryDetails: _mergeMaps(
        existing.wiktionaryDetails,
        newResult.wiktionaryDetails,
      ),
    );
  }

  static Map<K, V> _mergeMaps<K, V>(Map<K, V> map1, Map<K, V> map2) {
    final merged = Map<K, V>.from(map1);
    merged.addAll(map2);
    return merged;
  }
}