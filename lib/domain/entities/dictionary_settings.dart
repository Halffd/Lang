/// Per-dictionary settings scoped to a profile: priority (lower =
/// shown first), enable state, and matching conditions.
///
/// Mirrors Yomitan's per-profile dictionary options:
/// - priority: sort order across dictionaries
/// - enabled: quick toggle
/// - conditions: optional restrictions. A dictionary with no
///   conditions participates in every lookup. With conditions set,
///   ALL populated condition fields must match for the dictionary
///   to contribute results.
class DictionarySettings {
  /// Lower value = higher priority (0 = default, like Yomitan).
  int priority = 0;
  bool enabled = true;

  // ---- conditions (all populated ones must match) ----

  /// Restrict to lookups in these languages, e.g. ['ja', 'zh'].
  /// Empty = no language restriction.
  List<String> languages = [];

  /// Restrict to terms whose reading matches one of these patterns
  /// (exact or wildcard * suffix). Empty = no restriction.
  List<String> readingPatterns = [];

  /// Restrict to terms matching this regex (applied to the term).
  /// null = no restriction.
  String? termRegex;

  /// Restrict to terms carrying one of these part-of-speech tags
  /// (matched against term/definition tags). Empty = no restriction.
  List<String> partOfSpeechTags = [];

  DictionarySettings();

  DictionarySettings copy() {
    final s = DictionarySettings();
    s.priority = priority;
    s.enabled = enabled;
    s.languages = List.from(languages);
    s.readingPatterns = List.from(readingPatterns);
    s.termRegex = termRegex;
    s.partOfSpeechTags = List.from(partOfSpeechTags);
    return s;
  }

  Map<String, dynamic> toJson() => {
    'priority': priority,
    'enabled': enabled,
    'languages': languages,
    'readingPatterns': readingPatterns,
    'termRegex': termRegex,
    'partOfSpeechTags': partOfSpeechTags,
  };

  void fromJson(Map<String, dynamic> json) {
    priority = (json['priority'] as num?)?.toInt() ?? priority;
    enabled = json['enabled'] ?? enabled;
    final langs = json['languages'];
    if (langs is List) languages = langs.cast<String>();
    final rps = json['readingPatterns'];
    if (rps is List) readingPatterns = rps.cast<String>();
    termRegex = json['termRegex'] as String?;
    final pos = json['partOfSpeechTags'];
    if (pos is List) partOfSpeechTags = pos.cast<String>();
  }

  static DictionarySettings deserialize(dynamic raw) {
    final s = DictionarySettings();
    if (raw is Map<String, dynamic>) s.fromJson(raw);
    return s;
  }

  /// True when no condition would ever exclude anything.
  bool get hasNoConditions =>
      languages.isEmpty &&
      readingPatterns.isEmpty &&
      termRegex == null &&
      partOfSpeechTags.isEmpty;

  /// Evaluate whether a lookup matches this dictionary's conditions.
  /// [term], [reading], [lookupLanguage] and [tags] describe the
  /// lookup context. Populated conditions must all hold.
  bool matches({
    required String term,
    String? reading,
    String? lookupLanguage,
    List<String> tags = const [],
  }) {
    if (!hasNoConditions) {
      if (languages.isNotEmpty &&
          (lookupLanguage == null || !languages.contains(lookupLanguage))) {
        return false;
      }
      if (readingPatterns.isNotEmpty) {
        final r = reading ?? '';
        if (!readingPatterns.any((p) => _patternMatches(p, r))) {
          return false;
        }
      }
      if (termRegex != null && termRegex!.isNotEmpty) {
        try {
          if (!RegExp(termRegex!).hasMatch(term)) return false;
        } catch (_) {
          // invalid user regex never blocks everything
        }
      }
      if (partOfSpeechTags.isNotEmpty) {
        final hit = tags.any(
          (t) =>
              partOfSpeechTags.any((p) => t.toLowerCase() == p.toLowerCase()),
        );
        if (!hit) return false;
      }
    }
    return true;
  }

  static bool _patternMatches(String pattern, String value) {
    if (pattern.contains('*')) {
      final regex = RegExp(
        '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
      );
      return regex.hasMatch(value);
    }
    return pattern == value;
  }
}

/// Per-profile map of dictionary name -> settings.
class ProfileDictionarySettings {
  final Map<String, DictionarySettings> _byDictionary = {};

  DictionarySettings forDictionary(String name) =>
      _byDictionary[name] ??= DictionarySettings();

  void set(String name, DictionarySettings s) => _byDictionary[name] = s;

  void remove(String name) => _byDictionary.remove(name);

  Map<String, dynamic> toJson() => {
    for (final e in _byDictionary.entries) e.key: e.value.toJson(),
  };

  void fromJson(Map<String, dynamic> json) {
    _byDictionary.clear();
    json.forEach((name, raw) {
      _byDictionary[name] = DictionarySettings.deserialize(raw);
    });
  }

  static ProfileDictionarySettings deserialize(dynamic raw) {
    final s = ProfileDictionarySettings();
    if (raw is Map<String, dynamic>) s.fromJson(raw);
    return s;
  }

  /// Sort dictionary names by priority (lower first), disabled last.
  List<String> sortedByPriority(Set<String> names) {
    final list = names.toList();
    list.sort((a, b) {
      final ea = _byDictionary[a]?.enabled ?? true;
      final eb = _byDictionary[b]?.enabled ?? true;
      if (ea != eb) return ea ? -1 : 1;
      final pa = _byDictionary[a]?.priority ?? 0;
      final pb = _byDictionary[b]?.priority ?? 0;
      if (pa != pb) return pa.compareTo(pb);
      return a.compareTo(b);
    });
    return list;
  }

  /// Sort [DictionaryEntry]-like results by their source priority.
  /// [nameOf] extracts the dictionary name from a result item.
  List<T> sortResults<T>(List<T> results, String Function(T item) nameOf) {
    final copy = List<T>.from(results);
    copy.sort((a, b) {
      final pa = _byDictionary[nameOf(a)]?.priority ?? 0;
      final pb = _byDictionary[nameOf(b)]?.priority ?? 0;
      return pa.compareTo(pb);
    });
    return copy;
  }
}
