import 'dart:convert';

/// Yomitan-style settings covering all export-related options.
///
/// Sections mirror the Yomitan settings screen: profiles, general,
/// storage, scanning, popup behavior, appearance, audio, text parsing,
/// translation, anki, clipboard, backup, accessibility, security.

// ============================================================
// Enums
// ============================================================

enum FrequencySortingMode { min, first, avg, harmonic }

enum ResultGroupingMode { noGrouping, groupTermReadingPairs, groupTermTags }

enum DuplicateScope { deck, global }

enum DuplicateAction { prevent, overwrite, createDuplicate }

enum ScanModifierKey { none, alt, ctrl, meta, shift }

enum ClipboardSearchMode { replace, append }

enum ScreenshotFormat { jpg, png, webp }

enum PopupDisplayMode { overlay, fullWidth }

enum ThemePreset { defaultTheme, dark, light, black }

enum TermDisplayStyle { frequencyTag, visualTags, glossaryOnly }

enum ReadingDisplayMode { okurigana, furigana, kana, disabled }

enum SelectionIndicatorStyle { none, underline, box, highlight }

enum PopupLocation { left, right, above, below }

// ============================================================
// General
// ============================================================

class GeneralSettings {
  bool enabled = true;
  String language = 'ja';
  bool showWelcomeGuide = false;
  bool showLookupInContextMenu = true;
  int maximumNumberOfResults = 32;
  bool enableApi = false;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'language': language,
        'showWelcomeGuide': showWelcomeGuide,
        'showLookupInContextMenu': showLookupInContextMenu,
        'maximumNumberOfResults': maximumNumberOfResults,
        'enableApi': enableApi,
      };

  void fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'] ?? enabled;
    language = json['language'] ?? language;
    showWelcomeGuide = json['showWelcomeGuide'] ?? showWelcomeGuide;
    showLookupInContextMenu =
        json['showLookupInContextMenu'] ?? showLookupInContextMenu;
    maximumNumberOfResults =
        json['maximumNumberOfResults'] ?? maximumNumberOfResults;
    enableApi = json['enableApi'] ?? enableApi;
  }
}

// ============================================================
// Storage / frequency
// ============================================================

class StorageSettings {
  String frequencySortingDictionary = '';
  FrequencySortingMode frequencySortingMode = FrequencySortingMode.harmonic;
  bool persistentStorage = true;

  Map<String, dynamic> toJson() => {
        'frequencySortingDictionary': frequencySortingDictionary,
        'frequencySortingMode': frequencySortingMode.name,
        'persistentStorage': persistentStorage,
      };

  void fromJson(Map<String, dynamic> json) {
    frequencySortingDictionary =
        json['frequencySortingDictionary'] ?? frequencySortingDictionary;
    frequencySortingMode = FrequencySortingMode.values.firstWhere(
      (m) => m.name == json['frequencySortingMode'],
      orElse: () => FrequencySortingMode.harmonic,
    );
    persistentStorage = json['persistentStorage'] ?? persistentStorage;
  }
}

// ============================================================
// Scanning
// ============================================================

class ScanningSettings {
  ScanModifierKey scanModifierKey = ScanModifierKey.shift;
  bool scanUsingMiddleMouseButton = true;
  int scanDelay =0;
  bool scanWithoutMouseMove = false;
  bool selectMatchedText = true;
  bool searchNonJapaneseText = true;
  bool layoutAwareScanning = true;
  bool deepContentScanning = false;
  bool normalizeCssZoom = true;
  bool wildcardScanning = true;
  int textScanLength = 400;
  int sentenceScanningExtent = 200;
  List<String> sentenceTerminationCharacters = [
    '。', '！', '？', '.', '!', '?', '‼', '⁉', '｡', '！',
  ];

  Map<String, dynamic> toJson() => {
        'scanModifierKey': scanModifierKey.name,
        'scanUsingMiddleMouseButton': scanUsingMiddleMouseButton,
        'scanDelay': scanDelay,
        'scanWithoutMouseMove': scanWithoutMouseMove,
        'selectMatchedText': selectMatchedText,
        'searchNonJapaneseText': searchNonJapaneseText,
        'layoutAwareScanning': layoutAwareScanning,
        'deepContentScanning': deepContentScanning,
        'normalizeCssZoom': normalizeCssZoom,
        'wildcardScanning': wildcardScanning,
        'textScanLength': textScanLength,
        'sentenceScanningExtent': sentenceScanningExtent,
        'sentenceTerminationCharacters': sentenceTerminationCharacters,
      };

