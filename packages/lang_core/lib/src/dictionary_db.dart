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
}

class DictMatch {
  final String term;
  final String reading;
  final String definition;

  const DictMatch({
    required this.term,
    required this.reading,
    required this.definition,
  });
}
