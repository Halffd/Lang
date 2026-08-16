import 'dart:convert';

class DictionaryEntry {
  final int? id;
  final int dictionaryId;
  final String term;
  final String reading;
  final List<String>? definitionTags;
  final List<String>? rules;
  final double popularity;
  final List<String> definitions;
  final int? sequence;
  final List<String>? termTags;

  // Media support
  final String? audioUrl;
  final String? imageUrl;
  final String? imageCaption;

  // Add fields to maintain compatibility with UI
  List<String> get tags => termTags ?? (definitionTags ?? []);
  int get frequency => popularity.toInt();
  List<String> get examples => []; // No examples in Yomichan format, return empty list

  // Add convenience getter to maintain compatibility
  String get word => term;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  DictionaryEntry({
    this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    this.definitionTags,
    this.rules,
    this.popularity = 0,
    required this.definitions,
    this.sequence,
    this.termTags,
    this.audioUrl,
    this.imageUrl,
    this.imageCaption,
  });

  // Constructor for creating from JSON or other sources where dictionaryId might not be available
  DictionaryEntry.fromData({
    this.id,
    this.dictionaryId = 0,  // Default to 0 if not specified
    required this.term,
    required this.reading,
    this.definitionTags,
    this.rules,
    this.popularity = 0,
    required this.definitions,
    this.sequence,
    this.termTags,
    this.audioUrl,
    this.imageUrl,
    this.imageCaption,
  }) : assert(term.isNotEmpty, 'Term cannot be empty');

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      id: json['id'],
      dictionaryId: json['dictionaryId'] ?? json['dictionary_id'] ?? 0,
      term: json['term'] as String,
      reading: json['reading'] as String,
      definitionTags: _extractStringList(json['definitionTags']) ??
          _extractStringList(json['definition_tags']),
      rules: _extractStringList(json['rules']),
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      definitions: _extractStringList(json['definitions']) ?? [],
      sequence: json['sequence'],
      termTags: _extractStringList(json['termTags']) ??
          _extractStringList(json['term_tags']),
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageCaption: json['imageCaption'] as String?,
    );
  }

  /// Helper method to safely extract a list of strings from JSON
  static List<String>? _extractStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      try {
        return List<String>.from(value.map((e) => e.toString()));
      } catch (e) {
        // If conversion fails, return null
        return null;
      }
    } else if (value is String) {
      // If it's a string, try to parse it as a JSON array or return a list with the string
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) {
          return List<String>.from(parsed.map((e) => e.toString()));
        } else {
          // If it's not a list, return a list with the single string
          return [value];
        }
      } catch (e) {
        // If parsing fails, return a list with the original string
        return [value];
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dictionaryId': dictionaryId,
      'term': term,
      'reading': reading,
      'definitionTags': definitionTags,
      'rules': rules,
      'popularity': popularity,
      'definitions': definitions,
      'sequence': sequence,
      'termTags': termTags,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'imageCaption': imageCaption,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'term': term,
      'reading': reading,
      'definition_tags': definitionTags != null
          ? jsonEncode(definitionTags)
          : null,
      'rules': rules != null ? jsonEncode(rules) : null,
      'popularity': popularity,
      'definitions': jsonEncode(definitions),
      'sequence': sequence,
      'term_tags': termTags != null ? jsonEncode(termTags) : null,
      'audio_url': audioUrl,
      'image_url': imageUrl,
      'image_caption': imageCaption,
    };
  }

  DictionaryEntry copyWith({
    int? id,
    int? dictionaryId,
    String? term,
    String? reading,
    List<String>? definitionTags,
    List<String>? rules,
    double? popularity,
    List<String>? definitions,
    int? sequence,
    List<String>? termTags,
    String? audioUrl,
    String? imageUrl,
    String? imageCaption,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      dictionaryId: dictionaryId ?? this.dictionaryId,
      term: term ?? this.term,
      reading: reading ?? this.reading,
      definitionTags: definitionTags ?? this.definitionTags,
      rules: rules ?? this.rules,
      popularity: popularity ?? this.popularity,
      definitions: definitions ?? this.definitions,
      sequence: sequence ?? this.sequence,
      termTags: termTags ?? this.termTags,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageCaption: imageCaption ?? this.imageCaption,
    );
  }
}

class DictionarySearchResult {
  final List<DictionaryEntry> entries;
  final String query;
  final bool hasMore;

  DictionarySearchResult({
    required this.entries,
    required this.query,
    this.hasMore = false,
  });
}

class Dictionary {
  final int? id;
  final String name;
  final String title;
  final String? revision;
  final int format;
  final String? author;
  final String? url;
  final String? description;
  final String? attribution;
  final bool enabled;
  final int priority;
  final DateTime importedAt;
  