  void fromJson(Map<String, dynamic> json) {
    scanModifierKey = ScanModifierKey.values.firstWhere(
      (k) => k.name == json['scanModifierKey'],
      orElse: () => ScanModifierKey.shift,
    );
    scanUsingMiddleMouseButton =
        json['scanUsingMiddleMouseButton'] ?? scanUsingMiddleMouseButton;
    scanDelay = json['scanDelay'] ?? scanDelay;
    scanWithoutMouseMove = json['scanWithoutMouseMove'] ?? scanWithoutMouseMove;
    selectMatchedText = json['selectMatchedText'] ?? selectMatchedText;
    searchNonJapaneseText = json['searchNonJapaneseText'] ?? searchNonJapaneseText;
    layoutAwareScanning = json['layoutAwareScanning'] ?? layoutAwareScanning;
    deepContentScanning = json['deepContentScanning'] ?? deepContentScanning;
    normalizeCssZoom = json['normalizeCssZoom'] ?? normalizeCssZoom;
    wildcardScanning = json['wildcardScanning'] ?? wildcardScanning;
    textScanLength = json['textScanLength'] ?? textScanLength;
    sentenceScanningExtent =
        json['sentenceScanningExtent'] ?? sentenceScanningExtent;
    final stc = json['sentenceTerminationCharacters'];
    if (stc is List && stc.isNotEmpty) {
      sentenceTerminationCharacters = stc.cast<String>();
    }
  }
}

// ============================================================
// Popup behavior
// ============================================================

class PopupBehaviorSettings {
  bool allowScanningSearchPage = true;
  bool allowScanningPopupContent = true;
  int maximumNumberOfChildPopups = 4;
  bool allowScanningPopupSourceTerms = false;
  bool autoHideSearchPopup = true;
  bool hidePopupOnCursorExit = false;
  bool reducedMotionScrolling = false;
  bool searchOnClickFromResultsList = true;
  bool showIframePopupsInRootFrame = false;

  Map<String, dynamic> toJson() => {
        'allowScanningSearchPage': allowScanningSearchPage,
        'allowScanningPopupContent': allowScanningPopupContent,
        'maximumNumberOfChildPopups': maximumNumberOfChildPopups,
        'allowScanningPopupSourceTerms': allowScanningPopupSourceTerms,
        'autoHideSearchPopup': autoHideSearchPopup,
        'hidePopupOnCursorExit': hidePopupOnCursorExit,
        'reducedMotionScrolling': reducedMotionScrolling,
        'searchOnClickFromResultsList': searchOnClickFromResultsList,
        'showIframePopupsInRootFrame': showIframePopupsInRootFrame,
      };

  void fromJson(Map<String, dynamic> json) {
    allowScanningSearchPage =
        json['allowScanningSearchPage'] ?? allowScanningSearchPage;
    allowScanningPopupContent =
        json['allowScanningPopupContent'] ?? allowScanningPopupContent;
    maximumNumberOfChildPopups =
        json['maximumNumberOfChildPopups'] ?? maximumNumberOfChildPopups;
    allowScanningPopupSourceTerms =
        json['allowScanningPopupSourceTerms'] ?? allowScanningPopupSourceTerms;
    autoHideSearchPopup = json['autoHideSearchPopup'] ?? autoHideSearchPopup;
    hidePopupOnCursorExit =
        json['hidePopupOnCursorExit'] ?? hidePopupOnCursorExit;
    reducedMotionScrolling =
        json['reducedMotionScrolling'] ?? reducedMotionScrolling;
    searchOnClickFromResultsList =
        json['searchOnClickFromResultsList'] ?? searchOnClickFromResultsList;
    showIframePopupsInRootFrame =
        json['showIframePopupsInRootFrame'] ?? showIframePopupsInRootFrame;
  }
}

// ============================================================
// Appearance
// ============================================================

