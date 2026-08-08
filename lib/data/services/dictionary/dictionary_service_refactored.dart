import 'local_dictionary_service.dart';
import 'yomichan_service.dart';
import 'remote_dictionary_service.dart';
import 'tokenizer_service.dart';
import 'language_detector.dart';
import '../../domain/entities/dictionary.dart' as model;
import 'search_models.dart';
import '../../core/services/database.dart';

/// Refactored DictionaryService - delegates to specialized services
class DictionaryService {
  final LocalDictionaryService _localService = LocalDictionaryService();
  final YomichanService _yomichanService = YomichanService();
  final RemoteDictionaryService _remoteService = RemoteDictionaryService();
  final TokenizerService _tokenizerService = TokenizerService();
  final LanguageDetector _languageDetector = LanguageDetector();

  // Local database (Drift)
  static AppDatabase? _database;
  static AppDatabase get database => _database ??= AppDatabase();

  // Yomichan database (SQLite)
  Database? _yomichanDatabase;
  Future<Database> get yomichanDatabase async {
    _yomichanDatabase ??= await DatabaseManager().database;
    return _yomichanDatabase!;
  }

  // --- Main Search Methods ---

  /// Main search entry point - routes to appropriate service based on language
  Future<SearchResult> search(String query, {SearchOptions options = const SearchOptions()}) async {
    if (query.isEmpty) return SearchResult(entries: [], kanji: [], pitchAccents: {}, toneInfo: {}, frequencies: {}, dictionaries: {}, tags: {}, query: query);

    final language = _languageDetector.detect(query);
    
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

  /// Search Japanese text
  Future<SearchResult> _searchJapanese(String query, SearchOptions options) async {
    // Local database search
    final localResults = await _localService.searchJapanese(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    // Yomichan search
    final yomichanResults = await _yomichanService.searchEntries(query);

    // Ichi.moe analysis
    final ichiMoeResults = await _localService.analyzeWithIchiMoe(query);

    // Wiktionary details
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'ja');

    final entries = [
      ...localEntries,
      ...yomichanResults.map((r) => r.entry).toList(),
    ];

    return SearchResult(
      entries: entries,
      kanji: [],
      pitchAccents: _mergePitchAccents(yomichanResults),
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
      hasMore: entries.length >= 50,
    );
  }

  /// Search Chinese text
  Future<SearchResult> _searchChinese(String query, SearchOptions options) async {
    final localResults = await _localService.searchHanzi(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    final yomichanResults = await _yomichanService.searchEntries(query);
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'zh');

    final entries = [
      ...localEntries,
      ...yomichanResults.map((r) => r.entry).toList(),
    ];

    return SearchResult(
      entries: entries,
      kanji: [],
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
      hasMore: entries.length >= 50,
    );
  }

  /// Search Korean text
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

  /// Search European languages (English, etc.)
  Future<SearchResult> _searchEuropean(String query, SearchOptions options) async {
    final wiktionaryResults = await _remoteService.fetchWiktionaryDetails(query, language: 'en');
    final entries = _convertWiktionary(wiktionaryResults);

    // Local fallback
    final localResults = await _localService.searchExact(query);
    final localEntries = _localService.convertToModelEntries(localResults);

    final allEntries = [...entries, ...localEntries];

    return SearchResult(
      entries: allEntries,
      kanji: [],
      wiktionaryDetails: _convertWiktionary(wiktionaryResults),
      query: query,
    );
  }

  /// Search for single kanji/Chinese character
  Future<SearchResult> searchKanji(String character) async {
    final yomichanResults = await _yomichanService.searchKanji(character);
    return SearchResult(
      entries: [],
      kanji: yomichanResults.map((r) => r.kanji).toList(),
      tones: _mergeTones(yomichanResults),
      query: character,
    );
  }

  /// Tokenize text based on language
  Future<List<Token>> tokenize(String text) async {
    return await _tokenizerService.tokenize(text);
  }

  /// Detect language of text
  String detectLanguage(String text) {
    return _languageDetector.detect(text);
  }

  // --- Yomichan Dictionary Management ---

  Future<List<model.YomichanDictionary>> getYomichanDictionaries() async {
    return await _yomichanService.getDictionaries();
  }

  Future<void> toggleYomichanDictionary(int id, bool enabled) async {
    return await _yomichanService.toggleDictionary(id, enabled);
  }

  Future<void> deleteYomichanDictionary(int id) async {
    return await _yomichanService.deleteDictionary(id);
  }

  Future<model.DictionaryStats> getYomichanDictionaryStats(int id) async {
    return await _yomichanService.getStats(id);
  }

  // --- Compatibility Methods (for existing screens) ---

  Future<model.DictionarySearchResult> search(String query, {String language = 'ja'}) async {
    final result = await search(query, options: SearchOptions(limit: 50));
    return model.DictionarySearchResult(
      entries: result.entries,
      query: query,
      hasMore: result.hasMore,
    );
  }

  Future<model.DictionarySearchResult> analyzeText(String text) async {
    return await search(text, language: 'ja');
  }

  Future<model.DictionaryEntry?> lookupHistoryWord(String word) async {
    final result = await search(word, options: SearchOptions(exactMatch: true, limit: 1));
    return result.entries.isNotEmpty ? result.entries.first : null;
  }

  Future<void> saveWord(String word) async {
    // This would need to be implemented based on your storage strategy
    // For now, delegate to local service or yomichan service
  }

  Future<void> removeSavedWord(String word) async {
    // Implementation needed
  }

  Future<void> addToHistory(String word) async {
    // Implementation needed
  }

  Future<void> playAudio(String text) async {
    // Implementation needed
  }

  // --- Helper Methods ---

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
    // Convert to format expected by UI
    return {};
  }

  // --- Compatibility Properties ---

  int _itemsPerRow = 2;
  int get itemsPerRow => _itemsPerRow;

  int _itemsPerPage = 50;
  int get itemsPerPage => _itemsPerPage;

  bool _showIchiMoe = true;
  bool get showIchiMoe => _showIchiMoe;

  bool _showWiktionary = true;
  bool get showWiktionary => _showWiktionary;

  bool _showKanji = true;
  bool get showKanji => _showKanji;

  bool _showEtymology = true;
  bool get showEtymology => _showEtymology;

  int _searchLimit = 100;
  int get searchLimit => _searchLimit;

  // --- Settings Methods ---

  Future<void> init() async {
    await DatabaseManager().database;
  }

  Future<void> updateSetting(String key, dynamic value) async {
    // Delegate to appropriate service or local storage
  }

  Future<void> refreshDictionaries() async {
    // Delegate to yomichan service
  }

  Future<void> importDictionary() async {
    // Delegate to yomichan service
  }

  Future<void> refreshUserData() async {
    // Implementation needed
  }
}