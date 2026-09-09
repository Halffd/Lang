import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/data/datasources/local_translation_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/dictionary/local_dictionary_service.dart';
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/data/services/dictionary/remote_dictionary_service.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';
import 'package:lang/data/services/dictionary/search_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/utils/recursive_lookup.dart';
import 'package:lang/domain/entities/app_state.dart';

/// Unified dictionary service that delegates to specialized services
class AnalyzerProvider extends ChangeNotifier {
  /// App state hook, set at startup so profile dictionary settings
  /// (priority/conditions) can gate and order search results.
  AppState? appState;

  final LocalDictionaryService _localService = LocalDictionaryService();
  final YomichanService _yomichanService = YomichanService();
  final RemoteDictionaryService _remoteService = RemoteDictionaryService();
  final LanguageDetector _languageDetector = LanguageDetector();
  final TokenizerService _tokenizerService = TokenizerService();
  final SearchService _searchService = SearchService();

  // Translations (sentence-level and full-text)
  TranslationService? _translationService;
  final Map<String, String> _sentenceTranslations = {};
  String _fullTranslation = '';
  bool _isTranslating = false;
  String _lastTranslatedText = '';

  // Settings
  String _currentLanguage = 'ja';
  int _itemsPerRow = 2;
  int _itemsPerPage = 50;
  bool _showIchiMoe = true;
  bool _showWiktionary = true;
  bool _showKanji = true;
  bool _showEtymology = true;
  int _searchLimit = 100;

  // State
  List<AnalyzedWord> _analyzedWords = [];
  Map<String, String> _sentences = {};
  List<AnalyzedWord> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  // Pagination
  int _currentPage = 0;

  // User data
  List<Map<String, dynamic>> _installedDictionaries = [];
  List<Map<String, dynamic>> _savedWords = [];
  List<String> _history = [];

  // Filter/Sort/Group
  WordFilter _filter = WordFilter();
  WordSortBy _sortBy = WordSortBy.frequency;
  bool _sortAscending = false;
  WordGroupBy _groupBy = WordGroupBy.none;

  // Getters
  String get currentLanguage => _currentLanguage;
  int get itemsPerRow => _itemsPerRow;
  int get itemsPerPage => _itemsPerPage;
  bool get showIchiMoe => _showIchiMoe;
  bool get showWiktionary => _showWiktionary;
  bool get showKanji => _showKanji;
  bool get showEtymology => _showEtymology;
  int get searchLimit => _searchLimit;

  List<AnalyzedWord> get analyzedWords => _analyzedWords;
  Map<String, String> get sentences => _sentences;
  List<AnalyzedWord> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;
  List<Map<String, dynamic>> get installedDictionaries =>
      _installedDictionaries;
  List<Map<String, dynamic>> get savedWords => _savedWords;
  List<String> get history => _history;

  WordFilter get filter => _filter;
  WordSortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  WordGroupBy get groupBy => _groupBy;