class AppearanceSettings {
  ThemePreset theme = ThemePreset.defaultTheme;
  double fontSize = 14;
  double lineHeight = 1.5;
  String fontFamily = '';
  bool compactGlossaries = false;
  bool compactTags = false;
  bool showTagsForExpressionsAndReadings = true;
  TermDisplayStyle termDisplayStyle = TermDisplayStyle.frequencyTag;
  ReadingDisplayMode readingDisplayMode = ReadingDisplayMode.okurigana;
  String frequencyDisplayStyle = 'tags';
  SelectionIndicatorStyle selectionIndicatorStyle =
      SelectionIndicatorStyle.underline;
  bool pitchAccentDownstep = true;
  bool pitchAccentGraph = true;
  bool pitchAccentPosition = true;

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'fontFamily': fontFamily,
        'compactGlossaries': compactGlossaries,
        'compactTags': compactTags,
        'showTagsForExpressionsAndReadings':
            showTagsForExpressionsAndReadings,
        'termDisplayStyle': termDisplayStyle.name,
        'readingDisplayMode': readingDisplayMode.name,
        'frequencyDisplayStyle': frequencyDisplayStyle,
        'selectionIndicatorStyle': selectionIndicatorStyle.name,
        'pitchAccentDownstep': pitchAccentDownstep,
        'pitchAccentGraph': pitchAccentGraph,
        'pitchAccentPosition': pitchAccentPosition,
      };

  void fromJson(Map<String, dynamic> json) {
    theme = ThemePreset.values.firstWhere(
      (t) => t.name == json['theme'],
      orElse: () => ThemePreset.defaultTheme,
    );
    fontSize = (json['fontSize'] as num?)?.toDouble() ?? fontSize;
    lineHeight = (json['lineHeight'] as num?)?.toDouble() ?? lineHeight;
    fontFamily = json['fontFamily'] ?? fontFamily;
    compactGlossaries = json['compactGlossaries'] ?? compactGlossaries;
    compactTags = json['compactTags'] ?? compactTags;
    showTagsForExpressionsAndReadings =
        json['showTagsForExpressionsAndReadings'] ??
            showTagsForExpressionsAndReadings;
    termDisplayStyle = TermDisplayStyle.values.firstWhere(
      (t) => t.name == json['termDisplayStyle'],
      orElse: () => TermDisplayStyle.frequencyTag,
    );
    readingDisplayMode = ReadingDisplayMode.values.firstWhere(
      (r) => r.name == json['readingDisplayMode'],
      orElse: () => ReadingDisplayMode.okurigana,
    );
    frequencyDisplayStyle = json['frequencyDisplayStyle'] ?? frequencyDisplayStyle;
    selectionIndicatorStyle = SelectionIndicatorStyle.values.firstWhere(
      (s) => s.name == json['selectionIndicatorStyle'],
      orElse: () => SelectionIndicatorStyle.underline,
    );
    pitchAccentDownstep = json['pitchAccentDownstep'] ?? pitchAccentDownstep;
    pitchAccentGraph = json['pitchAccentGraph'] ?? pitchAccentGraph;
    pitchAccentPosition = json['pitchAccentPosition'] ?? pitchAccentPosition;
  }
}

// ============================================================
// Popup position & size
// ============================================================

class PopupPositionSettings {
  PopupDisplayMode displayMode = PopupDisplayMode.overlay;
  double scale = 1.0;
  bool autoScale = false;
  double zoomLevel = 1.0;
  double width = 400;
  double height = 250;
  PopupLocation horizontalPosition = PopupLocation.below;
  PopupLocation verticalPosition = PopupLocation.below;
  double horizontalOffset = 0;
  double verticalOffset = 0;

  Map<String, dynamic> toJson() => {
        'displayMode': displayMode.name,
        'scale': scale,
        'autoScale': autoScale,
        'zoomLevel': zoomLevel,
        'width': width,
        'height': height,
        'horizontalPosition': horizontalPosition.name,
        'verticalPosition': verticalPosition.name,
        'horizontalOffset': horizontalOffset,
        'verticalOffset': verticalOffset,
      };

