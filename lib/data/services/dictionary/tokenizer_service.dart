import 'package:lang_core/lang_core.dart' as core;

import 'package:lang/database/database_manager.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/utils/japanese_grammar.dart';
import 'package:sqflite/sqflite.dart' show Database;

/// App-side adapter over the shared [core.Tokenizer].
///
/// Segmentation, de-conjugation fallback and language detection live in
/// lang_core; this class only implements the [core.DictionaryDb] and
/// [core.Deconjugator] ports over the yomichan sqlite database and
/// keeps the pre-existing public surface (tokenize/detectLanguage/
/// splitSentences) so existing call sites are unchanged.
class TokenizerService implements core.DictionaryDb, core.Deconjugator {
  core.Tokenizer? _tokenizer;

  core.Tokenizer get _impl =>
      _tokenizer ??= core.Tokenizer(db: this, deconjugator: this);

  @override
  Future<core.DictMatch?> longestMatch(List<String> candidates) async {
    if (candidates.isEmpty) return null;
    final db = await DatabaseManager().database;

    // Candidates arrive longest-first. A candidate can match an entry
    // by its term (解読) or by its reading (かいどく) — the reading
    // match is what keeps kana compounds whole. Both passes run before
    // choosing, so the longest match wins: a kanji term かい must not
    // beat the reading かいどく of 解読.
    final termRows = await _queryIn(db, 'term', candidates);
    final readingRows = await _queryIn(db, 'reading', candidates);

    // index the rows by their key so the candidate scan is a lookup
    final termByKey = <String, Map<String, Object?>>{};
    for (final row in termRows) {
      termByKey.putIfAbsent(row['term'] as String? ?? '', () => row);
    }
    final readingByKey = <String, Map<String, Object?>>{};
    for (final row in readingRows) {
      final reading = (row['reading'] as String? ?? '').trim();
      readingByKey.putIfAbsent(reading, () => row);
      readingByKey.putIfAbsent(_toHiragana(reading), () => row);
    }

    Map<String, Object?>? bestRow;
    String? bestCandidate;
    for (final candidate in candidates) {
      // term match: the surface is the entry's term
      final termHit = termByKey[candidate];
      if (termHit != null) {
        bestRow = termHit;
        bestCandidate = candidate;
        break;
      }
      // reading match: the surface is the entry's reading (or its
      // kana-normalized form)
      final readingHit =
          readingByKey[candidate] ?? readingByKey[_toHiragana(candidate)];
      if (readingHit != null) {
        bestRow = readingHit;
        bestCandidate = candidate;
        break;
      }
    }
    if (bestRow == null || bestCandidate == null) return null;

    final match = _matchFromRow(bestRow);
    // The match covers the source surface that matched, not the kanji
    // term — carry the covered length so the tokenizer slices right.
    return core.DictMatch(
      term: match.term,
      reading: match.reading,
      definition: match.definition,
      tags: match.tags,
      matchLength: bestCandidate.length,
    );
  }

  /// Rows whose [column] equals one of [candidates], most popular
  /// first. Matching is case- and kana-normalized so katakana text
  /// finds the hiragana reading.
  Future<List<Map<String, Object?>>> _queryIn(
    Database db,
    String column,
    List<String> candidates,
  ) async {
    // query string → the candidate it stands for
    final queryKeys = <String, String>{};
    for (final c in candidates) {
      queryKeys[c] = c;
      queryKeys[_toHiragana(c)] = c;
      queryKeys[_toKatakana(c)] = c;
    }
    final keys = queryKeys.keys.toList(growable: false);
    if (keys.isEmpty) return const [];
    final placeholders = List.filled(keys.length, '?').join(',');
    return db.query(
      'entries',
      where: '$column IN ($placeholders)',
      whereArgs: keys,
      orderBy: 'popularity DESC',
      limit: 64,
    );
  }

  static String _toHiragana(String s) {
    final buf = StringBuffer();
    for (final r in s.runes) {
      // katakana → hiragana
      buf.writeCharCode(
        (r >= 0x30A1 && r <= 0x30F6) ? r - 0x60 : r,
      );
    }
    return buf.toString();
  }

  static String _toKatakana(String s) {
    final buf = StringBuffer();
    for (final r in s.runes) {
      // hiragana → katakana
      buf.writeCharCode(
        (r >= 0x3041 && r <= 0x3096) ? r + 0x60 : r,
      );
    }
    return buf.toString();
  }

  @override
  Future<core.DictMatch?> exactMatch(String term) async {
    final db = await DatabaseManager().database;
    final results = await db.query(
      'entries',
      where: 'term = ?',
      whereArgs: [term],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return _matchFromRow(results.first);
  }

  @override
  List<String> deconjugate(String surface) =>
      JapaneseGrammar.getAllPossibleForms(surface);

  core.DictMatch _matchFromRow(Map<String, Object?> row) {
    final entry = DictionaryEntry.fromJson(row);
    return core.DictMatch(
      term: entry.term,
      reading: entry.reading,
      definition: entry.definitions.isNotEmpty ? entry.definitions.first : '',
      tags: entry.tags,
    );
  }

  /// ISO 639-1 code for [text] — the same detector [tokenize] uses.
  String detectLanguage(String text) => _impl.detectLanguage(text);

  Future<List<core.Token>> tokenize(String text) => _impl.tokenize(text);

  /// Split text into sentences (surface → sentence).
  Map<String, String> splitSentences(List<core.Token> tokens) =>
      _impl.splitSentences(tokens);
}
