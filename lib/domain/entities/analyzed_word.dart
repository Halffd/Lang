class AnalyzedWord {
  final String word;
  final String? reading;
  final int? frequency;
  final String? sentence;
  final List<String> ichiMoeDefinitions;
  final String? wiktionaryHtml;
  final List<String> kanjiList;
  final Map<String, dynamic> kanjiDetails;
  final Map<String, Map<String, String>> kanjipediaData;
  final List<Map<String, dynamic>> localDefinitions;

  AnalyzedWord({
    required this.word,
    this.reading,
    this.frequency,
    this.sentence,
    this.ichiMoeDefinitions = const [],
    this.wiktionaryHtml,
    this.kanjiList = const [],
    this.kanjiDetails = const {},
    this.kanjipediaData = const {},
    this.localDefinitions = const [],
  });

  AnalyzedWord copyWith({
    String? word,
    String? reading,
    int? frequency,
    String? sentence,
    List<String>? ichiMoeDefinitions,
    String? wiktionaryHtml,
    List<String>? kanjiList,
    Map<String, dynamic>? kanjiDetails,
    Map<String, Map<String, String>>? kanjipediaData,
    List<Map<String, dynamic>>? localDefinitions,
  }) {
    return AnalyzedWord(
      word: word ?? this.word,
      reading: reading ?? this.reading,
      frequency: frequency ?? this.frequency,
      sentence: sentence ?? this.sentence,
      ichiMoeDefinitions: ichiMoeDefinitions ?? this.ichiMoeDefinitions,
      wiktionaryHtml: wiktionaryHtml ?? this.wiktionaryHtml,
      kanjiList: kanjiList ?? this.kanjiList,
      kanjiDetails: kanjiDetails ?? this.kanjiDetails,
      kanjipediaData: kanjipediaData ?? this.kanjipediaData,
      localDefinitions: localDefinitions ?? this.localDefinitions,
    );
  }
}