  void fromJson(Map<String, dynamic> json) {
    displayMode = PopupDisplayMode.values.firstWhere(
      (d) => d.name == json['displayMode'],
      orElse: () => PopupDisplayMode.overlay,
    );
    scale = (json['scale'] as num?)?.toDouble() ?? scale;
    autoScale = json['autoScale'] ?? autoScale;
    zoomLevel = (json['zoomLevel'] as num?)?.toDouble() ?? zoomLevel;
    width = (json['width'] as num?)?.toDouble() ?? width;
    height = (json['height'] as num?)?.toDouble() ?? height;
    horizontalPosition = PopupLocation.values.firstWhere(
      (p) => p.name == json['horizontalPosition'],
      orElse: () => PopupLocation.below,
    );
    verticalPosition = PopupLocation.values.firstWhere(
      (p) => p.name == json['verticalPosition'],
      orElse: () => PopupLocation.below,
    );
    horizontalOffset =
        (json['horizontalOffset'] as num?)?.toDouble() ?? horizontalOffset;
    verticalOffset =
        (json['verticalOffset'] as num?)?.toDouble() ?? verticalOffset;
  }
}

// ============================================================
// Search window
// ============================================================

class SearchWindowSettings {
  bool stickySearchHeader = true;
  bool useNativeWindow = false;
  double width = 400;
  double height = 250;
  double left = 0;
  String leftMode = 'left';
  double top = 0;
  String topMode = 'top';

  Map<String, dynamic> toJson() => {
        'stickySearchHeader': stickySearchHeader,
        'useNativeWindow': useNativeWindow,
        'width': width,
        'height': height,
        'left': left,
        'leftMode': leftMode,
        'top': top,
        'topMode': topMode,
      };

  void fromJson(Map<String, dynamic> json) {
    stickySearchHeader = json['stickySearchHeader'] ?? stickySearchHeader;
    useNativeWindow = json['useNativeWindow'] ?? useNativeWindow;
    width = (json['width'] as num?)?.toDouble() ?? width;
    height = (json['height'] as num?)?.toDouble() ?? height;
    left = (json['left'] as num?)?.toDouble() ?? left;
    leftMode = json['leftMode'] ?? leftMode;
    top = (json['top'] as num?)?.toDouble() ?? top;
    topMode = json['topMode'] ?? topMode;
  }
}

// ============================================================
// Audio
// ============================================================

class AudioSettings {
  bool enabled = true;
  bool autoPlaySearchResultAudio = false;
  String fallbackSound = 'none';
  double volume = 1.0;
  List<String> sources = ['jpod101', 'jisho', 'text-to-speech', 'custom'];

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'autoPlaySearchResultAudio': autoPlaySearchResultAudio,
        'fallbackSound': fallbackSound,
        'volume': volume,
        'sources': sources,
      };

  void fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'] ?? enabled;
    autoPlaySearchResultAudio =
        json['autoPlaySearchResultAudio'] ?? autoPlaySearchResultAudio;
    fallbackSound = json['fallbackSound'] ?? fallbackSound;
    volume = (json['volume'] as num?)?.toDouble() ?? volume;
    final s = json['sources'];
    if (s is List && s.isNotEmpty) sources = s.cast<String>();
  }
}

// ============================================================
// Text parsing
// ============================================================

class TextParsingSettings {
  bool parseInternalParser = true;
  bool parseMecab = false;
  bool showSpaceBetweenParsedWords = false;
  int sentenceScanningExtent = 200;
  List<String> sentenceTerminationCharacters = [
    '。', '！', '？', '.', '!', '?',
  ];

  Map<String, dynamic> toJson() => {
        'parseInternalParser': parseInternalParser,
        'parseMecab': parseMecab,
        'showSpaceBetweenParsedWords': showSpaceBetweenParsedWords,
        'sentenceScanningExtent': sentenceScanningExtent,
        'sentenceTerminationCharacters': sentenceTerminationCharacters,
      };

  void fromJson(Map<String, dynamic> json) {
    parseInternalParser = json['parseInternalParser'] ?? parseInternalParser;
    parseMecab = json['parseMecab'] ?? parseMecab;
    showSpaceBetweenParsedWords =
        json['showSpaceBetweenParsedWords'] ?? showSpaceBetweenParsedWords;
    sentenceScanningExtent =
        json['sentenceScanningExtent'] ?? sentenceScanningExtent;
    final stc = json['sentenceTerminationCharacters'];
    if (stc is List && stc.isNotEmpty) {
      sentenceTerminationCharacters = stc.cast<String>();
    }
  }
}

