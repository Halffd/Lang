import 'dart:convert';

/// Anki note types (card models) with per-field marker templates,
/// mirroring Yomitan's Anki Cards configuration and the
/// jp-mining-note field layout.

enum AnkiNoteType { expression, reading, kanji, name }

class AnkiNoteTypeConfig {
  final AnkiNoteType type;
  String deck = 'Default';
  String model = 'Basic';
  bool enabled = true;

  /// Fields in order: name -> marker template.
  /// Marker templates may contain multiple markers and literal text,
  /// e.g. "{{furigana}}" or "{expression} ({reading})".
  final List<AnkiFieldConfig> fields;

  AnkiNoteTypeConfig(this.type, this.deck, this.model, this.fields,
      {this.enabled = true});

  String get typeName {
    switch (type) {
      case AnkiNoteType.expression:
        return 'expression';
      case AnkiNoteType.reading:
        return 'reading';
      case AnkiNoteType.kanji:
        return 'kanji';
      case AnkiNoteType.name:
        return 'name';
    }
  }

  AnkiFieldConfig field(String name) =>
      fields.firstWhere((f) => f.name == name, orElse: () => AnkiFieldConfig(name, ''));

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'deck': deck,
        'model': model,
        'enabled': enabled,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  static AnkiNoteTypeConfig fromJson(Map<String, dynamic> json) {
    final t = AnkiNoteType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => AnkiNoteType.expression,
    );
    final fieldsJson = json['fields'] as List? ?? [];
    final fields = fieldsJson
        .whereType<Map>()
        .map((m) => AnkiFieldConfig.fromJson(m.cast<String, dynamic>()))
        .toList();
    final c = AnkiNoteTypeConfig(
      t,
      json['deck'] as String? ?? 'Default',
      json['model'] as String? ?? 'Basic',
      fields,
      enabled: json['enabled'] as bool? ?? true,
    );
    return c;
  }

  /// Deep copy with per-field overrides applied.
  AnkiNoteTypeConfig copy() => AnkiNoteTypeConfig.fromJson(toJson());
}

class AnkiFieldConfig {
  String name;
  String value; // marker template

  AnkiFieldConfig(this.name, this.value);

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  static AnkiFieldConfig fromJson(Map<String, dynamic> json) =>
      AnkiFieldConfig(json['name'] as String? ?? '',
          json['value'] as String? ?? '');
}

/// Default note type configuration matching jp-mining-note style
/// field layouts from the user's template listing.
class DefaultNoteTypes {
  static List<AnkiFieldConfig> _expressionFields() => [
        AnkiFieldConfig('Word', '{expression}'),
        AnkiFieldConfig('WordReading', '{furigana-plain}'),
        AnkiFieldConfig('PAOverride', ''),
        AnkiFieldConfig('PAOverrideText', ''),
        AnkiFieldConfig('AJTWordPitch', '{pitch-accents}'),
        AnkiFieldConfig('PrimaryDefinition', '{glossary-first}'),
        AnkiFieldConfig('PrimaryDefinitionPicture', '{clipboard-image}'),
        AnkiFieldConfig('Sentence', '{sentence}'),
        AnkiFieldConfig('SentenceReading', '{sentence-furigana-plain}'),
        AnkiFieldConfig('AltDisplay', ''),
        AnkiFieldConfig('AltDisplayPASentenceCard', ''),
        AnkiFieldConfig('AdditionalNotes', '{clipboard-text}'),
        AnkiFieldConfig('IsSentenceCard', ''),
        AnkiFieldConfig('IsClickCard', ''),
        AnkiFieldConfig('IsHoverCard', ''),
        AnkiFieldConfig('IsTargetedSentenceCard', ''),
        AnkiFieldConfig('PAShowInfo', ''),
        AnkiFieldConfig('PATestOnlyWord', ''),
        AnkiFieldConfig('PADoNotTest', ''),
        AnkiFieldConfig('PASeparateWordCard', ''),
        AnkiFieldConfig('PASeparateSentenceCard', ''),
        AnkiFieldConfig('SeparateClozeDeletionCard', ''),
        AnkiFieldConfig('Hint', '{hint}'),
        AnkiFieldConfig('HintNotHidden', ''),
        AnkiFieldConfig('Picture', '{screenshot}'),
        AnkiFieldConfig('WordAudio', '{audio}'),
        AnkiFieldConfig('SentenceAudio', '{sentence-audio}'),
        AnkiFieldConfig('PAGraphs', '{pitch-accent-graphs}'),
        AnkiFieldConfig('PAPositions', '{pitch-accent-positions}'),
        AnkiFieldConfig('PASilence', ''),
        AnkiFieldConfig('WordReadingHiragana', '{reading}'),
        AnkiFieldConfig('FrequenciesStylized', '{frequencies}'),
        AnkiFieldConfig('FrequencySort', '{frequency-harmonic-rank}'),
        AnkiFieldConfig('SecondaryDefinition', '{glossary-no-dictionary}'),
        AnkiFieldConfig('ExtraDefinitions', '{glossary}'),
        AnkiFieldConfig('UtilityDictionaries', '{tags}'),
        AnkiFieldConfig('Comment', ''),
      ];

