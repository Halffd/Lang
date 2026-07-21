import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/analyzed_word.dart';
import '../../domain/repositories/analyzer_repository.dart';

enum WordSortBy {
  word,
  frequency,
  reading,
  definitionCount,
  kanjiCount,
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

class WordFilter {
  final int? minFrequency;
  final int? maxFrequency;
  final bool? hasDefinition;
  final bool? hasReading;
  final bool? hasKanji;
  final bool? isSaved;
  final String? query;
  final Set<int>? frequencyBands;

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

  bool matches(AnalyzedWord word) {
    if (minFrequency != null && (word.frequency ?? 999999) < minFrequency!) return false;
    if (maxFrequency != null && (word.frequency ?? 999999) > maxFrequency!) return false;
    if (hasDefinition == true && word.definitions.isEmpty && word.ichiMoeDefinitions.isEmpty && word.wiktionaryHtml == null) return false;
    if (hasDefinition == false && (word.definitions.isNotEmpty || word.ichiMoeDefinitions.isNotEmpty || word.wiktionaryHtml != null)) return false;
    if (hasReading == true && (word.reading?.isEmpty ?? true) && (word.mdbgData?.pinyin.isEmpty ?? true)) return false;
    if (hasReading == false && ((word.reading?.isNotEmpty ?? false) || (word.mdbgData?.pinyin.isNotEmpty ?? false))) return false;
    if (hasKanji == true && word.kanjiList.isEmpty) return false;
    if (hasKanji == false && word.kanjiList.isNotEmpty) return false;
    if (isSaved == true) {
      // Note: isSaved check requires savedWords from provider, can't be done here
    }
    if (query?.isNotEmpty ?? false) {
      final q = query!.toLowerCase();
      if (!word.word.toLowerCase().contains(q) &&
          !(word.reading?.toLowerCase().contains(q) ?? false) &&
          !(word.mdbgData?.pinyin.toLowerCase().contains(q) ?? false) &&
          !word.definitions.any((d) => d.toLowerCase().contains(q))) {
        return false;
      }
    }
    if (frequencyBands?.isNotEmpty ?? false) {
      final freq = word.frequency ?? 999999;
      int band;
      if (freq <= 1000) band = 0;
      else if (freq <= 5000) band = 1;
      else if (freq <= 15000) band = 2;
      else band = 3;
      if (!frequencyBands!.contains(band)) return false;
    }
    return true;
  }
}

class AnalyzerProvider with ChangeNotifier {
  final AnalyzerRepository _repository;

  AnalyzerProvider(this._repository);

  // Settings
  String _currentLanguage = 'ja';
  String get currentLanguage => _currentLanguage;

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

  // Filter, Sort, Group
  WordFilter _filter = WordFilter();
  WordFilter get filter => _filter;

  WordSortBy _sortBy = WordSortBy.frequency;
  WordSortBy get sortBy => _sortBy;

  bool _sortAscending = false;
  bool get sortAscending => _sortAscending;

  WordGroupBy _groupBy = WordGroupBy.none;
  WordGroupBy get groupBy => _groupBy;

  // Analysis State
  List<AnalyzedWord> _analyzedWords = [];
  Map<String, String> _sentences = {};

  // Search State
  List<AnalyzedWord> _searchResults = [];
  List<AnalyzedWord> get searchResults => _searchResults;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Pagination
  int _currentPage = 0;
  int get currentPage => _currentPage;

