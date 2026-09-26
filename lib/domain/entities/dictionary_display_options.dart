import 'dart:convert';

/// Per-user preferences controlling which parts of dictionary
/// entries render on screen - mirroring Yomitan's result display
/// toggles plus per-part switches.
class DictionaryDisplayOptions {
  /// Example sentences (structured-content example-sentence blocks)
  bool showSentences = true;

  /// Images from dictionaries (structured-content image nodes)
  bool showImages = true;

  /// Part-of-speech / category tags
  bool showTags = true;

  /// Dictionary notes and extra-info blocks
  bool showNotes = true;

  /// Frequency information
  bool showFrequencies = true;

  /// Pronunciation/pitch-accent info
  bool showPitchAccent = true;

  /// Compact glossary layout (semicolon-joined, no list bullets)
  bool compactGlossaries = false;

  /// Render structured content as plain text instead of styled
  bool showStructuredContent = true;

  /// Collapse long definitions behind an expand control
  bool collapseLongDefinitions = false;

  /// Hide the per-definition dictionary name badge
  bool showDictionaryName = true;

  /// Honor color styles embedded in dictionary structured content.
  /// Off = always use the theme color (popups use theme colors so
  /// dictionary accent colors don't paint every letter).
  bool respectContentColors = true;

  Map<String, dynamic> toJson() => {
    'showSentences': showSentences,
    'showImages': showImages,
    'showTags': showTags,
    'showNotes': showNotes,
    'showFrequencies': showFrequencies,
    'showPitchAccent': showPitchAccent,
    'compactGlossaries': compactGlossaries,
    'showStructuredContent': showStructuredContent,
    'collapseLongDefinitions': collapseLongDefinitions,
    'showDictionaryName': showDictionaryName,
    'respectContentColors': respectContentColors,
  };

  void fromJson(Map<String, dynamic> json) {
    showSentences = json['showSentences'] ?? showSentences;
    showImages = json['showImages'] ?? showImages;
    showTags = json['showTags'] ?? showTags;
    showNotes = json['showNotes'] ?? showNotes;
    showFrequencies = json['showFrequencies'] ?? showFrequencies;
    showPitchAccent = json['showPitchAccent'] ?? showPitchAccent;
    compactGlossaries = json['compactGlossaries'] ?? compactGlossaries;
    showStructuredContent =
        json['showStructuredContent'] ?? showStructuredContent;
    collapseLongDefinitions =
        json['collapseLongDefinitions'] ?? collapseLongDefinitions;
    showDictionaryName = json['showDictionaryName'] ?? showDictionaryName;
    respectContentColors = json['respectContentColors'] ?? respectContentColors;
  }

  String serialize() => jsonEncode(toJson());

  /// Deep copy (via serialize roundtrip) — callers may tweak single fields
  /// (e.g. popup disables content colors) without mutating shared prefs.
  DictionaryDisplayOptions copy() {
    final o = DictionaryDisplayOptions();
    o.fromJson(toJson());
    return o;
  }

  static DictionaryDisplayOptions deserialize(String? raw) {
    final o = DictionaryDisplayOptions();
    if (raw == null || raw.isEmpty) return o;
    try {
      o.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    return o;
  }
}
