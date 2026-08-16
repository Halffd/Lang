import 'package:lang/data/repositories/dictionary_service.dart';
import 'wiktionary_etymology_service.dart';

/// Service to handle Wiktionary integration and enrichment of search results
class WiktionaryIntegrationService {
  final DictionaryService _dictionaryService;

  WiktionaryIntegrationService(this._dictionaryService);

  /// Fetch and merge Wiktionary details into search result
  Future<SearchResult> enrichSearchResult(
    SearchResult baseResult,
    String query,
    String detectedLanguage,
  ) async {
    try {
      final wiktionaryDetails = await _dictionaryService
          .fetchWordDetailsMultiLanguage(query, detectedLanguage);

      if (wiktionaryDetails.isEmpty) {
        return baseResult;
      }

      final updatedWiktionaryMap = Map<String, List<WiktionaryEntry>>.from(
        baseResult.wiktionaryDetails,
      );

      final newEntries = wiktionaryDetails
          .map((detail) => WiktionaryEntry(
                word: query,
                language: detectedLanguage,
                definition: detail,
                partOfSpeech: 'Detailed Info',
              ))
          .toList();

      updatedWiktionaryMap['${query}_'] = newEntries;

      return SearchResult(
        entries: baseResult.entries,
        kanji: baseResult.kanji,
        pitchAccents: baseResult.pitchAccents,
        toneInfo: baseResult.toneInfo,
        frequencies: baseResult.frequencies,
        dictionaries: baseResult.dictionaries,
        tags: baseResult.tags,
        etymology: baseResult.etymology,
        wiktionaryDetails: updatedWiktionaryMap,
      );
    } catch (e) {
      print('Wiktionary enrichment failed (non-critical): $e');
      return baseResult;
    }
  }
}