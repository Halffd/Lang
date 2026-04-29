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
  final MdbgData? mdbgData;

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
    this.mdbgData,
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
    MdbgData? mdbgData,
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
      mdbgData: mdbgData ?? this.mdbgData,
    );
  }
}

class MdbgData {
  final String pinyin;
  final List<String> definitions;
  final String? traditional;
  final String? simplified;

  MdbgData({
    required this.pinyin,
    required this.definitions,
    this.traditional,
    this.simplified,
  });
}