// ============================================================
// Translation / dictionary search resolution
// ============================================================

class TranslationSettings {
  /// Dictionary search resolution:
  /// true  = "A dog" -> search "A dog", "A do", "A d", "A"
  /// false = "A dog" -> "A dog", "A"
  bool searchResolutionFull = true;
  List<Map<String, String>> customTextReplacements = [];

  Map<String, dynamic> toJson() => {
        'searchResolutionFull': searchResolutionFull,
        'customTextReplacements': customTextReplacements,
      };

  void fromJson(Map<String, dynamic> json) {
    searchResolutionFull = json['searchResolutionFull'] ?? searchResolutionFull;
    final ctr = json['customTextReplacements'];
    if (ctr is List) {
      customTextReplacements = ctr
          .whereType<Map>()
          .map((m) => m.cast<String, String>())
          .toList();
    }
  }
}

// ============================================================
// Clipboard
// ============================================================

class ClipboardSettings {
  bool enableBackgroundMonitoring = false;
  bool enableSearchPageMonitoring = false;
  int maximumSearchTextLength = 1000;
  ClipboardSearchMode searchMode = ClipboardSearchMode.replace;

  Map<String, dynamic> toJson() => {
        'enableBackgroundMonitoring': enableBackgroundMonitoring,
        'enableSearchPageMonitoring': enableSearchPageMonitoring,
        'maximumSearchTextLength': maximumSearchTextLength,
        'searchMode': searchMode.name,
      };

  void fromJson(Map<String, dynamic> json) {
    enableBackgroundMonitoring =
        json['enableBackgroundMonitoring'] ?? enableBackgroundMonitoring;
    enableSearchPageMonitoring =
        json['enableSearchPageMonitoring'] ?? enableSearchPageMonitoring;
    maximumSearchTextLength =
        json['maximumSearchTextLength'] ?? maximumSearchTextLength;
    searchMode = ClipboardSearchMode.values.firstWhere(
      (m) => m.name == json['searchMode'],
      orElse: () => ClipboardSearchMode.replace,
    );
  }
}

// ============================================================
// Accessibility & security
// ============================================================

class AccessibilitySettings {
  bool googleDocsCompatibilityMode = false;

  Map<String, dynamic> toJson() => {'googleDocsCompatibilityMode': googleDocsCompatibilityMode};

  void fromJson(Map<String, dynamic> json) {
    googleDocsCompatibilityMode =
        json['googleDocsCompatibilityMode'] ?? googleDocsCompatibilityMode;
  }
}

class SecuritySettings {
  bool useSecureContainerAroundPopups = true;
  bool useSecurePopupFrameUrl = false;

  Map<String, dynamic> toJson() => {
        'useSecureContainerAroundPopups': useSecureContainerAroundPopups,
        'useSecurePopupFrameUrl': useSecurePopupFrameUrl,
      };

  void fromJson(Map<String, dynamic> json) {
    useSecureContainerAroundPopups =
        json['useSecureContainerAroundPopups'] ?? useSecureContainerAroundPopups;
    useSecurePopupFrameUrl =
        json['useSecurePopupFrameUrl'] ?? useSecurePopupFrameUrl;
  }
}

// ============================================================
// Result display
// ============================================================

class ResultDisplaySettings {
  ResultGroupingMode resultGroupingMode =
      ResultGroupingMode.groupTermReadingPairs;
  bool averageFrequencies = false;

  Map<String, dynamic> toJson() => {
        'resultGroupingMode': resultGroupingMode.name,
        'averageFrequencies': averageFrequencies,
      };

  void fromJson(Map<String, dynamic> json) {
    resultGroupingMode = ResultGroupingMode.values.firstWhere(
      (m) => m.name == json['resultGroupingMode'],
      orElse: () => ResultGroupingMode.groupTermReadingPairs,
    );
    averageFrequencies = json['averageFrequencies'] ?? averageFrequencies;
  }
}

// ============================================================
// Anki
// ============================================================

