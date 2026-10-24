/// The dictionary surface the tokenizer needs.
///
/// Hosts implement this over their storage (sqlite entries table in the
/// Lang app). Keeping it a port keeps lang_core storage-free — other
/// consumers can back it with anything.
abstract interface class DictionaryDb {
  /// Returns the longest entry from [candidates] found in the
  /// dictionary, or null when none match. Candidates arrive longest
  /// first; implementations should honour that order.
  Future<DictMatch?> longestMatch(List<String> candidates);

  /// Exact-term lookup, used by the de-conjugation fallback.
  Future<DictMatch?> exactMatch(String term);
}

class DictMatch {
  final String term;
  final String reading;
  final String definition;

  /// Dictionary tags (definition + term tags), for hosts that surface
  /// word types.
  final List<String> tags;

  /// Set when [term] was reached by de-conjugating the surface form
  /// (e.g. surface 食べて matched base form 食べる).
  final String? deconjugatedFrom;

  const DictMatch({
    required this.term,
    required this.reading,
    required this.definition,
    this.tags = const [],
    this.deconjugatedFrom,
  });
}

/// Produces candidate base forms for an inflected [surface] string
/// (e.g. 食べて → 食べる). Hosts wire their grammar engine; without a
/// deconjugator the tokenizer still segments, just without inflected
/// form collapsing.
abstract interface class Deconjugator {
  /// Base forms for [surface], excluding [surface] itself.
  List<String> deconjugate(String surface);
}