  // Computed: filtered, sorted, grouped words
  List<AnalyzedWord> get _filteredSortedWords {
    var words = List<AnalyzedWord>.from(_analyzedWords);

    // Apply filters
    if (_filter.minFrequency != null) {
      words = words.where((w) => (w.frequency ?? 999999) >= _filter.minFrequency!).toList();
    }
    if (_filter.maxFrequency != null) {
      words = words.where((w) => (w.frequency ?? 0) <= _filter.maxFrequency!).toList();
    }
    if (_filter.hasDefinition == true) {
      words = words.where((w) => w.definitions.isNotEmpty || w.ichiMoeDefinitions.isNotEmpty || w.wiktionaryHtml != null).toList();
    } else if (_filter.hasDefinition == false) {
      words = words.where((w) => w.definitions.isEmpty && w.ichiMoeDefinitions.isEmpty && w.wiktionaryHtml == null).toList();
    }
    if (_filter.hasReading == true) {
      words = words.where((w) => (w.reading?.isNotEmpty ?? false) || (w.mdbgData?.pinyin.isNotEmpty ?? false)).toList();
    } else if (_filter.hasReading == false) {
      words = words.where((w) => (w.reading?.isEmpty ?? true) && (w.mdbgData?.pinyin.isEmpty ?? true)).toList();
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
      words = words.where((w) =>
        w.word.toLowerCase().contains(q) ||
        (w.reading?.toLowerCase().contains(q) ?? false) ||
        (w.mdbgData?.pinyin.toLowerCase().contains(q) ?? false) ||
        w.definitions.any((d) => d.toLowerCase().contains(q))
      ).toList();
    }
    if (_filter.frequencyBands?.isNotEmpty ?? false) {
      words = words.where((w) {
        final freq = w.frequency ?? 999999;
        int band;
        if (freq <= 1000) band = 0;
        else if (freq <= 5000) band = 1;
        else if (freq <= 15000) band = 2;
        else band = 3;
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
          cmp = a.definitions.length.compareTo(b.definitions.length);
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
    final end = (start + _itemsPerPage > words.length) ? words.length : start + _itemsPerPage;
    if (start >= words.length) return [];
    return words.sublist(start, end);
  }

  int get totalPages {
    final words = _filteredSortedWords;
    if (words.isEmpty) return 0;
    return (words.length / _itemsPerPage).ceil();
  }

  List<AnalyzedWord> get analyzedWords => _analyzedWords;
  Map<String, String> get sentences => _sentences;

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
          if (freq <= 1000) key = 'Top 1K (Very Common)';
          else if (freq <= 5000) key = '1K-5K (Common)';
          else if (freq <= 15000) key = '5K-15K (Uncommon)';
          else key = '15K+ (Rare)';
          break;
        case WordGroupBy.firstChar:
          key = word.word.isNotEmpty ? word.word[0].toUpperCase() : '?';
          break;
        case WordGroupBy.kanjiCount:
          key = '${word.kanjiList.length} Kanji';
          break;
        case WordGroupBy.hasReading:
          key = (word.reading?.isNotEmpty ?? false) || (word.mdbgData?.pinyin.isNotEmpty ?? false) ? 'Has Reading' : 'No Reading';
          break;
        case WordGroupBy.hasDefinition:
          key = (word.definitions.isNotEmpty || word.ichiMoeDefinitions.isNotEmpty || word.wiktionaryHtml != null) ? 'Has Definition' : 'No Definition';
          break;
        default:
          key = 'All';
      }
      groups.putIfAbsent(key, () => []).add(word);
    }
    final sortedKeys = groups.keys.toList()..sort();
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, groups[k]!)));
  }

  // Dictionary Management
  List<Map<String, dynamic>> _installedDictionaries = [];
  List<Map<String, dynamic>> get installedDictionaries => _installedDictionaries;

  // User Data
  List<Map<String, dynamic>> _savedWords = [];
  List<Map<String, dynamic>> get savedWords => _savedWords;

  List<String> _history = [];
  List<String> get history => _history;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    await _repository.init();
    final settings = await _repository.getSettings();
    _itemsPerRow = settings['itemsPerRow'] ?? 2;
    _itemsPerPage = settings['itemsPerPage'] ?? 50;
    _showIchiMoe = settings['showIchiMoe'] ?? true;
    _showWiktionary = settings['showWiktionary'] ?? true;
    _showKanji = settings['showKanji'] ?? true;
    _showEtymology = settings['showEtymology'] ?? true;
    _searchLimit = settings['searchLimit'] ?? 100;
    await refreshDictionaries();
    await refreshUserData();
  }

  Future<void> refreshUserData() async {
    _savedWords = await _repository.getSavedWords();
    _history = await _repository.getHistory();
    notifyListeners();
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

    await _repository.saveSettings({key: value});
    notifyListeners();
  }

  // --- Search Methods ---

  Future<void> searchWord(String query) async {
    if (query.trim().isEmpty) return;
    _isSearching = true;
    notifyListeners();

    try {
      await addToHistory(query);
      _searchResults = await _repository.lookupWord(query, _currentLanguage);
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
      final result = await _repository.enrichWord(
        word,
        _currentLanguage,
        showIchiMoe: _showIchiMoe,
        showWiktionary: _showWiktionary,
        showKanji: _showKanji,
        showEtymology: _showEtymology,
      );
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

      final tokens = await _repository.tokenizeText(text, _currentLanguage);
      _sentences = _repository.splitSentences(tokens);

      final uniqueTokens = tokens.toSet().toList().where((t) {
        final trimmed = t.trim();
        return trimmed.isNotEmpty && !RegExp(r'^\d+$').hasMatch(trimmed);
      }).toList().take(_searchLimit).toList();

      _analyzedWords = [];

      const chunkSize = 5;
      for (var i = 0; i < uniqueTokens.length; i += chunkSize) {
        final chunk = uniqueTokens.sublist(i, i + chunkSize > uniqueTokens.length ? uniqueTokens.length : i + chunkSize);

        final chunkResults = await Future.wait(chunk.map((token) async {
          final result = await _repository.enrichWord(
            token,
            _currentLanguage,
            showIchiMoe: _showIchiMoe,
            showWiktionary: _showWiktionary,
            showKanji: _showKanji,
            showEtymology: _showEtymology,
          );

          return result.copyWith(sentence: _sentences[token]);
        }));

        _analyzedWords.addAll(chunkResults);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  // --- Filter, Sort, Group Methods ---

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

  void clearAnalysis() {
    _analyzedWords = [];
    _sentences = {};
    _currentPage = 0;
    notifyListeners();
  }

  // --- Dictionary Management ---

  Future<void> refreshDictionaries() async {
    _installedDictionaries = await _repository.getInstalledDictionaries();
    notifyListeners();
  }

  Future<void> importDictionary() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final bytes = result.files.single.bytes ?? Uint8List.fromList(await result.files.single.xFile.readAsBytes());
        await _repository.importDictionary(bytes);
        await refreshDictionaries();
      } catch (e) {
        debugPrint('Import error: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteDictionary(String title) async {
    await _repository.deleteDictionary(title);
    await refreshDictionaries();
  }

  // --- Action Methods ---

  Future<void> saveWord(String word) async {
    final sentence = _sentences[word];
    await _repository.saveWord(word, sentence: sentence);
    await refreshUserData();
  }

  Future<void> removeSavedWord(String word) async {
    await _repository.removeSavedWord(word);
    await refreshUserData();
  }

  Future<void> addToHistory(String word) async {
    await _repository.addToHistory(word);
    await refreshUserData();
  }

  Future<void> playAudio(String text) async {
    await _repository.playAudio(text, _currentLanguage);
  }

  // --- Translation Methods ---

  String getSentenceTranslation(String sentence) {
    return '';
  }

  String getFullTranslation() {
    if (_sentences.isEmpty) return '';
    return _sentences.values.join('\n\n');
  }
}