  static List<AnkiFieldConfig> _readingFields() => _expressionFields();

  static List<AnkiFieldConfig> _kanjiFields() => [
        AnkiFieldConfig('Word', '{character}'),
        AnkiFieldConfig('Reading', '{onyomi}, {kunyomi}'),
        AnkiFieldConfig('Glossary', '{glossary}'),
        AnkiFieldConfig('Sentence', '{sentence}'),
        AnkiFieldConfig('Sentence-English', '{sentence}'),
        AnkiFieldConfig('Picture', '{screenshot}'),
        AnkiFieldConfig('Audio', '{audio}'),
        AnkiFieldConfig('Sentence-Audio', '{sentence-audio}'),
        AnkiFieldConfig('Hint', '{hint}'),
      ];

  static List<AnkiFieldConfig> _nameFields() => [
        AnkiFieldConfig('Word', '{expression}'),
        AnkiFieldConfig('Reading', '{reading}'),
        AnkiFieldConfig('Glossary', '{glossary}'),
        AnkiFieldConfig('Sentence', '{sentence}'),
        AnkiFieldConfig('Sentence-English', '{sentence}'),
        AnkiFieldConfig('Picture', '{screenshot}'),
        AnkiFieldConfig('Audio', '{audio}'),
        AnkiFieldConfig('Sentence-Audio', '{sentence-audio}'),
        AnkiFieldConfig('Hint', '{hint}'),
      ];

  static AnkiNoteTypeConfig expression() => AnkiNoteTypeConfig(
      AnkiNoteType.expression, 'Mining', 'jp-mining-note',
      _expressionFields());

  static AnkiNoteTypeConfig reading() => AnkiNoteTypeConfig(
      AnkiNoteType.reading, 'Mining', 'jp-mining-note', _readingFields());

  static AnkiNoteTypeConfig kanji() => AnkiNoteTypeConfig(
      AnkiNoteType.kanji, 'Kanji', 'Basic', _kanjiFields());

  static AnkiNoteTypeConfig name() => AnkiNoteTypeConfig(
      AnkiNoteType.name, 'Names', 'Basic', _nameFields());

  static List<AnkiNoteTypeConfig> all() =>
      [expression(), reading(), kanji(), name()];
}

/// Container for all note types, persisted as JSON.
class AnkiNoteTypes {
  final List<AnkiNoteTypeConfig> types;

  AnkiNoteTypes(this.types);

  static AnkiNoteTypes defaults() => AnkiNoteTypes(DefaultNoteTypes.all());

  AnkiNoteTypeConfig byType(AnkiNoteType t) =>
      types.firstWhere((c) => c.type == t,
          orElse: () => DefaultNoteTypes.all()
              .firstWhere((c) => c.type == t));

  Map<String, dynamic> toJson() =>
      {'types': types.map((t) => t.toJson()).toList()};

  static AnkiNoteTypes fromJson(Map<String, dynamic> json) {
    final ts = json['types'] as List? ?? [];
    return AnkiNoteTypes(ts
        .whereType<Map>()
        .map((m) => AnkiNoteTypeConfig.fromJson(m.cast<String, dynamic>()))
        .toList());
  }

  String serialize() => jsonEncode(toJson());

  static AnkiNoteTypes deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return defaults();
    try {
      return AnkiNoteTypes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return defaults();
    }
  }
}