  Dictionary({
    this.id,
    required this.name,
    required this.title,
    this.revision,
    this.format = 3,
    this.author,
    this.url,
    this.description,
    this.attribution,
    this.enabled = true,
    this.priority = 0,
    required this.importedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'title': title,
      'revision': revision,
      'format': format,
      'author': author,
      'url': url,
      'description': description,
      'attribution': attribution,
      'enabled': enabled ? 1 : 0,
      'priority': priority,
      'imported_at': importedAt.millisecondsSinceEpoch,
    };
  }
  
  factory Dictionary.fromMap(Map<String, dynamic> map) {
    return Dictionary(
      id: map['id'] as int?,
      name: map['name'] as String,
      title: map['title'] as String,
      revision: map['revision'] as String?,
      format: map['format'] as int? ?? 3,
      author: map['author'] as String?,
      url: map['url'] as String?,
      description: map['description'] as String?,
      attribution: map['attribution'] as String?,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      priority: map['priority'] as int? ?? 0,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        map['imported_at'] as int,
      ),
    );
  }

  Dictionary copyWith({
    int? id,
    String? name,
    String? title,
    String? revision,
    int? format,
    String? author,
    String? url,
    String? description,
    String? attribution,
    bool? enabled,
    int? priority,
    DateTime? importedAt,
  }) {
    return Dictionary(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      revision: revision ?? this.revision,
      format: format ?? this.format,
      author: author ?? this.author,
      url: url ?? this.url,
      description: description ?? this.description,
      attribution: attribution ?? this.attribution,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      importedAt: importedAt ?? this.importedAt,
    );
  }
}

class KanjiEntry {
  final int? id;
  final int dictionaryId;
  final String character;
  final List<String>? onyomi;
  final List<String>? kunyomi;
  final List<String>? tags;
  final List<String> meanings;
  final Map<String, dynamic>? stats;
  
  KanjiEntry({
    this.id,
    required this.dictionaryId,
    required this.character,
    this.onyomi,
    this.kunyomi,
    this.tags,
    required this.meanings,
    this.stats,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'character': character,
      'onyomi': onyomi != null ? jsonEncode(onyomi) : null,
      'kunyomi': onyomi != null ? jsonEncode(kunyomi) : null,
      'tags': tags != null ? jsonEncode(tags) : null,
      'meanings': jsonEncode(meanings),
      'stats': stats != null ? jsonEncode(stats) : null,
    };
  }
  
  factory KanjiEntry.fromMap(Map<String, dynamic> map) {
    return KanjiEntry(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      character: map['character'] as String,
      onyomi: map['onyomi'] != null
          ? List<String>.from(jsonDecode(map['onyomi']))
          : null,
      kunyomi: map['kunyomi'] != null
          ? List<String>.from(jsonDecode(map['kunyomi']))
          : null,
      tags: map['tags'] != null
          ? List<String>.from(jsonDecode(map['tags']))
          : null,
      meanings: List<String>.from(jsonDecode(map['meanings'])),
      stats: map['stats'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['stats']))
          : null,
    );
  }
}

class DictionaryTag {
  final int? id;
  final int dictionaryId;
  final String name;
  final String category;
  final int sortOrder;
  final String? notes;
  final double popularity;
  
  DictionaryTag({
    this.id,
    required this.dictionaryId,
    required this.name,
    required this.category,
    this.sortOrder = 0,
    this.notes,
    this.popularity = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'name': name,
      'category': category,
      'sort_order': sortOrder,
      'notes': notes,
      'popularity': popularity,
    };
  }
  
