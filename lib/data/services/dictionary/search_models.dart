import '../../domain/entities/dictionary.dart' as model;

/// Options for search operations
class SearchOptions {
  final int limit;
  final bool exactMatch;
  final bool searchReadings;
  final List<int>? dictionaryIds;

  const SearchOptions({
    this.limit = 20,
    this.exactMatch = false,
    this.searchReadings = true,
    this.dictionaryIds,
  });
}

/// Result of a search operation
class SearchResult {
  final List<model.DictionaryEntry> entries;
  final List<model.KanjiEntry> kanji;
  final Map<String, List<model.PitchAccent>> pitchAccents;
  final Map<String, List<model.ToneInfo>> toneInfo;
  final Map<String, List<model.FrequencyData>> frequencies;
  final Map<int, model.Dictionary> dictionaries;
  final Map<String, model.DictionaryTag> tags;
  final Map<String, List<EtymologyEntry>> etymology;
  final Map<String, List<model.WiktionaryEntry>> wiktionaryDetails;
  final String query;
  final bool hasMore;

  SearchResult({
    required this.entries,
    required this.kanji,
    required this.pitchAccents,
    required this.toneInfo,
    required this.frequencies,
    required this.dictionaries,
    required this.tags,
    required this.etymology,
    required this.wiktionaryDetails,
    required this.query,
    this.hasMore = false,
  });

  SearchResult.empty(String query)
      : entries = [],
        kanji = [],
        pitchAccents = {},
        toneInfo = {},
        frequencies = {},
        dictionaries = {},
        tags = {},
        etymology = {},
        wiktionaryDetails = {},
        query = query,
        hasMore = false;
}

/// Etymology entry
class EtymologyEntry {
  final String sectionTitle;
  final String? originalLanguage;
  final String content;

  EtymologyEntry({
    required this.sectionTitle,
    this.originalLanguage,
    required this.content,
  });
}

/// Token representation
class Token {
  final String surface;
  final String reading;
  final String definition;
  final String partOfSpeech;
  final int startIndex;
  final int endIndex;

  const Token({
    required this.surface,
    required this.reading,
    required this.definition,
    required this.partOfSpeech,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson() => {
    'surface': surface,
    'reading': reading,
    'definition': definition,
    'partOfSpeech': partOfSpeech,
    'startIndex': startIndex,
    'endIndex': endIndex,
  };
}

/// Yomichan search result
class YomichanSearchResult {
  final model.DictionaryEntry entry;
  final model.Dictionary? dictionary;
  final List<model.PitchAccent> pitches;
  final List<model.ToneInfo> tones;
  final List<model.FrequencyData> frequencies;

  YomichanSearchResult({
    required this.entry,
    this.dictionary,
    required this.pitches,
    required this.tones,
    required this.frequencies,
  });
}

/// Yomichan kanji result
class YomichanKanjiResult {
  final model.KanjiEntry kanji;
  final model.Dictionary? dictionary;
  final List<model.ToneInfo> tones;

  YomichanKanjiResult({
    required this.kanji,
    this.dictionary,
    required this.tones,
  });
}