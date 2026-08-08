import 'local_dictionary_service.dart';
import 'yomichan_service.dart';
import 'remote_dictionary_service.dart';
import 'tokenizer_service.dart';
import 'language_detector.dart';
import '../../domain/entities/dictionary.dart' as model;

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
    // Local database search with romaji/kana support
    final localResults = await _localService.searchJapanese(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    // Yomichan search
    final yomichanResults = await _yomichanService.searchEntries(query);

    // Ichi.moe analysis for Japanese text
    final ichiMoeResults = await _localService.analyzeWithIchiMoe(query);

    // Wiktionary for additional detail
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'ja');

    return SearchResult(
      entries: localEntries + yomichanResults.map((r) => r.entry).toList(),
      kanji: [], // Kanji search separate
      pitchAccents: _mergePitchAccents(yomichanResults),
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
      hasMore: localEntries.length >= 50,
    );
  }

  /// Search for Chinese text
  Future<SearchResult> _searchChinese(String query, SearchOptions options) async {
    // Local search for Hanzi
    final localResults = await _localService.searchHanzi(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    // Yomichan search for Chinese characters
    final yomichanResults = await _yomichanService.searchEntries(query);

    // Wiktionary for Chinese
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'zh');

    return SearchResult(
      entries: localEntries + yomichanResults.map((r) => r.entry).toList(),
      kanji: [],
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
      hasMore: localEntries.length >= 50,
    );
  }

  /// Search for Korean text
  Future<SearchResult> _searchKorean(String query, SearchOptions options) async {
    final yomichanResults = await _yomichanService.searchEntries(query);
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'ko');

    return SearchResult(
      entries: yomichanResults.map((r) => r.entry).toList(),
      kanji: [],
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
    );
  }

  /// Search for European languages (English, etc.)
  Future<SearchResult> _searchEuropean(String query, SearchOptions options) async {
    // Wiktionary as primary source for European languages
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'en');
    final entries = _convertWiktionary(wiktionaryResults);

    // Local fallback
    final localResults = await _localService.searchExact(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    return SearchResult(
      entries: entries + localEntries,
      kanji: [],
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
    );
  }

  /// Search for a single kanji/Chinese character
  Future<SearchResult> searchKanji(String character) async {
    final yomichanResults = await _yomichanService.searchKanji(character);
    
    return SearchResult(
      entries: [],
      kanji: yomichanResults.map((r) => r.kanji).toList(),
      tones: _mergeTones(yomichanResults),
      query: character,
    );
  }

  /// Tokenize text
  Future<List<Token>> tokenize(String text) async {
    return await _tokenizerService.tokenize(text);
  }

  // Helper methods
  Map<String, List<model.PitchAccent>> _mergePitchAccents(List<YomichanSearchResult> results) {
    final map = <String, List<model.PitchAccent>>{};
    for (final result in results) {
      final key = '${result.entry.term}_${result.entry.reading}';
      if (result.pitches.isNotEmpty) map[key] = result.pitches;
    }
    return map;
  }

  Map<String, List<model.ToneInfo>> _mergeTones(List<YomichanKanjiResult> results) {
    final map = <String, List<model.ToneInfo>>{};
    for (final result in results) {
      if (result.tones.isNotEmpty) map[result.kanji.character] = result.tones;
    }
    return map;
  }

  Map<String, dynamic> _convertWiktionary(List<model.WiktionaryEntry> entries) {
    // Convert to internal format
    return {'entries': entries.map((e) => e.toJson()).toList()};
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
  final List<model.DictionaryEntry> entries;
  final List<model.KanjiEntry> kanji;
  final Map<String, List<model.PitchAccent>> pitchAccents;
  final Map<String, List<model.ToneInfo>> tones;
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