  // Computed: filtered, sorted, grouped words
  List<AnalyzedWord> get _filteredSortedWords {
    var words = List<AnalyzedWord>.from(_analyzedWords);

    // Apply filters
    if (_filter.minFrequency != null) {
      words = words
          .where((w) => (w.frequency ?? 999999) >= _filter.minFrequency!)
          .toList();
    }
    if (_filter.maxFrequency != null) {
      words = words
          .where((w) => (w.frequency ?? 0) <= _filter.maxFrequency!)
          .toList();
    }
    if (_filter.hasDefinition == true) {
      words = words
          .where(
            (w) =>
                w.ichiMoeDefinitions.isNotEmpty ||
                w.localDefinitions.isNotEmpty ||
                (w.mdbgData?.definitions.isNotEmpty ?? false) ||
                w.wiktionaryHtml != null,
          )
          .toList();
    } else if (_filter.hasDefinition == false) {
      words = words
          .where(
            (w) =>
                w.ichiMoeDefinitions.isEmpty &&
                w.localDefinitions.isEmpty &&
                (w.mdbgData?.definitions.isEmpty ?? true) &&
                w.wiktionaryHtml == null,
          )
          .toList();
    }
    if (_filter.hasReading == true) {
      words = words
          .where(
            (w) =>
                (w.reading?.isNotEmpty ?? false) ||
                (w.mdbgData?.pinyin.isNotEmpty ?? false),
          )
          .toList();
    } else if (_filter.hasReading == false) {
      words = words
          .where(
            (w) =>
                (w.reading?.isEmpty ?? true) &&
                (w.mdbgData?.pinyin.isEmpty ?? true),
          )
          .toList();
    }
    if (_filter.hasKanji == true) {
      words = words.where((w) => w.kanjiList.isNotEmpty).toList();
    } else if (_filter.hasKanji == false) {
      words = words.where((w) => w.kanjiList.isEmpty).toList();
    }
    if (_filter.isSaved == true) {
      final savedWordSet = _savedWords.map((w) => w['word'] as String).toSet();
      words = words.where((w) => savedWordSet.contains(w.word)).toList();
    } else if (_filter.isSaved == false) {
      final savedWordSet = _savedWords.map((w) => w['word'] as String).toSet();
      words = words.where((w) => !savedWordSet.contains(w.word)).toList();
    }
    if (_filter.query?.isNotEmpty ?? false) {
      final q = _filter.query!.toLowerCase();
      words = words
          .where(
            (w) =>
                w.word.toLowerCase().contains(q) ||
                (w.reading?.toLowerCase().contains(q) ?? false) ||
                (w.mdbgData?.pinyin.toLowerCase().contains(q) ?? false) ||
                w.ichiMoeDefinitions.any((d) => d.toLowerCase().contains(q)) ||
                w.localDefinitions.any(
                  (d) => (d['definition'] as String? ?? '')
                      .toLowerCase()
                      .contains(q),
                ) ||
                (w.mdbgData?.definitions.any(
                      (d) => d.toLowerCase().contains(q),
                    ) ??
                    false),
          )
          .toList();
    }
    if (_filter.frequencyBands?.isNotEmpty ?? false) {
      words = words.where((w) {
        final freq = w.frequency ?? 999999;
        int band;
        if (freq <= 1000) {
          band = 0;
        } else if (freq <= 5000)
          band = 1;
        else if (freq <= 15000)
          band = 2;
        else
          band = 3;
        return _filter.frequencyBands!.contains(band);
      }).toList();
    }

    // Apply sort
    words.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case WordSortBy.word:
          cmp = a.word.compareTo(b.word);
          break;
        case WordSortBy.frequency:
          cmp = (a.frequency ?? 999999).compareTo(b.frequency ?? 999999);
          break;
        case WordSortBy.reading:
          cmp = (a.reading ?? '').compareTo(b.reading ?? '');
          break;
        case WordSortBy.kanjiCount:
          cmp = a.kanjiList.length.compareTo(b.kanjiList.length);
          break;
        case WordSortBy.definitionCount:
          final aCount =
              a.ichiMoeDefinitions.length +
              a.localDefinitions.length +
              (a.mdbgData?.definitions.length ?? 0);
          final bCount =
              b.ichiMoeDefinitions.length +
              b.localDefinitions.length +
              (b.mdbgData?.definitions.length ?? 0);
          cmp = aCount.compareTo(bCount);
          break;
        case WordSortBy.wordLength:
          cmp = a.word.length.compareTo(b.word.length);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return words;
  }

