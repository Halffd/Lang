import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/analyzed_word.dart';
import '../../domain/repositories/analyzer_repository.dart';

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

  int get totalPages {
    if (_analyzedWords.isEmpty) return 0;
    return (_analyzedWords.length / _itemsPerPage).ceil();
  }

  List<AnalyzedWord> get pagedWords {
    if (_analyzedWords.isEmpty) return [];
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage > _analyzedWords.length) ? _analyzedWords.length : start + _itemsPerPage;
    if (start >= _analyzedWords.length) return [];
    return _analyzedWords.sublist(start, end);
  }

  List<AnalyzedWord> get analyzedWords => _analyzedWords;
  Map<String, String> get sentences => _sentences;

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
      if (text.length < 50) await addToHistory(text); // Only add short texts/words to history
      
      final tokens = await _repository.tokenizeText(text, _currentLanguage);
      _sentences = _repository.splitSentences(tokens);
      
      final uniqueTokens = tokens.toSet().toList().where((t) {
        final trimmed = t.trim();
        return trimmed.isNotEmpty && !RegExp(r'^\d+$').hasMatch(trimmed);
      }).toList().take(_searchLimit).toList();
      
      _analyzedWords = [];
      
      // Parallelize lookups
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
    // This would typically use a translation service
    // For now, return empty string as placeholder
    // In a real implementation, this would call a translation API
    return '';
  }

  String getFullTranslation() {
    if (_sentences.isEmpty) return '';
    // Return concatenated translations
    return _sentences.values.join('\n\n');
  }
}
