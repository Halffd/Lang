import 'dart:convert';

class EtymologyInfo {
  final String word;
  final String language;
  final List<EtymologyEntry> entries;
  final DateTime lastUpdated;

  EtymologyInfo({
    required this.word,
    required this.language,
    required this.entries,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'language': language,
      'entries': entries.map((x) => x.toMap()).toList(),
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory EtymologyInfo.fromMap(Map<String, dynamic> map) {
    return EtymologyInfo(
      word: map['word'] ?? '',
      language: map['language'] ?? '',
      entries: List<EtymologyEntry>.from(
        (map['entries'] as List).map<EtymologyEntry>((x) => EtymologyEntry.fromMap(x)),
      ),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated']?.toInt() ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory EtymologyInfo.fromJson(String source) => EtymologyInfo.fromMap(json.decode(source));
}

class EtymologyEntry {
  final String sectionTitle;
  final String originalLanguage;  // The original language being traced (e.g., Latin, Old English)
  final String content;  // The etymology content
  final Map<String, String> additionalLanguages;  // Additional languages for the same etymology

  EtymologyEntry({
    required this.sectionTitle,
    required this.originalLanguage,
    required this.content,
    this.additionalLanguages = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'sectionTitle': sectionTitle,
      'originalLanguage': originalLanguage,
      'content': content,
      'additionalLanguages': additionalLanguages,
    };
  }

  factory EtymologyEntry.fromMap(Map<String, dynamic> map) {
    return EtymologyEntry(
      sectionTitle: map['sectionTitle'] ?? '',
      originalLanguage: map['originalLanguage'] ?? '',
      content: map['content'] ?? '',
      additionalLanguages: Map<String, String>.from(map['additionalLanguages'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory EtymologyEntry.fromJson(String source) => EtymologyEntry.fromMap(json.decode(source));
}