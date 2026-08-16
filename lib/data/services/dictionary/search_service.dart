import 'package:lang/data/services/dictionary/local_dictionary_service.dart' hide DictionaryEntry;
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/data/services/dictionary/remote_dictionary_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';
import 'package:lang/domain/entities/dictionary.dart';

/// Unified search service that orchestrates all dictionary sources
class SearchService {
  final LocalDictionaryService _localService = LocalDictionaryService();
  final YomichanService _yomichanService = YomichanService();
  final RemoteDictionaryService _remoteService = RemoteDictionaryService();
  final TokenizerService _tokenizerService = TokenizerService();
  final LanguageDetector _languageDetector = LanguageDetector();

  /// Main search method - searches all sources and merges results
  Future<SearchResult> search(String query, {SearchOptions options = const SearchOptions()}) async {
    if (query.isEmpty) {
      return SearchResult(entries: [], kanji: [], query: query);
    }

    final language = _languageDetector.detect(query);
    
    // Route to appropriate search strategy based on language
    switch (language) {
      case 'ja':
        return await _searchJapanese(query, options);
      case 'zh':
        return await _searchChinese(query, options);
      case 'ko':
        return await _searchKorean(query, options);
      default:
        return await _searchEuropean(query, options);
    }
  }

  /// Search for Japanese text
  Future<SearchResult> _searchJapanese(String query, SearchOptions options) async {
    final localResults = await _localService.searchJapanese(query);
    final localEntries = _localService.convertToModelEntries(localResults);
    final yomichanResults = await _yomichanService.searchEntries(query);
    final ichiMoeResults = await _localService.analyzeWithIchiMoe(query);
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'ja');

    return SearchResult(
      entries: localEntries + yomichanResults.map((r) => r.entry).whereType<DictionaryEntry>().toList(),
      kanji: [],
      query: query,
      hasMore: localEntries.length >= 50,
    );
  }

  /// Search for Chinese text
  Future<SearchResult> _searchChinese(String query, SearchOptions options) async {
    final localResults = await _localService.searchHanzi(query);
    final localEntries = _localService.convertToModelEntries(localResults);
    final yomichanResults = await _yomichanService.searchEntries(query);
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'zh');

    return SearchResult(
      entries: localEntries + yomichanResults.map((r) => r.entry).whereType<DictionaryEntry>().toList(),
      kanji: [],
      query: query,
      hasMore: localEntries.length >= 50,
    );
  }

  /// Search for Korean text
  Future<SearchResult> _searchKorean(String query, SearchOptions options) async {
    final yomichanResults = await _yomichanService.searchEntries(query);
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'ko');

    return SearchResult(
      entries: yomichanResults.map((r) => r.entry).whereType<DictionaryEntry>().toList(),
      kanji: [],
      query: query,
    );
  }

  /// Search for European languages (English, etc.)
  Future<SearchResult> _searchEuropean(String query, SearchOptions options) async {
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'en');
    final entries = _convertWiktionary(wiktionaryResults);
    final localResults = await _localService.searchExact(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    // Merge the two lists properly - entries is a Map, we need to extract the list
    final wiktionaryEntries = entries['entries'] as List<DictionaryEntry>? ?? [];
    final allEntries = <DictionaryEntry>[];
    allEntries.addAll(wiktionaryEntries);
    allEntries.addAll(localEntries);

    return SearchResult(
      entries: allEntries,
      kanji: [],
      query: query,
    );
  }

  /// Search for a single kanji/Chinese character
  Future<SearchResult> searchKanji(String character) async {
    final yomichanResults = await _yomichanService.searchKanji(character);
    
    return SearchResult(
      entries: [],
      kanji: yomichanResults.map((r) => r.kanji).whereType<KanjiEntry>().toList(),
      query: character,
    );
  }

  /// Tokenize text
  Future<List<Token>> tokenize(String text) async {
    return await _tokenizerService.tokenize(text);
  }

  // Helper methods
  Map<String, dynamic> _convertWiktionary(List<WiktionaryEntry> entries) {
    return {'entries': entries.map((e) => e.toJson()).whereType<Map<String, dynamic>>().toList()};
  }

  void _mergeFrequencies(List<YomichanSearchResult> results) {
    // Implementation
  }
}

/// Search options
class SearchOptions {
  final int limit;
  final bool exactMatch;
  final bool searchReadings;
  final List<int>? dictionaryIds;

  const SearchOptions({
    this.limit = 20,
    this.exactMatch = false,
    this.searchReadings = true,
    this.dictionaryIds,
  });
}

/// Search result container
class SearchResult {
  final List<DictionaryEntry> entries;
  final List<KanjiEntry> kanji;
  final Map<String, dynamic> pitchAccents;
  final Map<String, dynamic> tones;
  final Map<String, dynamic> wiktionaryDetails;
  final String query;
  final bool hasMore;

  SearchResult({
    required this.entries,
    required this.kanji,
    this.pitchAccents = const {},
    this.tones = const {},
    this.wiktionaryDetails = const {},
    required this.query,
    this.hasMore = false,
  });
}