class AnkiSettings {
  bool enabled = false;
  String serverAddress = 'http://127.0.0.1:8765';
  String tags = '';
  String apiKey = '';
  bool checkForCardDuplicates = true;
  DuplicateScope duplicateScope = DuplicateScope.deck;
  DuplicateAction duplicateAction = DuplicateAction.prevent;
  bool prioritizeDuplicateChecks = true;
  ScreenshotFormat screenshotFormat = ScreenshotFormat.jpg;
  int idleDownloadTimeoutMs = 60000;
  bool suspendNewCards = false;
  bool showCardTagsAndFlags = false;
  bool forceSyncOnAddingCard = false;
  String noteViewerWindow = 'default';

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'serverAddress': serverAddress,
        'tags': tags,
        'apiKey': apiKey,
        'checkForCardDuplicates': checkForCardDuplicates,
        'duplicateScope': duplicateScope.name,
        'duplicateAction': duplicateAction.name,
        'prioritizeDuplicateChecks': prioritizeDuplicateChecks,
        'screenshotFormat': screenshotFormat.name,
        'idleDownloadTimeoutMs': idleDownloadTimeoutMs,
        'suspendNewCards': suspendNewCards,
        'showCardTagsAndFlags': showCardTagsAndFlags,
        'forceSyncOnAddingCard': forceSyncOnAddingCard,
        'noteViewerWindow': noteViewerWindow,
      };

  void fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'] ?? enabled;
    serverAddress = json['serverAddress'] ?? serverAddress;
    tags = json['tags'] ?? tags;
    apiKey = json['apiKey'] ?? apiKey;
    checkForCardDuplicates = json['checkForCardDuplicates'] ?? checkForCardDuplicates;
    duplicateScope = DuplicateScope.values.firstWhere(
      (s) => s.name == json['duplicateScope'],
      orElse: () => DuplicateScope.deck,
    );
    duplicateAction = DuplicateAction.values.firstWhere(
      (a) => a.name == json['duplicateAction'],
      orElse: () => DuplicateAction.prevent,
    );
    prioritizeDuplicateChecks =
        json['prioritizeDuplicateChecks'] ?? prioritizeDuplicateChecks;
    screenshotFormat = ScreenshotFormat.values.firstWhere(
      (f) => f.name == json['screenshotFormat'],
      orElse: () => ScreenshotFormat.jpg,
    );
    idleDownloadTimeoutMs = json['idleDownloadTimeoutMs'] ?? idleDownloadTimeoutMs;
    suspendNewCards = json['suspendNewCards'] ?? suspendNewCards;
    showCardTagsAndFlags = json['showCardTagsAndFlags'] ?? showCardTagsAndFlags;
    forceSyncOnAddingCard = json['forceSyncOnAddingCard'] ?? forceSyncOnAddingCard;
    noteViewerWindow = json['noteViewerWindow'] ?? noteViewerWindow;
  }
}

// ============================================================
// Profile
// ============================================================

class YomitanProfile {
  final String name;
  final GeneralSettings general = GeneralSettings();
  final StorageSettings storage = StorageSettings();
  final ScanningSettings scanning = ScanningSettings();
  final PopupBehaviorSettings popupBehavior = PopupBehaviorSettings();
  final AppearanceSettings appearance = AppearanceSettings();
  final PopupPositionSettings popupPosition = PopupPositionSettings();
  final SearchWindowSettings searchWindow = SearchWindowSettings();
  final AudioSettings audio = AudioSettings();
  final TextParsingSettings textParsing = TextParsingSettings();
  final TranslationSettings translation = TranslationSettings();
  final ClipboardSettings clipboard = ClipboardSettings();
  final AccessibilitySettings accessibility = AccessibilitySettings();
  final SecuritySettings security = SecuritySettings();
  final ResultDisplaySettings resultDisplay = ResultDisplaySettings();
  final AnkiSettings anki = AnkiSettings();

  YomitanProfile(this.name);

  Map<String, dynamic> toJson() => {
        'name': name,
        'general': general.toJson(),
        'storage': storage.toJson(),
        'scanning': scanning.toJson(),
        'popupBehavior': popupBehavior.toJson(),
        'appearance': appearance.toJson(),
        'popupPosition': popupPosition.toJson(),
        'searchWindow': searchWindow.toJson(),
        'audio': audio.toJson(),
        'textParsing': textParsing.toJson(),
        'translation': translation.toJson(),
        'clipboard': clipboard.toJson(),
        'accessibility': accessibility.toJson(),
        'security': security.toJson(),
        'resultDisplay': resultDisplay.toJson(),
        'anki': anki.toJson(),
      };

