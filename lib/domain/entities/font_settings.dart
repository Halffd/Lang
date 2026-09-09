import 'dart:convert';

/// Per-item-group font size configuration for the analyze screen
/// (and any other text surfaces). Every value is a multiplier
/// applied on top of the base size for that group.
class FontSettings {
  /// Section headers ("Sentences", "Words", "Full translation"...)
  final double headers;

  /// Source sentence text in the sentence list
  final double sentences;

  /// Per-sentence translation text under each sentence
  final double translations;

  /// Word entries on cards (word + reading)
  final double words;

  /// Kanji characters in word cards and kanji popups
  final double kanji;

  /// Small UI text (badges, timestamps, hints)
  final double ui;

  const FontSettings({
    this.headers = 1.0,
    this.sentences = 1.0,
    this.translations = 1.0,
    this.words = 1.0,
    this.kanji = 1.0,
    this.ui = 1.0,
  });

  FontSettings copyWith({
    double? headers,
    double? sentences,
    double? translations,
    double? words,
    double? kanji,
    double? ui,
  }) => FontSettings(
    headers: headers ?? this.headers,
    sentences: sentences ?? this.sentences,
    translations: translations ?? this.translations,
    words: words ?? this.words,
    kanji: kanji ?? this.kanji,
    ui: ui ?? this.ui,
  );

  Map<String, dynamic> toJson() => {
    'headers': headers,
    'sentences': sentences,
    'translations': translations,
    'words': words,
    'kanji': kanji,
    'ui': ui,
  };

  static FontSettings fromJson(Map<String, dynamic> json) {
    double d(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return 1.0;
    }

    return FontSettings(
      headers: d('headers').clamp(0.5, 3.0),
      sentences: d('sentences').clamp(0.5, 3.0),
      translations: d('translations').clamp(0.5, 3.0),
      words: d('words').clamp(0.5, 3.0),
      kanji: d('kanji').clamp(0.5, 3.0),
      ui: d('ui').clamp(0.5, 3.0),
    );
  }

  String serialize() => jsonEncode(toJson());

  static FontSettings deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return const FontSettings();
    try {
      return FontSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const FontSettings();
    }
  }
}
