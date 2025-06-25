class DictionaryEntry {
  final String term;
  final String reading;
  final List<String> definitions;
  final List<String> tags;
  final int frequency;
  final List<String> examples;
  final Map<String, dynamic>? metadata;
  
  DictionaryEntry({
    required this.term,
    required this.reading,
    required this.definitions,
    this.tags = const [],
    this.frequency = -1,
    this.examples = const [],
    this.metadata,
  });
  
  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      term: json['term'] as String,
      reading: json['reading'] as String,
      definitions: List<String>.from(json['definitions']),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      frequency: json['frequency'] as int? ?? -1,
      examples: json['examples'] != null ? List<String>.from(json['examples']) : [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'term': term,
      'reading': reading,
      'definitions': definitions,
      'tags': tags,
      'frequency': frequency,
      'examples': examples,
      'metadata': metadata,
    };
  }
  
  @override
  String toString() {
    return '$term [$reading]: ${definitions.join('; ')}';
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