  static YomitanProfile fromJson(Map<String, dynamic> json) {
    final p = YomitanProfile(json['name'] as String? ?? 'Default');
    p.general.fromJson(json['general'] as Map<String, dynamic>? ?? {});
    p.storage.fromJson(json['storage'] as Map<String, dynamic>? ?? {});
    p.scanning.fromJson(json['scanning'] as Map<String, dynamic>? ?? {});
    p.popupBehavior
        .fromJson(json['popupBehavior'] as Map<String, dynamic>? ?? {});
    p.appearance.fromJson(json['appearance'] as Map<String, dynamic>? ?? {});
    p.popupPosition
        .fromJson(json['popupPosition'] as Map<String, dynamic>? ?? {});
    p.searchWindow
        .fromJson(json['searchWindow'] as Map<String, dynamic>? ?? {});
    p.audio.fromJson(json['audio'] as Map<String, dynamic>? ?? {});
    p.textParsing.fromJson(json['textParsing'] as Map<String, dynamic>? ?? {});
    p.translation
        .fromJson(json['translation'] as Map<String, dynamic>? ?? {});
    p.clipboard.fromJson(json['clipboard'] as Map<String, dynamic>? ?? {});
    p.accessibility
        .fromJson(json['accessibility'] as Map<String, dynamic>? ?? {});
    p.security.fromJson(json['security'] as Map<String, dynamic>? ?? {});
    p.resultDisplay
        .fromJson(json['resultDisplay'] as Map<String, dynamic>? ?? {});
    p.anki.fromJson(json['anki'] as Map<String, dynamic>? ?? {});
    return p;
  }
}

// ============================================================
// Root options
// ============================================================

class YomitanOptions {
  List<YomitanProfile> profiles = [YomitanProfile('Default')];
  int activeProfileIndex = 0;

  YomitanProfile get activeProfile => profiles[activeProfileIndex.clamp(0, profiles.length - 1)];

  // Global (not per-profile): dictionary enable map, export settings
  final Map<String, bool> dictionaryEnabled = {};
  int maxExportImageWidth = 640;
  int maxExportImageHeight = 640;

  Map<String, dynamic> toJson() => {
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'activeProfileIndex': activeProfileIndex,
        'dictionaryEnabled': dictionaryEnabled,
        'maxExportImageWidth': maxExportImageWidth,
        'maxExportImageHeight': maxExportImageHeight,
      };

  static YomitanOptions fromJson(Map<String, dynamic> json) {
    final o = YomitanOptions();
    final ps = json['profiles'];
    if (ps is List && ps.isNotEmpty) {
      o.profiles = ps
          .whereType<Map>()
          .map((m) => YomitanProfile.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    o.activeProfileIndex = json['activeProfileIndex'] as int? ?? 0;
    final de = json['dictionaryEnabled'];
    if (de is Map) o.dictionaryEnabled.addAll(de.cast<String, bool>());
    o.maxExportImageWidth = json['maxExportImageWidth'] as int? ?? 640;
    o.maxExportImageHeight = json['maxExportImageHeight'] as int? ?? 640;
    return o;
  }

  String serialize() => jsonEncode(toJson());

  static YomitanOptions deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return YomitanOptions();
    try {
      return YomitanOptions.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return YomitanOptions();
    }
  }

  YomitanProfile addProfile(String name) {
    final p = YomitanProfile(name);
    profiles.add(p);
    return p;
  }

  void removeProfile(String name) {
    if (profiles.length <= 1) return;
    final idx = profiles.indexWhere((p) => p.name == name);
    if (idx < 0) return;
    profiles.removeAt(idx);
    if (activeProfileIndex >= profiles.length) {
      activeProfileIndex = profiles.length - 1;
    }
  }

  void setActiveProfile(String name) {
    final idx = profiles.indexWhere((p) => p.name == name);
    if (idx >= 0) activeProfileIndex = idx;
  }
}