  factory DictionaryTag.fromMap(Map<String, dynamic> map) {
    return DictionaryTag(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      notes: map['notes'] as String?,
      popularity: (map['popularity'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PitchAccent {
  final int? id;
  final int dictionaryId;
  final String term;
  final String reading;
  final List<PitchPattern> pitches;
  
  PitchAccent({
    this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    required this.pitches,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'term': term,
      'reading': reading,
      'pitches': jsonEncode(pitches.map((p) => p.toMap()).toList()),
    };
  }
  
  factory PitchAccent.fromMap(Map<String, dynamic> map) {
    return PitchAccent(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      term: map['term'] as String,
      reading: map['reading'] as String,
      pitches: (jsonDecode(map['pitches']) as List)
          .map((p) => PitchPattern.fromMap(p))
          .toList(),
    );
  }
}

class PitchPattern {
  final int position;
  final List<String>? tags;
  
  PitchPattern({
    required this.position,
    this.tags,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'position': position,
      if (tags != null) 'tags': tags,
    };
  }
  
  factory PitchPattern.fromMap(Map<String, dynamic> map) {
    return PitchPattern(
      position: map['position'] as int,
      tags: map['tags'] != null
          ? List<String>.from(map['tags'])
          : null,
    );
  }
}

class FrequencyData {
  final int? id;
  final int dictionaryId;
  final String term;
  final String reading;
  final String frequencyType;
  final double value;
  final String? displayValue;
  
  FrequencyData({
    this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    required this.frequencyType,
    required this.value,
    this.displayValue,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'term': term,
      'reading': reading,
      'frequency_type': frequencyType,
      'value': value,
      'display_value': displayValue,
    };
  }
  
  factory FrequencyData.fromMap(Map<String, dynamic> map) {
    return FrequencyData(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      term: map['term'] as String,
      reading: map['reading'] as String,
      frequencyType: map['frequency_type'] as String,
      value: (map['value'] as num).toDouble(),
      displayValue: map['display_value'] as String?,
    );
  }
}

// Additional models for Yomichan functionality
class YomichanDictionary {
  final int? id;
  final String name;
  final String title;
  final String? revision;
  final int format;
  final String? author;
  final String? url;
  final String? description;
  final String? attribution;
  final bool enabled;
  final int priority;
  final DateTime importedAt;

  YomichanDictionary({
    this.id,
    required this.name,
    required this.title,
    this.revision,
    this.format = 3,
    this.author,
    this.url,
    this.description,
    this.attribution,
    this.enabled = true,
    this.priority = 0,
    required this.importedAt,
  });

  YomichanDictionary copyWith({
    int? id,
    String? name,
    String? title,
    String? revision,
    int? format,
    String? author,
    String? url,
    String? description,
    String? attribution,
    bool? enabled,
    int? priority,
    DateTime? importedAt,
  }) {
    return YomichanDictionary(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      revision: revision ?? this.revision,
      format: format ?? this.format,
      author: author ?? this.author,
      url: url ?? this.url,
      description: description ?? this.description,
      attribution: attribution ?? this.attribution,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'title': title,
      'revision': revision,
      'format': format,
      'author': author,
      'url': url,
      'description': description,
      'attribution': attribution,
      'enabled': enabled ? 1 : 0,
      'priority': priority,
      'imported_at': importedAt.millisecondsSinceEpoch,
    };
  }

  factory YomichanDictionary.fromMap(Map<String, dynamic> map) {
    return YomichanDictionary(
      id: map['id'] as int?,
      name: map['name'] as String,
      title: map['title'] as String,
      revision: map['revision'] as String?,
      format: map['format'] as int? ?? 3,
      author: map['author'] as String?,
      url: map['url'] as String?,
      description: map['description'] as String?,
      attribution: map['attribution'] as String?,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      priority: map['priority'] as int? ?? 0,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        map['imported_at'] as int,
      ),
    );
  }
}

class DictionaryStats {
  final int entries;
  final int kanji;

  DictionaryStats({required this.entries, required this.kanji});
}

class YomichanSearchResult {
  final DictionaryEntry entry;
  final Dictionary? dictionary;
  final List<PitchAccent> pitches;
  final List<ToneInfo> tones;
  final List<FrequencyData> frequencies;

  YomichanSearchResult({
    required this.entry,
    this.dictionary,
    required this.pitches,
    required this.tones,
    required this.frequencies,
  });
}

class YomichanKanjiResult {
  final KanjiEntry kanji;
  final Dictionary? dictionary;
  final List<ToneInfo> tones;

  YomichanKanjiResult({
    required this.kanji,
    this.dictionary,
    required this.tones,
  });
}

class ToneInfo {
  final int? id;
  final int dictionaryId;
  final String term;
  final String reading;
  final int tone;
  final String? toneMark;

  ToneInfo({
    this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    required this.tone,
    this.toneMark,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'term': term,
      'reading': reading,
      'tone': tone,
      'tone_mark': toneMark,
    };
  }

  factory ToneInfo.fromMap(Map<String, dynamic> map) {
    return ToneInfo(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      term: map['term'] as String,
      reading: map['reading'] as String,
      tone: map['tone'] as int,
      toneMark: map['tone_mark'] as String?,
    );
  }
}

class WiktionaryEntry {
  final String term;
  final String definition;
  final String language;
  final String? etymology;
  final List<String>? examples;
  final List<String>? synonyms;
  final List<String>? antonyms;

  WiktionaryEntry({
    required this.term,
    required this.definition,
    required this.language,
    this.etymology,
    this.examples,
    this.synonyms,
    this.antonyms,
  });

  Map<String, dynamic> toJson() {
    return {
      'term': term,
      'definition': definition,
      'language': language,
      'etymology': etymology,
      'examples': examples,
      'synonyms': synonyms,
      'antonyms': antonyms,
    };
  }
}