  List<AnalyzedWord> get pagedWords {
    final words = _filteredSortedWords;
    if (words.isEmpty) return [];
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage > words.length)
        ? words.length
        : start + _itemsPerPage;
    if (start >= words.length) return [];
    return words.sublist(start, end);
  }

  int get totalPages {
    final words = _filteredSortedWords;
    if (words.isEmpty) return 0;
    return (words.length / _itemsPerPage).ceil();
  }

  // ============================================================
  // Word/sentence selection model for keyboard navigation
  // ============================================================

  int _selectedWordIndex = -1;
  int _selectedSentenceIndex = -1;

  int get selectedWordIndex => _selectedWordIndex;
  int get selectedSentenceIndex => _selectedSentenceIndex;

  /// Sentences in document order (unique values of _sentences map).
  List<String> get sentenceList {
    final seen = <String>{};
    final list = <String>[];
    for (final s in _sentences.values) {
      final t = s.trim();
      if (t.isNotEmpty && !seen.contains(t)) {
        seen.add(t);
        list.add(t);
      }
    }
    return list;
  }

  /// Words grouped by sentence, in document order.
  /// Each entry: (sentence text, words in that sentence).
  List<MapEntry<String, List<AnalyzedWord>>> get sentenceGroups {
    final sents = sentenceList;
    final groups = <MapEntry<String, List<AnalyzedWord>>>[];
    final used = <String>{};
    for (final s in sents) {
      final wordsInSentence = _filteredSortedWords
          .where((w) => (w.sentence ?? '').trim() == s)
          .toList();
      groups.add(MapEntry(s, wordsInSentence));
      for (final w in wordsInSentence) {
        used.add(w.word);
      }
    }
    // words without sentence go in a trailing pseudo-group
    final orphans = _filteredSortedWords
        .where((w) => !used.contains(w.word))
        .toList();
    if (orphans.isNotEmpty) {
      groups.add(MapEntry('', orphans));
    }
    return groups;
  }

  /// Currently selected word (or null).
  AnalyzedWord? get selectedWord {
    final words = _filteredSortedWords;
    if (_selectedWordIndex < 0 || _selectedWordIndex >= words.length) {
      return null;
    }
    return words[_selectedWordIndex];
  }

  /// Currently selected sentence text (or null).
  String? get selectedSentence {
    final sents = sentenceList;
    if (_selectedSentenceIndex < 0 || _selectedSentenceIndex >= sents.length) {
      return null;
    }
    return sents[_selectedSentenceIndex];
  }

  /// Index of [word] in the filtered+sorted list (by identity), -1 if absent.
  int indexOfFilteredSorted(AnalyzedWord word) {
    final words = _filteredSortedWords;
    for (int i = 0; i < words.length; i++) {
      if (identical(words[i], word) || words[i].word == word.word) return i;
    }
    return -1;
  }

  void selectWord(int index) {
    final words = _filteredSortedWords;
    if (index >= 0 && index < words.length) {
      _selectedWordIndex = index;
      // keep sentence selection in sync
      final sent = words[index].sentence?.trim();
      final sents = sentenceList;
      final sIdx = sents.indexOf(sent ?? '');
      if (sIdx >= 0) _selectedSentenceIndex = sIdx;
      notifyListeners();
    }
  }

  void selectSentence(int index) {
    final sents = sentenceList;
    if (index >= 0 && index < sents.length) {
      _selectedSentenceIndex = index;
      // select first word of that sentence
      final words = _filteredSortedWords;
      final wIdx = words.indexWhere(
        (w) => (w.sentence ?? '').trim() == sents[index],
      );
      if (wIdx >= 0) _selectedWordIndex = wIdx;
      notifyListeners();
    }
  }

  bool selectNextWord() {
    final words = _filteredSortedWords;
    if (words.isEmpty) return false;
    if (_selectedWordIndex < 0) {
      selectWord(0);
      return true;
    }
    if (_selectedWordIndex < words.length - 1) {
      selectWord(_selectedWordIndex + 1);
      return true;
    }
    return false;
  }

  bool selectPrevWord() {
    if (_selectedWordIndex <= 0) return false;
    selectWord(_selectedWordIndex - 1);
    return true;
  }

  bool selectNextSentence() {
    final sents = sentenceList;
    if (sents.isEmpty) return false;
    if (_selectedSentenceIndex < 0) {
      selectSentence(0);
      return true;
    }
    if (_selectedSentenceIndex < sents.length - 1) {
      selectSentence(_selectedSentenceIndex + 1);
      return true;
    }
    return false;
  }

  bool selectPrevSentence() {
    if (_selectedSentenceIndex <= 0) return false;
    selectSentence(_selectedSentenceIndex - 1);
    return true;
  }

  void selectFirstSentence() {
    final sents = sentenceList;
    if (sents.isNotEmpty) selectSentence(0);
  }

  void selectLastSentence() {
    final sents = sentenceList;
    if (sents.isNotEmpty) selectSentence(sents.length - 1);
  }

  /// Page containing the selected word (for auto-scroll sync).
  int get pageOfSelectedWord {
    if (_selectedWordIndex < 0) return _currentPage;
    return _selectedWordIndex ~/ _itemsPerPage;
  }

  void clearSelection() {
    _selectedWordIndex = -1;
    _selectedSentenceIndex = -1;
    notifyListeners();
  }

  // Grouped words for display
  Map<String, List<AnalyzedWord>> get groupedWords {
    final words = _filteredSortedWords;
    if (_groupBy == WordGroupBy.none) return {'All': words};

    final groups = <String, List<AnalyzedWord>>{};
    for (final word in words) {
      String key;
      switch (_groupBy) {
        case WordGroupBy.frequencyBand:
          final freq = word.frequency ?? 999999;
          if (freq <= 1000) {
            key = 'Top 1K (Very Common)';
          } else if (freq <= 5000)
            key = '1K-5K (Common)';
          else if (freq <= 15000)
            key = '5K-15K (Uncommon)';
          else
            key = '15K+ (Rare)';
          break;
        case WordGroupBy.firstChar:
          key = word.word.isNotEmpty ? word.word[0].toUpperCase() : '?';
          break;
        case WordGroupBy.kanjiCount:
          key = '${word.kanjiList.length} Kanji';
          break;
        case WordGroupBy.hasReading:
          key =
              (word.reading?.isNotEmpty ?? false) ||
                  (word.mdbgData?.pinyin.isNotEmpty ?? false)
              ? 'Has Reading'
              : 'No Reading';
          break;
        case WordGroupBy.hasDefinition:
          final hasDef =
              word.ichiMoeDefinitions.isNotEmpty ||
              word.localDefinitions.isNotEmpty ||
              (word.mdbgData?.definitions.isNotEmpty ?? false) ||
              word.wiktionaryHtml != null;
          key = hasDef ? 'Has Definition' : 'No Definition';
          break;
        default:
          key = 'All';
      }
      groups.putIfAbsent(key, () => []).add(word);
    }
    final sortedKeys = groups.keys.toList()..sort();
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, groups[k]!)));
  }

  // --- Settings Methods ---

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    if (key == 'itemsPerRow') _itemsPerRow = value;
    if (key == 'itemsPerPage') {
      _itemsPerPage = value;
      _currentPage = 0;
    }
    if (key == 'showIchiMoe') _showIchiMoe = value;
    if (key == 'showWiktionary') _showWiktionary = value;
    if (key == 'showKanji') _showKanji = value;
    if (key == 'showEtymology') _showEtymology = value;
    if (key == 'searchLimit') _searchLimit = value;
    notifyListeners();
  }

  void setFilter(WordFilter filter) {
    _filter = filter;
    _currentPage = 0;
    notifyListeners();
  }

  void clearFilters() {
    _filter = WordFilter();
    _currentPage = 0;
    notifyListeners();
  }

  void setSortBy(WordSortBy sortBy, {bool? ascending}) {
    if (_sortBy == sortBy && ascending == null) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      if (ascending != null) _sortAscending = ascending;
    }
    notifyListeners();
  }

  void setGroupBy(WordGroupBy groupBy) {
    _groupBy = groupBy;
    notifyListeners();
  }

  // --- Pagination Methods ---

  void nextPage() {
    if (_currentPage < totalPages - 1) {
      _currentPage++;
      notifyListeners();
    }
  }

  void prevPage() {
    if (_currentPage > 0) {
      _currentPage--;
      notifyListeners();
    }
  }

  void firstPage() {
    _currentPage = 0;
    notifyListeners();
  }

  void lastPage() {
    if (totalPages > 0) {
      _currentPage = totalPages - 1;
      notifyListeners();
    }
  }

  // --- Search Methods ---

  Future<void> searchWord(String query) async {
    if (query.trim().isEmpty) return;
    _isSearching = true;
    notifyListeners();

    try {
      await addToHistory(query);
      HistoryService.instance.record(
        HistoryCategory.search,
        query,
        subtitle: _currentLanguage,
      );
      final results = await _yomichanService.lookupWord(
        query,
        _currentLanguage,
      );

      // profile-scoped dictionary settings: priority, conditions
      final dictSettings =
          appState?.yomitanOptions.activeProfile.dictionarySettings;
      final filtered = <YomichanSearchResult>[];
      for (final r in results) {
        final name = r.dictionary?.name ?? '';
        final s = dictSettings?.forDictionary(name);
        if (s != null && !s.enabled) continue;
        if (s != null && !s.hasNoConditions) {
          final matches = s.matches(
            term: r.entry.term,
            reading: r.entry.reading,
            lookupLanguage: _currentLanguage,
            tags: [...?r.entry.definitionTags, ...?r.entry.termTags],
          );
          if (!matches) continue;
        }
        filtered.add(r);
      }
      // sort: enabled/priority per profile settings
      final sorted = dictSettings == null
          ? filtered
          : dictSettings.sortResults(filtered, (r) => r.dictionary?.name ?? '');

      _searchResults = [
        for (final r in sorted) await _toAnalyzedWordRecursive(r, depth: 0),
      ];
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Build an AnalyzedWord from a search result, attaching nested
  /// entries found inside its definitions (recursive lookup, max
  /// depth [RecursiveLookup.maxDepth]).
  Future<AnalyzedWord> _toAnalyzedWordRecursive(
    YomichanSearchResult r, {
    required int depth,
  }) async {
    final word = AnalyzedWord(
      word: r.entry.word,
      reading: r.entry.reading,
      frequency: r.entry.frequency,
      ichiMoeDefinitions: r.entry.definitions
          .where((d) => d.isNotEmpty)
          .toList(),
      sourceDictionary: r.dictionary?.name,
    );

    if (depth >= RecursiveLookup.maxDepth - 1) return word;

    // find sub-terms in the definitions
    final subTerms = RecursiveLookup.extractSubTerms(r.entry);
    if (subTerms.isEmpty) return word;

    final nested = <AnalyzedWord>[];
    for (final term in subTerms.take(RecursiveLookup.maxChildrenPerEntry)) {
      try {
        final childResults = await _yomichanService.lookupWord(
          term,
          _currentLanguage,
        );
        if (childResults.isEmpty) continue;
        final child = await _toAnalyzedWordRecursive(
          childResults.first,
          depth: depth + 1,
        );
        if (child.word != word.word) nested.add(child);
      } catch (_) {
        // sub lookups are best-effort
      }
    }
    return word.copyWith(nestedEntries: nested);
  }

  Future<AnalyzedWord?> lookupHistoryWord(String word) async {
    try {
      final result = await _yomichanService.enrichWord(
        word,
        _currentLanguage,
        showIchiMoe: _showIchiMoe,
        showWiktionary: _showWiktionary,
        showKanji: _showKanji,
        showEtymology: _showEtymology,
      );
      if (result != null) {
        HistoryService.instance.record(
          HistoryCategory.word,
          word,
          subtitle: _currentLanguage,
        );
      }
      return result;
    } catch (e) {
      debugPrint('History word lookup error: $e');
      return null;
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // --- Analysis Methods ---

  Future<void> analyzeText(String text) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (text.length < 50) await addToHistory(text);
      HistoryService.instance.record(
        HistoryCategory.analysis,
        text.length > 60 ? '${text.substring(0, 60)}…' : text,
        subtitle: text,
      );

      final tokens = await _tokenizerService.tokenize(text);
      _sentences = _tokenizerService.splitSentences(tokens);

      // reset stale translations from a previous analysis
      _sentenceTranslations.clear();
      _fullTranslation = '';
      _lastTranslatedText = '';

      final uniqueTokens = tokens
          .toSet()
          .toList()
          .where((t) {
            final trimmed = t.surface.trim();
            return trimmed.isNotEmpty && !RegExp(r'^\d+$').hasMatch(trimmed);
          })
          .toList()
          .take(_searchLimit)
          .toList();

      _analyzedWords = [];

      const chunkSize = 5;
      for (var i = 0; i < uniqueTokens.length; i += chunkSize) {
        final chunk = uniqueTokens.sublist(
          i,
          i + chunkSize > uniqueTokens.length
              ? uniqueTokens.length
              : i + chunkSize,
        );

        final chunkResults = await Future.wait(
          chunk.map((token) async {
            final result = await _yomichanService.enrichWord(
              token.surface,
              _currentLanguage,
              showIchiMoe: _showIchiMoe,
              showWiktionary: _showWiktionary,
              showKanji: _showKanji,
              showEtymology: _showEtymology,
            );
            return result?.copyWith(sentence: _sentences[token.surface]);
          }),
        );

        _analyzedWords.addAll(chunkResults.whereType<AnalyzedWord>());
        notifyListeners();
      }

      // auto-translate when the setting is enabled
      if (appState?.autoTranslate ?? false) {
        await translateSentences();
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Dictionary Management ---

  Future<void> refreshDictionaries() async {
    final dicts = await _yomichanService.getDictionaries();
    _installedDictionaries = dicts.map((d) => d.toMap()).toList();
    notifyListeners();
  }

  Future<void> importDictionary() async {
    // Implementation would use file picker
  }

  Future<void> deleteDictionary(int id) async {
    await _yomichanService.deleteDictionary(id);
    await refreshDictionaries();
  }

  // --- Action Methods ---

  Future<void> saveWord(String word) async {
    final sentence = _sentences[word];
    await _yomichanService.saveWord(word, sentence: sentence);
    HistoryService.instance.record(
      HistoryCategory.action,
      word,
      subtitle: 'save_word',
    );
    await refreshUserData();
  }

  Future<void> removeSavedWord(String word) async {
    await _yomichanService.removeSavedWord(word);
    HistoryService.instance.record(
      HistoryCategory.action,
      word,
      subtitle: 'remove_word',
    );
    await refreshUserData();
  }

  Future<void> addToHistory(String word) async {
    await _yomichanService.addToHistory(word);
    await refreshUserData();
  }

  Future<void> playAudio(String text) async {
    await _yomichanService.playAudio(text, _currentLanguage);
  }

  // --- User Data ---

  Future<void> refreshUserData() async {
    _savedWords = await _yomichanService.getSavedWords();
    _history = await _yomichanService.getHistory();
    notifyListeners();
  }

  Future<void> init() async {
    try {
      await _yomichanService.init();
      await refreshDictionaries();
      await refreshUserData();
    } catch (e) {
      debugPrint('AnalyzerProvider init error: $e');
    }
    notifyListeners();
  }

  /// Restore persisted language preference into this provider
  void restoreLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  // --- Translation Methods ---

  /// Lazily build the translation service from app settings.
  Future<TranslationService> _ensureTranslationService() async {
    if (_translationService != null) return _translationService!;
    String? geminiKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('geminiApiKey') ?? '';
      if (raw.isNotEmpty) geminiKey = raw;
    } catch (_) {}
    _translationService = TranslationService(
      localService: LocalTranslationService(),
      geminiApiKey: geminiKey,
      provider:
          appState?.translationProvider ?? TranslationProvider.googleCloud,
    );
    return _translationService!;
  }

  /// UI language is the translation target; learning language the
  /// source. Falls back to 'en' for both.
  String get _targetLanguage => _uiLanguage();

  String _uiLanguage() {
    final ui = appState?.language ?? 'en';
    return ui.isEmpty ? 'en' : ui;
  }

  /// Translate every analyzed sentence. Results populate
  /// [getSentenceTranslation]; the full text translation joins
  /// them.
  Future<void> translateSentences() async {
    if (_sentences.isEmpty) return;
    final text = _sentences.values.join('\n\n');
    if (text == _lastTranslatedText && _sentenceTranslations.isNotEmpty) {
      return; // already translated this text
    }
    _isTranslating = true;
    notifyListeners();

    try {
      final service = await _ensureTranslationService();
      final result = await service.translate(
        TranslationRequest(
          sourceText: text,
          sourceLanguage: _currentLanguage,
          targetLanguage: _targetLanguage,
        ),
      );
      final full = result.fullTranslation.trim();
      if (full.isNotEmpty) {
        // Split full translation back onto sentences: the
        // service receives sentences joined with blank lines and
        // most engines keep the block structure.
        final blocks = full
            .split(RegExp(r'\n\s*\n'))
            .where((b) => b.trim().isNotEmpty)
            .toList();
        final keys = _sentences.keys.toList();
        if (blocks.length == keys.length) {
          for (var i = 0; i < keys.length; i++) {
            _sentenceTranslations[_sentences[keys[i]]!] = blocks[i].trim();
          }
        }
        _fullTranslation = full;
        _lastTranslatedText = text;
      }
    } catch (e) {
      debugPrint('Sentence translation error: $e');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Translation for one analyzed sentence ('' until translated).
  String getSentenceTranslation(String sentence) {
    return _sentenceTranslations[sentence] ?? '';
  }

  /// Full-text translation ('' until translated).
  String getFullTranslation() {
    return _fullTranslation;
  }

  bool get isTranslating => _isTranslating;

  /// Test hook: inject sentence map without running analysis.
  @visibleForTesting
  void testSetSentences(Map<String, String> sentences) {
    _sentences = sentences;
  }

  // --- Filter, Sort, Group Enums ---
}

class WordFilter {
  int? minFrequency;
  int? maxFrequency;
  bool? hasDefinition;
  bool? hasReading;
  bool? hasKanji;
  bool? isSaved;
  String? query;
  Set<int>? frequencyBands;

  WordFilter({
    this.minFrequency,
    this.maxFrequency,
    this.hasDefinition,
    this.hasReading,
    this.hasKanji,
    this.isSaved,
    this.query,
    this.frequencyBands,
  });

  WordFilter copyWith({
    int? minFrequency,
    int? maxFrequency,
    bool? hasDefinition,
    bool? hasReading,
    bool? hasKanji,
    bool? isSaved,
    String? query,
    Set<int>? frequencyBands,
  }) {
    return WordFilter(
      minFrequency: minFrequency ?? this.minFrequency,
      maxFrequency: maxFrequency ?? this.maxFrequency,
      hasDefinition: hasDefinition ?? this.hasDefinition,
      hasReading: hasReading ?? this.hasReading,
      hasKanji: hasKanji ?? this.hasKanji,
      isSaved: isSaved ?? this.isSaved,
      query: query ?? this.query,
      frequencyBands: frequencyBands ?? this.frequencyBands,
    );
  }

  bool get hasActiveFilters =>
      minFrequency != null ||
      maxFrequency != null ||
      hasDefinition != null ||
      hasReading != null ||
      hasKanji != null ||
      isSaved != null ||
      (query?.isNotEmpty ?? false) ||
      (frequencyBands?.isNotEmpty ?? false);

  int get activeFilterCount {
    int count = 0;
    if (minFrequency != null) count++;
    if (maxFrequency != null) count++;
    if (hasDefinition != null) count++;
    if (hasReading != null) count++;
    if (hasKanji != null) count++;
    if (isSaved != null) count++;
    if (query?.isNotEmpty ?? false) count++;
    if (frequencyBands?.isNotEmpty ?? false) count++;
    return count;
  }
}

enum WordSortBy {
  word,
  frequency,
  reading,
  kanjiCount,
  definitionCount,
  wordLength,
}

enum WordGroupBy {
  none,
  frequencyBand,
  firstChar,
  kanjiCount,
  hasReading,
  hasDefinition,
}
