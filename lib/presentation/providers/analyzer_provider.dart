import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/analyzed_word.dart';
import '../../domain/repositories/analyzer_repository.dart';

enum WordSortBy { word, frequency, reading, kanjiCount, definitionCount }
enum WordGroupBy { none, frequencyBand, firstChar, kanjiCount, hasReading, hasDefinition }

class WordFilter {
  final int? minFrequency;
  final int? maxFrequency;
  final bool? hasDefinition;
  final bool? hasReading;
  final bool? hasKanji;
  final bool? isSaved;
  final String? query;
  final Set<int>? frequencyBands; // 0: 1-1000, 1: 1001-5000, 2: 5001-15000, 3: 15001+

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

  bool _sortAscending = false; // frequency descending by default
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
    // Sort groups by key
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

  // --- Filter, Sort, Group State ---
  // --- Filter, Sort, Group State ---

  WordFilter _filter = WordFilter();
  WordFilter get filter => _filter;

  WordSortBy _sortBy = WordSortBy.frequency;
  WordSortBy get sortBy => _sortBy;

  bool _sortAscending = false;
  bool get sortAscending => _sortAscending;

  WordGroupBy _groupBy = WordGroupBy.none;
  WordGroupBy get groupBy => _groupBy;

  // Computed getters
  List<AnalyzedWord> get filteredWords {
    var words = _analyzedWords.where(_filter.matches).toList();
    
    words.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case WordSortBy.word:
          comparison = a.word.compareTo(b.word);
          break;
        case WordSortBy.frequency:
          comparison = (a.frequency ?? 999999).compareTo(b.frequency ?? 999999);
          break;
        case WordSortBy.reading:
          comparison = (a.reading ?? '').compareTo(b.reading ?? '');
          break;
        case WordSortBy.definitionCount:
          comparison = a.definitions.length.compareTo(b.definitions.length);
          break;
        case WordSortBy.kanjiCount:
          comparison = a.kanjiList.length.compareTo(b.kanjiList.length);
          break;
        case WordSortBy.wordLength:
          comparison = a.word.length.compareTo(b.word.length);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    return words;
  }

  List<AnalyzedWord> get words {
    return filteredWords;
  }

  int get totalPages {
    if (words.isEmpty) return 0;
    return (words.length / _itemsPerPage).ceil();
  }

  List<AnalyzedWord> get pagedWords {
    if (words.isEmpty) return [];
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage > words.length) ? words.length : start + _itemsPerPage;
    if (start >= words.length) return [];
    return words.sublist(start, end);
  }

  List<AnalyzedWord> get analyzedWords => _analyzedWords;
  Map<String, String> get sentences => _sentences;

  // Filter, Sort, Group Enums
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


// Filter, Sort, Group Enums

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
  int? minFrequency;
  int? maxFrequency;
  bool? hasDefinition;
  bool? hasReading;
  bool? hasKanji;
  int? minKanjiCount;
  int? maxKanjiCount;
  String? searchText;

  bool matches(AnalyzedWord word) {
    if (minFrequency != null && (word.frequency ?? 999999) < minFrequency!) return false;
    if (maxFrequency != null && (word.frequency ?? 999999) > maxFrequency!) return false;
    if (hasDefinition == true && word.definitions.isEmpty && word.ichiMoeDefinitions.isEmpty && word.wiktionaryHtml == null) return false;
    if (hasDefinition == false && (word.definitions.isNotEmpty || word.ichiMoeDefinitions.isNotEmpty || word.wiktionaryHtml != null)) return false;
    if (hasReading == true && (word.reading?.isEmpty ?? true) && (word.mdbgData?.pinyin.isEmpty ?? true)) return false;
    if (hasReading == false && ((word.reading?.isNotEmpty ?? false) || (word.mdbgData?.pinyin.isNotEmpty ?? false))) return false;
    if (hasKanji == true && word.kanjiList.isEmpty) return false;
    if (hasKanji == false && word.kanjiList.isNotEmpty) return false;
    if (minKanjiCount != null && word.kanjiList.length < minKanjiCount!) return false;
    if (maxKanjiCount != null && word.kanjiList.length > maxKanjiCount!) return false;
    if (searchText != null && searchText!.isNotEmpty) {
      final text = searchText!.toLowerCase();
      final wordLower = word.word.toLowerCase();
      final readingLower = (word.reading ?? ).toLowerCase();
      final pinyinLower = (word.mdbgData?.pinyin ?? ).toLowerCase();
      if (!wordLower.contains(text) && !readingLower.contains(text) && !pinyinLower.contains(text)) return false;
    }
    return true;
  }

  WordFilter copyWith({
    int? minFrequency,
    int? maxFrequency,
    bool? hasDefinition,
    bool? hasReading,
    bool? hasKanji,
    int? minKanjiCount,
    int? maxKanjiCount,
    String? searchText,
  }) {
    return WordFilter()
      ..minFrequency = minFrequency ?? this.minFrequency
      ..maxFrequency = maxFrequency ?? this.maxFrequency
      ..hasDefinition = hasDefinition ?? this.hasDefinition
      ..hasReading = hasReading ?? this.hasReading
      ..hasKanji = hasKanji ?? this.hasKanji
      ..minKanjiCount = minKanjiCount ?? this.minKanjiCount
      ..maxKanjiCount = maxKanjiCount ?? this.maxKanjiCount
      ..searchText = searchText ?? this.searchText;
  }
}
