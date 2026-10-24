/// One segmented unit of text.
class Token {
  final String surface;
  final String reading;
  final String definition;
  final String partOfSpeech;
  final int startIndex;
  final int endIndex;

  /// Dictionary tags carried through from the match (empty for
  /// unmatched characters and whitespace splits).
  final List<String> tags;

  /// Base form when this token was matched via de-conjugation.
  final String? deconjugatedFrom;

  const Token({
    required this.surface,
    required this.reading,
    required this.definition,
    required this.partOfSpeech,
    required this.startIndex,
    required this.endIndex,
    this.tags = const [],
    this.deconjugatedFrom,
  });

  Map<String, dynamic> toJson() => {
        'surface': surface,
        'reading': reading,
        'definition': definition,
        'partOfSpeech': partOfSpeech,
        'startIndex': startIndex,
        'endIndex': endIndex,
        'tags': tags,
        if (deconjugatedFrom != null) 'deconjugatedFrom': deconjugatedFrom,
      };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        surface: json['surface'] as String? ?? '',
        reading: json['reading'] as String? ?? '',
        definition: json['definition'] as String? ?? '',
        partOfSpeech: json['partOfSpeech'] as String? ?? '',
        startIndex: json['startIndex'] as int? ?? 0,
        endIndex: json['endIndex'] as int? ?? 0,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        deconjugatedFrom: json['deconjugatedFrom'] as String?,
      );
}
