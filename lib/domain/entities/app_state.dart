import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import 'yomitan_options.dart';
import 'anki_note_types.dart';
import 'dictionary_display_options.dart';
import '../../data/repositories/translation_service.dart';
import 'translation_model.dart';

/// What the clipboard monitor does with detected text.
enum ClipboardAutoSearchMode {
  /// record to activity history only, never search
  historyOnly,

  /// record and automatically run a dictionary search
  autoSearch,

  /// disabled entirely
  off,
}

class AppState extends ChangeNotifier {
  final StorageService _storageService;

  // App settings
  bool _clipboardMonitor = false;
  String _language = 'ja';
  String _learningLanguage = 'ja';
  YomitanOptions? _yomitanOptions;
  AnkiNoteTypes? _ankiNoteTypes;
  DictionaryDisplayOptions? _dictionaryDisplayOptions;
  bool _darkMode = false;
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  bool _showParticles = true;
  bool _showKanji = true;
  int _minFrequency = -1;
  bool _autoHideNavigation = true;
  double _zoomLevel = 1.0; // Default zoom level
  double _fontSizeMultiplier = 1.0; // Default font size multiplier
  bool _defaultFlexMode = false;
  int _defaultScreenIndex = 0; // Default to 0 (Search screen)
  List<String> _etymologyLanguages = [
    'en',
    'zh',
    'ja',
  ]; // Default languages for etymology

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

  // AnkiConnect
  String _ankiConnectUrl = 'http://127.0.0.1:8765';
  bool _ankiConnectEnabled = false;
  String _ankiConnectModel = 'Basic';
  bool _ankiSyncOnSave = false;

  AppState(this._storageService) {
    _loadSettings();
    Future.microtask(() => _loadSavedWords());
    _loadFavoriteWords();
    _loadAnkiWords();
    _loadDeletedWords();
  }

  // Getters
  bool get clipboardMonitor => _clipboardMonitor;
  String get language => _language;
  String get learningLanguage => _learningLanguage;
  YomitanOptions get yomitanOptions =>
      _yomitanOptions ??= YomitanOptions.deserialize(
        _storageService.getStringSync('yomitan_options'),
      );
  AnkiNoteTypes get ankiNoteTypes =>
      _ankiNoteTypes ??= AnkiNoteTypes.deserialize(
        _storageService.getStringSync('anki_note_types'),
      );
  DictionaryDisplayOptions get dictionaryDisplayOptions =>
      _dictionaryDisplayOptions ??= DictionaryDisplayOptions.deserialize(
        _storageService.getStringSync('dictionary_display_options'),
      );
  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _themeMode;
  bool get showParticles => _showParticles;
  bool get showKanji => _showKanji;
  int get minFrequency => _minFrequency;
  bool get autoHideNavigation => _autoHideNavigation;
  bool get defaultFlexMode => _defaultFlexMode;
  double get zoomLevel => _zoomLevel;
  double get fontSizeMultiplier => _fontSizeMultiplier;
  String get currentQuery => _currentQuery;
  List<String> get searchHistory => _searchHistory;
  String get currentProfile => _currentProfile;
  List<String> get savedWords => _savedWords;
  Map<String, dynamic> get savedWordsDetails => _savedWordsDetails;
  List<String> get favoriteWords => _favoriteWords;
  List<String> get ankiWords => _ankiWords;
  String get ankiConnectUrl => _ankiConnectUrl;
  bool get ankiConnectEnabled => _ankiConnectEnabled;
  String get ankiConnectModel => _ankiConnectModel;
  bool get ankiSyncOnSave => _ankiSyncOnSave;
  List<String> get etymologyLanguages => _etymologyLanguages;
  bool get autoTranslate => _autoTranslate;
  List<String> get ankiDecks => _ankiDecks;
  String get currentAnkiDeck => _currentAnkiDeck;
  List<String> get profiles => _profiles;
  bool get clipboardAutoDetect => _clipboardAutoDetect;
  ClipboardAutoSearchMode get clipboardAutoSearchMode =>
      _clipboardAutoSearchMode;
  bool get clipboardAutoSearchFocusedOnly => _clipboardAutoSearchFocusedOnly;
  String get clipboardAutoSearchRegex => _clipboardAutoSearchRegex;
  bool get forvoAudioEnabled => _forvoAudioEnabled;
  String get forvoApiKey => _forvoApiKey;
  bool get autoConvertJapanese => _autoConvertJapanese;
  int get defaultScreenIndex => _defaultScreenIndex;
  bool get autoPasteReader => _autoPasteReader;
  bool get showWiktionary => _showWiktionary;
  bool get showInlineDefinitions => _showInlineDefinitions;
  bool get showHoverDefinitions => _showHoverDefinitions;
  bool get useLocalTranslation => _useLocalTranslation;
  TranslationProvider get translationProvider => _translationProvider;

