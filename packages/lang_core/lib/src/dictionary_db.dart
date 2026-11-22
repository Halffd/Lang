/// The dictionary surface the tokenizer needs.
///
/// Hosts implement this over their storage (sqlite entries table in the
/// Lang app). Keeping it a port keeps lang_core storage-free — other
/// consumers can back it with anything.
abstract interface class DictionaryDb {
  /// Returns the longest entry matching any of [candidates], or null
  /// when none match. Candidates arrive longest first; implementations
  /// should honour that order.
  ///
  /// A candidate may match an entry by its term (解読) **or by its
  /// reading** (かいどく). Reading matches are what keep kana compounds
  /// whole: without them a kana surface that is only stored under its
  /// kanji form gets chopped into fragments (かい + どく).
  ///
  /// The returned match carries the number of source characters it
  /// covers ([DictMatch.length]) so the tokenizer can slice the input
  /// correctly regardless of which field matched.
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

  /// Number of source characters this match covers. Null means "the
  /// length of [term]" — the term-match case.
  final int? matchLength;

  const DictMatch({
    required this.term,
    required this.reading,
    required this.definition,
    this.tags = const [],
    this.deconjugatedFrom,
    this.matchLength,
  });

  /// Source length covered by this match.
  int get length => matchLength ?? term.length;
}

/// Produces candidate base forms for an inflected [surface] string
/// (e.g. 食べて → 食べる). Hosts wire their grammar engine; without a
/// deconjugator the tokenizer still segments, just without inflected
/// form collapsing.
abstract interface class Deconjugator {
  /// Base forms for [surface], excluding [surface] itself.
  List<String> deconjugate(String surface);
}
