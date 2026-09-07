import 'package:flutter/material.dart';
import 'package:lang/data/services/dictionary/local_dictionary_service.dart';
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/data/services/dictionary/remote_dictionary_service.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';
import 'package:lang/data/services/dictionary/search_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';

/// Unified dictionary service that delegates to specialized services
class AnalyzerProvider extends ChangeNotifier {
  final LocalDictionaryService _localService = LocalDictionaryService();
  final YomichanService _yomichanService = YomichanService();
  final RemoteDictionaryService _remoteService = RemoteDictionaryService();
  final LanguageDetector _languageDetector = LanguageDetector();
  final TokenizerService _tokenizerService = TokenizerService();
  final SearchService _searchService = SearchService();

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
    final orphans =
        _filteredSortedWords.where((w) => !used.contains(w.word)).toList();
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
    if (_selectedSentenceIndex < 0 ||
        _selectedSentenceIndex >= sents.length) {
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
      final wIdx =
          words.indexWhere((w) => (w.sentence ?? '').trim() == sents[index]);
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
      final results = await _yomichanService.lookupWord(
        query,
        _currentLanguage,
      );
      _searchResults = results
          .map(
            (r) => AnalyzedWord(
              word: r.entry.word,
              reading: r.entry.reading,
              frequency: r.entry.frequency,
              ichiMoeDefinitions: r.entry.definitions
                  .where((d) => d.isNotEmpty)
                  .toList(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<AnalyzedWord?> lookupHistoryWord(String word) async {
    try {
      return await _yomichanService.enrichWord(
        word,
        _currentLanguage,
        showIchiMoe: _showIchiMoe,
        showWiktionary: _showWiktionary,
        showKanji: _showKanji,
        showEtymology: _showEtymology,
      );
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

      final tokens = await _tokenizerService.tokenize(text);
      _sentences = _tokenizerService.splitSentences(tokens);

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
    await refreshUserData();
  }

  Future<void> removeSavedWord(String word) async {
    await _yomichanService.removeSavedWord(word);
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

  String getSentenceTranslation(String sentence) {
    // This would typically use a translation service
    return '';
  }

  String getFullTranslation() {
    if (_sentences.isEmpty) return '';
    return _sentences.values.join('\n\n');
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