  // Popup settings
  double get hoverPopupSize => _hoverPopupSize;
  int get hoverPopupDelay => _hoverPopupDelay;
  String get hoverPopupModifier => _hoverPopupModifier;
  List<String> get hoverPopupLanguages => _hoverPopupLanguages;

  // Profile activation
  String get profileActivationScreen => _profileActivationScreen;
  String get profileActivationApp => _profileActivationApp;

  // Expose storage service for mixins
  StorageService get storageService => _storageService;

  bool _autoTranslate = false;
  List<String> _ankiDecks = ['Default'];
  String _currentAnkiDeck = 'Default';
  bool _clipboardAutoDetect = false;
  // what the clipboard monitor does with detected text
  ClipboardAutoSearchMode _clipboardAutoSearchMode =
      ClipboardAutoSearchMode.historyOnly;
  // auto-search only when an app window has focus
  bool _clipboardAutoSearchFocusedOnly = false;
  // optional custom regex; clipboard text must match to trigger search
  String _clipboardAutoSearchRegex = '';
  bool _forvoAudioEnabled = false;
  String _forvoApiKey = '';
  bool _autoConvertJapanese =
      true; // Default to auto-convert letters to Japanese
  List<String> _profiles = ['Default'];
  bool _autoPasteReader = false; // Auto-paste from clipboard in reader mode
  bool _showWiktionary = true; // Show Wiktionary definitions by default
  bool _showInlineDefinitions = true; // Show definition text below each word
  bool _showHoverDefinitions = true; // Show definition popup on hover
  bool _useLocalTranslation = false; // Use on-device ML Kit translation
  TranslationProvider _translationProvider = TranslationProvider.googleCloud;

  // Popup settings
  double _hoverPopupSize = 1.0; // 1.0 = normal, 0.5 = half, 2.0 = double
  int _hoverPopupDelay = 300; // ms before showing popup
  String _hoverPopupModifier = 'none'; // 'none', 'ctrl', 'shift', 'alt'
  List<String> _hoverPopupLanguages = []; // empty = all languages

  // Profile activation
  String _profileActivationScreen =
      'all'; // 'all', 'search', 'reader', 'srs', 'browser'
  String _profileActivationApp = 'default'; // 'default', 'srs', 'browser'

  // Setters with persistence

  void setClipboardMonitor(bool value) {
    _clipboardMonitor = value;
    _storageService.setBool('clipboard_monitor', value);
    notifyListeners();
  }

  void setLanguage(String value) {
    _language = value;
    _storageService.setString('language', value);
    notifyListeners();
  }

  void setLearningLanguage(String value) {
    _learningLanguage = value;
    _storageService.setString('learning_language', value);
    notifyListeners();
  }

  void setYomitanOptions(YomitanOptions options) {
    _yomitanOptions = options;
    _storageService.setString('yomitan_options', options.serialize());
    notifyListeners();
  }

  void setAnkiNoteTypes(AnkiNoteTypes types) {
    _ankiNoteTypes = types;
    _storageService.setString('anki_note_types', types.serialize());
    notifyListeners();
  }

  void setDictionaryDisplayOptions(DictionaryDisplayOptions options) {
    _dictionaryDisplayOptions = options;
    _storageService.setString(
      'dictionary_display_options',
      options.serialize(),
    );
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    _storageService.setBool('dark_mode', value);
    notifyListeners();
  }

