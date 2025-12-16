import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storageService;
  
  // App settings
  bool _clipboardMonitor = false;
  bool _automaticKanaConversion = true;
  String _language = 'ja';
  bool _darkMode = false;
  bool _showParticles = true;
  bool _showKanji = true;
  int _minFrequency = -1;
  bool _autoHideNavigation = true;
  bool _defaultFlexMode = false;
  
  // Search state
  String _currentQuery = '';
  List<String> _searchHistory = [];
  String _currentProfile = 'Default';
  
  // Saved words
  List<String> _savedWords = [];
  Map<String, dynamic> _savedWordsDetails = {};

  // Favorite words
  List<String> _favoriteWords = [];

  // Anki words
  List<String> _ankiWords = [];

  AppState(this._storageService) {
    _loadSettings();
    _loadSavedWords();
    _loadFavoriteWords();
    _loadAnkiWords();
  }

  // Getters
  bool get clipboardMonitor => _clipboardMonitor;
  bool get automaticKanaConversion => _automaticKanaConversion;
  String get language => _language;
  bool get darkMode => _darkMode;
  bool get showParticles => _showParticles;
  bool get showKanji => _showKanji;
  int get minFrequency => _minFrequency;
  bool get autoHideNavigation => _autoHideNavigation;
  bool get defaultFlexMode => _defaultFlexMode;
  String get currentQuery => _currentQuery;
  List<String> get searchHistory => _searchHistory;
  String get currentProfile => _currentProfile;
  List<String> get savedWords => _savedWords;
  Map<String, dynamic> get savedWordsDetails => _savedWordsDetails;
  List<String> get favoriteWords => _favoriteWords;
  List<String> get ankiWords => _ankiWords;
  
  // Setters with persistence
  void setClipboardMonitor(bool value) {
    _clipboardMonitor = value;
    _storageService.setBool('clipboard_monitor', value);
    notifyListeners();
  }
  
  void setAutomaticKanaConversion(bool value) {
    _automaticKanaConversion = value;
    _storageService.setBool('automatic_kana_conversion', value);
    notifyListeners();
  }
  
  void setLanguage(String value) {
    _language = value;
    _storageService.setString('language', value);
    notifyListeners();
  }
  
  void setDarkMode(bool value) {
    _darkMode = value;
    _storageService.setBool('dark_mode', value);
    notifyListeners();
  }
  
  void setShowParticles(bool value) {
    _showParticles = value;
    _storageService.setBool('show_particles', value);
    notifyListeners();
  }
  
  void setShowKanji(bool value) {
    _showKanji = value;
    _storageService.setBool('show_kanji', value);
    notifyListeners();
  }
  
  void setMinFrequency(int value) {
    _minFrequency = value;
    _storageService.setInt('min_frequency', value);
    notifyListeners();
  }

  void setAutoHideNavigation(bool value) {
    _autoHideNavigation = value;
    _storageService.setBool('auto_hide_navigation', value);
    notifyListeners();
  }

  void setDefaultFlexMode(bool value) {
    _defaultFlexMode = value;
    _storageService.setBool('default_flex_mode', value);
    notifyListeners();
  }
  
  void setCurrentProfile(String value) {
    _currentProfile = value;
    _storageService.setString('current_profile', value);
    notifyListeners();
  }
  
  void setCurrentQuery(String value) {
    _currentQuery = value;
    notifyListeners();
  }

  // Word management
  void addSavedWord(String word, {Map<String, dynamic>? details}) {
    if (!_savedWords.contains(word)) {
      _savedWords.add(word);
      if (details != null) {
        _savedWordsDetails[word] = details;
      }
      _persistSavedWords();
      notifyListeners();
    }
  }

  void removeSavedWord(String word) {
    _savedWords.remove(word);
    _savedWordsDetails.remove(word);
    _persistSavedWords();
    notifyListeners();
  }

  void addFavoriteWord(String word) {
    if (!_favoriteWords.contains(word)) {
      _favoriteWords.add(word);
      _persistFavoriteWords();
      notifyListeners();
    }
  }

  void removeFavoriteWord(String word) {
    _favoriteWords.remove(word);
    _persistFavoriteWords();
    notifyListeners();
  }

  void addAnkiWord(String word) {
    if (!_ankiWords.contains(word)) {
      _ankiWords.add(word);
      _persistAnkiWords();
      notifyListeners();
    }
  }

  void removeAnkiWord(String word) {
    _ankiWords.remove(word);
    _persistAnkiWords();
    notifyListeners();
  }
  
  void addToSearchHistory(String query) {
    if (query.isNotEmpty && !_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 50) {
        _searchHistory.removeLast();
      }
      _storageService.setStringList('search_history', _searchHistory);
      notifyListeners();
    }
  }

  // Private methods
  void _loadSettings() {
    _clipboardMonitor = _storageService.getBool('clipboard_monitor') ?? false;
    _automaticKanaConversion = _storageService.getBool('automatic_kana_conversion') ?? true;
    _language = _storageService.getString('language') ?? 'ja';
    _darkMode = _storageService.getBool('dark_mode') ?? false;
    _showParticles = _storageService.getBool('show_particles') ?? true;
    _showKanji = _storageService.getBool('show_kanji') ?? true;
    _minFrequency = _storageService.getInt('min_frequency') ?? -1;
    _autoHideNavigation = _storageService.getBool('auto_hide_navigation') ?? true;
    _defaultFlexMode = _storageService.getBool('default_flex_mode') ?? false;
    _currentProfile = _storageService.getString('current_profile') ?? 'Default';
    _searchHistory = _storageService.getStringList('search_history') ?? [];
  }

  void _loadSavedWords() {
    _savedWords = _storageService.getStringList('saved_words') ?? [];
    final savedDetailsJson = _storageService.getString('saved_words_details');
    if (savedDetailsJson != null) {
      try {
        _savedWordsDetails = Map<String, dynamic>.from(_storageService.getJson('saved_words_details') ?? {});
      } catch (e) {
        _savedWordsDetails = {};
      }
    }
  }

  void _loadFavoriteWords() {
    _favoriteWords = _storageService.getStringList('favorite_words') ?? [];
  }

  void _loadAnkiWords() {
    _ankiWords = _storageService.getStringList('anki_words') ?? [];
  }

  void _persistSavedWords() {
    _storageService.setStringList('saved_words', _savedWords);
    _storageService.setJson('saved_words_details', _savedWordsDetails);
  }

  void _persistFavoriteWords() {
    _storageService.setStringList('favorite_words', _favoriteWords);
  }

  void _persistAnkiWords() {
    _storageService.setStringList('anki_words', _ankiWords);
  }
}
