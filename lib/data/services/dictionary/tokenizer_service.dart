import 'package:lang_core/lang_core.dart' as core;

import 'package:lang/database/database_manager.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/utils/japanese_grammar.dart';

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

    final placeholders = List.filled(candidates.length, '?').join(',');
    final results = await db.query(
      'entries',
      where: 'term IN ($placeholders)',
      whereArgs: candidates,
      orderBy: 'length(term) DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _matchFromRow(results.first);
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