  ThemeMode? _parseThemeMode(String? themeModeString) {
    if (themeModeString == null) return null;

    switch (themeModeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    // Save as string since ThemeMode isn't directly supported by shared preferences
    _storageService.setString('theme_mode', mode.toString());
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

  void setZoomLevel(double zoom) {
    // Limit zoom between 0.5 and 3.0
    _zoomLevel = zoom.clamp(0.5, 3.0);
    _storageService.setDouble('zoom_level', _zoomLevel);
    notifyListeners();
  }

  void setFontSizeMultiplier(double multiplier) {
    // Limit font size between 0.8 and 2.0
    _fontSizeMultiplier = multiplier.clamp(0.8, 2.0);
    _storageService.setDouble('font_size_multiplier', _fontSizeMultiplier);
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

  void setEtymologyLanguages(List<String> languages) {
    _etymologyLanguages = languages;
    _storageService.setStringList('etymology_languages', languages);
    notifyListeners();
  }

  void setAutoTranslate(bool value) {
    _autoTranslate = value;
    _storageService.setBool('auto_translate', value);
    notifyListeners();
  }

  void setAnkiDecks(List<String> decks) {
    _ankiDecks = decks;
    _storageService.setStringList('anki_decks', decks);
    notifyListeners();
  }

  void setCurrentAnkiDeck(String deckName) {
    _currentAnkiDeck = deckName;
    _storageService.setString('current_anki_deck', deckName);
    notifyListeners();
  }

  void addAnkiDeck(String deckName) {
    if (!_ankiDecks.contains(deckName)) {
      _ankiDecks.add(deckName);
      _storageService.setStringList('anki_decks', _ankiDecks);
      notifyListeners();
    }
  }

  void removeAnkiDeck(String deckName) {
    if (_ankiDecks.length > 1 && _ankiDecks.contains(deckName)) {
      // Don't remove last deck
      _ankiDecks.remove(deckName);
      if (_currentAnkiDeck == deckName) {
        _currentAnkiDeck = _ankiDecks.first; // Switch to first deck
        _storageService.setString('current_anki_deck', _currentAnkiDeck);
      }
      _storageService.setStringList('anki_decks', _ankiDecks);
      notifyListeners();
    }
  }

  void setAnkiConnectUrl(String value) {
    _ankiConnectUrl = value;
    _storageService.setString('anki_connect_url', value);
    notifyListeners();
  }

  void setAnkiConnectEnabled(bool value) {
    _ankiConnectEnabled = value;
    _storageService.setBool('anki_connect_enabled', value);
    notifyListeners();
  }

  void setAnkiConnectModel(String value) {
    _ankiConnectModel = value;
    _storageService.setString('anki_connect_model', value);
    notifyListeners();
  }

  void setAnkiSyncOnSave(bool value) {
    _ankiSyncOnSave = value;
    _storageService.setBool('anki_sync_on_save', value);
    notifyListeners();
  }

  // Profile management
  void setProfiles(List<String> profiles) {
    _profiles = profiles;
    _storageService.setStringList('profiles', profiles);
    notifyListeners();
  }

  void addProfile(String profileName) {
    if (!_profiles.contains(profileName)) {
      _profiles.add(profileName);
      _storageService.setStringList('profiles', _profiles);
      notifyListeners();
    }
  }

  void removeProfile(String profileName) {
    if (_profiles.length > 1 && _profiles.contains(profileName)) {
      // Don't remove last profile
      _profiles.remove(profileName);
      if (_currentProfile == profileName) {
        _currentProfile = _profiles.first; // Switch to first profile
        _storageService.setString('current_profile', _currentProfile);
      }
      _storageService.setStringList('profiles', _profiles);
      notifyListeners();
    }
  }

  void setClipboardAutoDetect(bool value) {
    _clipboardAutoDetect = value;
    _storageService.setBool('clipboard_auto_detect', value);
    notifyListeners();
  }

  void setClipboardAutoSearchMode(ClipboardAutoSearchMode value) {
    _clipboardAutoSearchMode = value;
    _storageService.setString('clipboard_auto_search_mode', value.name);
    notifyListeners();
  }

  void setClipboardAutoSearchFocusedOnly(bool value) {
    _clipboardAutoSearchFocusedOnly = value;
    _storageService.setBool('clipboard_auto_search_focused_only', value);
    notifyListeners();
  }

  void setClipboardAutoSearchRegex(String value) {
    _clipboardAutoSearchRegex = value;
    _storageService.setString('clipboard_auto_search_regex', value);
    notifyListeners();
  }

  void setForvoAudioEnabled(bool value) {
    _forvoAudioEnabled = value;
    _storageService.setBool('forvo_audio_enabled', value);
    notifyListeners();
  }

  void setForvoApiKey(String value) {
    _forvoApiKey = value;
    _storageService.setString('forvo_api_key', value);
    notifyListeners();
  }

  void setAutoConvertJapanese(bool value) {
    _autoConvertJapanese = value;
    _storageService.setBool('auto_convert_japanese', value);
    notifyListeners();
  }

  void setDefaultScreenIndex(int value) {
    // Ensure value is within valid range (0-6 for the 7 screens)
    if (value >= 0 && value <= 6) {
      _defaultScreenIndex = value;
      _storageService.setInt('default_screen_index', value);
      notifyListeners();
    }
  }

  void setAutoPasteReader(bool value) {
    _autoPasteReader = value;
    _storageService.setBool('auto_paste_reader', value);
    notifyListeners();
  }

  void setShowWiktionary(bool value) {
    _showWiktionary = value;
    _storageService.setBool('show_wiktionary', value);
    notifyListeners();
  }

  void setShowInlineDefinitions(bool value) {
    _showInlineDefinitions = value;
    _storageService.setBool('show_inline_definitions', value);
    notifyListeners();
  }

  void setShowHoverDefinitions(bool value) {
    _showHoverDefinitions = value;
    _storageService.setBool('show_hover_definitions', value);
    notifyListeners();
  }

  void setUseLocalTranslation(bool value) {
    _useLocalTranslation = value;
    _storageService.setBool('use_local_translation', value);
    notifyListeners();
  }

  void setTranslationProvider(TranslationProvider value) {
    _translationProvider = value;
    _storageService.setString('translation_provider', value.name);
    notifyListeners();
  }

  void setHoverPopupSize(double value) {
    _hoverPopupSize = value;
    _storageService.setDouble('hover_popup_size', value);
    notifyListeners();
  }

  void setHoverPopupDelay(int value) {
    _hoverPopupDelay = value;
    _storageService.setInt('hover_popup_delay', value);
    notifyListeners();
  }

  void setHoverPopupModifier(String value) {
    _hoverPopupModifier = value;
    _storageService.setString('hover_popup_modifier', value);
    notifyListeners();
  }

  void setHoverPopupLanguages(List<String> value) {
    _hoverPopupLanguages = value;
    _storageService.setStringList('hover_popup_languages', value);
    notifyListeners();
  }

  void setProfileActivationScreen(String value) {
    _profileActivationScreen = value;
    _storageService.setString('profile_activation_screen', value);
    notifyListeners();
  }

  void setProfileActivationApp(String value) {
    _profileActivationApp = value;
    _storageService.setString('profile_activation_app', value);
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
    try {
      _clipboardMonitor = _storageService.getBool('clipboard_monitor') ?? false;
      _language = _storageService.getStringSync('language') ?? 'ja';
      _learningLanguage =
          _storageService.getStringSync('learning_language') ?? _language;
      // Ensure language code is valid - fix any legacy data that might have display names instead of codes
      if (!LanguageOption.all.any((option) => option.code == _language)) {
        // If the saved language is not a valid code, it might be a display name
        // Look it up in a simple mapping to convert it back to a code
        final languageMap = {
          'Japanese': 'ja',
          'Chinese': 'zh',
          'Korean': 'ko',
          'English': 'en',
          'French': 'fr',
          'Spanish': 'es',
          'German': 'de',
          'Italian': 'it',
          'Portuguese': 'pt',
          'Russian': 'ru',
          'Arabic': 'ar',
          'Hindi': 'hi',
          'Afrikaans': 'af',
          'Bulgarian': 'bg',
          'Catalan': 'ca',
          'Croatian': 'hr',
          'Czech': 'cs',
          'Danish': 'da',
          'Dutch': 'nl',
          'Estonian': 'et',
          'Filipino': 'tl',
          'Finnish': 'fi',
          'Greek': 'el',
          'Hebrew': 'iw',
          'Hungarian': 'hu',
          'Indonesian': 'id',
          'Latvian': 'lv',
          'Lithuanian': 'lt',
          'Norwegian': 'no',
          'Polish': 'pl',
          'Romanian': 'ro',
          'Serbian': 'sr',
          'Slovak': 'sk',
          'Slovenian': 'sl',
          'Swedish': 'sv',
          'Thai': 'th',
          'Turkish': 'tr',
          'Ukrainian': 'uk',
          'Vietnamese': 'vi',
        };

        final correctedCode = languageMap[_language] ?? 'ja';
        _language = correctedCode;
        // Update the saved value to be correct
        _storageService.setString('language', _language);
        // Notify listeners so the UI updates with the corrected language
        notifyListeners();
      }
      _darkMode = _storageService.getBool('dark_mode') ?? false;
      // Load theme mode with fallback to system
      final themeModeString = _storageService.getStringSync('theme_mode');
      _themeMode = _parseThemeMode(themeModeString) ?? ThemeMode.system;
      _showParticles = _storageService.getBool('show_particles') ?? true;
      _showKanji = _storageService.getBool('show_kanji') ?? true;
      _minFrequency = _storageService.getInt('min_frequency') ?? -1;
      _autoHideNavigation =
          _storageService.getBool('auto_hide_navigation') ?? true;
      _defaultFlexMode = _storageService.getBool('default_flex_mode') ?? false;
      _zoomLevel = _storageService.getDouble('zoom_level') ?? 1.0;
      _fontSizeMultiplier =
          _storageService.getDouble('font_size_multiplier') ?? 1.0;
      _currentProfile =
          _storageService.getStringSync('current_profile') ?? 'Default';
      _searchHistory = _storageService.getStringList('search_history') ?? [];
      _etymologyLanguages =
          _storageService.getStringList('etymology_languages') ??
          ['en', 'zh', 'ja'];
      _autoTranslate = _storageService.getBool('auto_translate') ?? false;
      _ankiDecks = _storageService.getStringList('anki_decks') ?? ['Default'];
      _currentAnkiDeck =
          _storageService.getStringSync('current_anki_deck') ?? 'Default';
      _ankiConnectUrl =
          _storageService.getStringSync('anki_connect_url') ??
          'http://127.0.0.1:8765';
      _ankiConnectEnabled =
          _storageService.getBool('anki_connect_enabled') ?? false;
      _ankiConnectModel =
          _storageService.getStringSync('anki_connect_model') ?? 'Basic';
      _ankiSyncOnSave = _storageService.getBool('anki_sync_on_save') ?? false;
      _profiles = _storageService.getStringList('profiles') ?? ['Default'];
      _clipboardAutoDetect =
          _storageService.getBool('clipboard_auto_detect') ?? false;
      _clipboardAutoSearchMode = ClipboardAutoSearchMode.values.firstWhere(
        (m) =>
            m.name ==
            (_storageService.getStringSync('clipboard_auto_search_mode') ??
                ClipboardAutoSearchMode.historyOnly.name),
        orElse: () => ClipboardAutoSearchMode.historyOnly,
      );
      _clipboardAutoSearchFocusedOnly =
          _storageService.getBool('clipboard_auto_search_focused_only') ??
          false;
      _clipboardAutoSearchRegex =
          _storageService.getStringSync('clipboard_auto_search_regex') ?? '';
      _forvoAudioEnabled =
          _storageService.getBool('forvo_audio_enabled') ?? false;
      _forvoApiKey = _storageService.getStringSync('forvo_api_key') ?? '';
      _autoConvertJapanese =
          _storageService.getBool('auto_convert_japanese') ?? true;
      _defaultScreenIndex = _storageService.getInt('default_screen_index') ?? 0;
      _autoPasteReader = _storageService.getBool('auto_paste_reader') ?? false;
      _showWiktionary = _storageService.getBool('show_wiktionary') ?? true;
      _showInlineDefinitions =
          _storageService.getBool('show_inline_definitions') ?? true;
      _showHoverDefinitions =
          _storageService.getBool('show_hover_definitions') ?? true;
      _useLocalTranslation =
          _storageService.getBool('use_local_translation') ?? false;
      final savedProvider = _storageService.getStringSync(
        'translation_provider',
      );
      _translationProvider = TranslationProvider.values.firstWhere(
        (e) => e.name == savedProvider,
        orElse: () => TranslationProvider.googleCloud,
      );
      // Load popup settings
      _hoverPopupSize = _storageService.getDouble('hover_popup_size') ?? 1.0;
      _hoverPopupDelay = _storageService.getInt('hover_popup_delay') ?? 300;
      _hoverPopupModifier =
          _storageService.getStringSync('hover_popup_modifier') ?? 'none';
      _hoverPopupLanguages =
          _storageService.getStringList('hover_popup_languages') ?? [];
      // Load profile activation
      _profileActivationScreen =
          _storageService.getStringSync('profile_activation_screen') ?? 'all';
      _profileActivationApp =
          _storageService.getStringSync('profile_activation_app') ?? 'default';
      // Ensure value is within valid range (0-6 for the 7 screens)
      if (_defaultScreenIndex < 0 || _defaultScreenIndex > 6) {
        _defaultScreenIndex = 0;
      }
    } catch (e) {
      // Handle the case where preferences are not initialized yet
      // Set default values
      _clipboardMonitor = false;
      _language = 'ja';
      _darkMode = false;
      _showParticles = true;
      _showKanji = true;
      _minFrequency = -1;
      _autoHideNavigation = true;
      _defaultFlexMode = false;
      _currentProfile = 'Default';
      _searchHistory = [];
      _etymologyLanguages = ['en', 'zh', 'ja'];
      _autoTranslate = false;
      _ankiDecks = ['Default'];
      _currentAnkiDeck = 'Default';
      _ankiConnectUrl = 'http://127.0.0.1:8765';
      _ankiConnectEnabled = false;
      _ankiConnectModel = 'Basic';
      _ankiSyncOnSave = false;
      _profiles = ['Default'];
      _clipboardAutoDetect = false;
      _forvoAudioEnabled = false;
      _forvoApiKey = '';
      _showWiktionary = true;
      _showInlineDefinitions = true;
      _showHoverDefinitions = true;
      _useLocalTranslation = false;
      _translationProvider = TranslationProvider.googleCloud;
      _defaultScreenIndex = 0;
      // Popup defaults
      _hoverPopupSize = 1.0;
      _hoverPopupDelay = 300;
      _hoverPopupModifier = 'none';
      _hoverPopupLanguages = [];
      // Profile activation defaults
      _profileActivationScreen = 'all';
      _profileActivationApp = 'default';
    }
  }

  void _loadSavedWords() async {
    try {
      _savedWords = _storageService.getStringList('saved_words') ?? [];
      final savedDetailsJson = _storageService.getStringSync(
        'saved_words_details',
      );
      if (savedDetailsJson != null) {
        try {
          _savedWordsDetails = Map<String, dynamic>.from(
            await _storageService.getJson('saved_words_details') ?? {},
          );
        } catch (e) {
          _savedWordsDetails = {};
        }
      }
    } catch (e) {
      _savedWords = [];
      _savedWordsDetails = {};
    }
  }

  void _loadFavoriteWords() {
    try {
      _favoriteWords = _storageService.getStringList('favorite_words') ?? [];
    } catch (e) {
      _favoriteWords = [];
    }
  }

  void _loadAnkiWords() {
    try {
      _ankiWords = _storageService.getStringList('anki_words') ?? [];
    } catch (e) {
      _ankiWords = [];
    }
  }

  void _loadDeletedWords() {
    try {
      _deletedWords = _storageService.getStringList('deleted_words') ?? [];
    } catch (e) {
      _deletedWords = [];
    }
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

  // Word list functionality (deleted words)
  List<String> _deletedWords = [];

  List<String> get deletedWords => _deletedWords;

  bool isWordDeleted(String word) => _deletedWords.contains(word);

  Future<void> deleteWord(String word) async {
    if (!_deletedWords.contains(word)) {
      _deletedWords.add(word);
      await _storageService.addToDeletedWords(word);
      notifyListeners();
    }
  }

  Future<void> undeleteWord(String word) async {
    if (_deletedWords.contains(word)) {
      _deletedWords.remove(word);
      await _storageService.removeFromDeletedWords(word);
      notifyListeners();
    }
  }

  // Favorite words methods
  bool isWordFavorite(String word) => _favoriteWords.contains(word);

  Future<void> toggleFavoriteWord(
    String word, {
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      if (!_favoriteWords.contains(word)) {
        _favoriteWords.add(word);
      }
    } else {
      _favoriteWords.remove(word);
    }
    await _storageService.setStringList('favorite_words', _favoriteWords);
    notifyListeners();
  }
}
