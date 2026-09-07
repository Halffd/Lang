import 'dart:convert';
import 'package:lang/domain/entities/dictionary.dart';

/// Result of a recursive definition lookup: a dictionary entry
/// plus nested lookups for terms found inside its definition.
///
/// Mirrors Yomitan's recursive lookup: words in a definition can be
/// looked up themselves, nesting entries up to [RecursiveLookup]
/// max depth.
class RecursiveEntry {
  final DictionaryEntry entry;

  /// Nested entries for terms discovered inside [entry]'s
  /// definitions. Max nesting depth 3.
  final List<RecursiveEntry> children;

  /// Terms found in definitions that could not be resolved to an
  /// entry (rendered as plain text chips).
  final List<String> unresolvedTerms;

  RecursiveEntry({
    required this.entry,
    this.children = const [],
    this.unresolvedTerms = const [],
  });
}

/// Recursive lookup engine settings and logic.
class RecursiveLookup {
  /// Maximum nesting depth (Yomitan default: 3).
  static const int maxDepth = 3;

  /// Definitions longer than this many characters are not scanned
  /// for sub-terms (performance guard).
  static const int maxDefinitionLengthForScan = 2000;

  /// Maximum child lookups per entry level.
  static const int maxChildrenPerEntry = 8;

  /// Find [term] in [dictionary], then recursively look up words
  /// found inside its definitions.
  ///
  /// [searchFn] performs a single lookup and returns matching
  /// entries. [tokenizer] splits a definition into candidate terms.
  static Future<RecursiveEntry?> lookup(
    String term,
    Future<List<DictionaryEntry>> Function(String) searchFn, {
    int depth = 0,
    _Visited visited = const _Visited.empty(),
  }) async {
    if (depth >= maxDepth) return null;
    if (visited.contains(term)) return null;

    final entries = await searchFn(term);
    if (entries.isEmpty) return null;
    final entry = entries.first;

    // reached depth: no children
    if (depth == maxDepth - 1) {
      return RecursiveEntry(entry: entry);
    }

    final nextVisited = visited.add(term);
    final candidates = extractSubTerms(entry);
    final children = <RecursiveEntry>[];
    final unresolved = <String>[];

    for (final candidate in candidates.take(maxChildrenPerEntry)) {
      final child = await lookup(
        candidate,
        searchFn,
        depth: depth + 1,
        visited: nextVisited,
      );
      if (child != null) {
        children.add(child);
      } else {
        unresolved.add(candidate);
      }
    }

    return RecursiveEntry(
      entry: entry,
      children: children,
      unresolvedTerms: unresolved,
    );
  }

  /// Extract candidate lookup terms from an entry's definitions.
  /// Plain text only - structured content is flattened first.
  static List<String> extractSubTerms(DictionaryEntry entry) {
    final terms = <String>[];
    for (final def in entry.definitions) {
      if (def.length > maxDefinitionLengthForScan) continue;
      final text = _flatten(def);
      // candidate: CJK word runs (1+ chars: single kanji/kana are
      // valid lookup terms) or latin words 3+
      for (final match in RegExp(
        r'[\u3040-\u30FF\u3400-\u9FFF]+',
      ).allMatches(text)) {
        final t = match.group(0)!;
        if (t != entry.term && t.length >= 1) terms.add(t);
      }
      for (final match in RegExp(r'[A-Za-z]{3,}').allMatches(text)) {
        final t = match.group(0)!;
        if (t.toLowerCase() != entry.term.toLowerCase()) {
          terms.add(t);
        }
      }
    }
    // unique, keep order
    return terms.toSet().toList();
  }

  static String _flatten(String definition) {
    // structured-content JSON -> plain text
    if (definition.trimLeft().startsWith('{') ||
        definition.trimLeft().startsWith('[')) {
      try {
        final decoded = _tryDecode(definition);
        final buf = StringBuffer();
        _flattenNode(decoded, buf);
        return buf.toString();
      } catch (_) {
        return definition;
      }
    }
    return definition;
  }

  static dynamic _tryDecode(String raw) {
    final t = raw.trim();
    if (!t.startsWith('{') && !t.startsWith('[')) return null;
    try {
      return jsonDecode(t);
    } catch (_) {
      return null;
    }
  }

  static void _flattenNode(dynamic node, StringBuffer out) {
    if (node is String) {
      out.write(node);
    } else if (node is List) {
      for (final c in node) {
        _flattenNode(c, out);
      }
    } else if (node is Map) {
      final m = node.map((k, v) => MapEntry(k.toString(), v));
      final tag = m['tag'] as String?;
      if (tag == 'br' || tag == 'line-break') {
        out.write(' ');
        return;
      }
      if (tag == 'rt' || tag == 'rp') return;
      _flattenNode(m['content'], out);
    }
  }
}

/// Cycle guard: terms already visited on this lookup path.
class _Visited {
  final Set<String> terms;
  const _Visited.empty() : terms = const {};
  const _Visited(this.terms);

  bool contains(String t) => terms.contains(t);

  _Visited add(String t) {
    final next = Set<String>.from(terms)..add(t);
    return _Visited(next);
  }
}
