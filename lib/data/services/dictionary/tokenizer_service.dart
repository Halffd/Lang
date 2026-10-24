import 'package:lang_core/lang_core.dart' as core;

import 'package:lang/database/database_manager.dart';
import 'package:lang/domain/entities/dictionary.dart';

/// App-side adapter over the shared [core.Tokenizer].
///
/// Segmentation and language detection live in lang_core; this class
/// only implements the [core.DictionaryDb] port over the yomichan
/// sqlite database and keeps the pre-existing public surface
/// (tokenize/detectLanguage/splitSentences) so existing call sites are
/// unchanged.
class TokenizerService implements core.DictionaryDb {
  core.Tokenizer? _tokenizer;

  core.Tokenizer get _impl => _tokenizer ??= core.Tokenizer(db: this);

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
    final entry = DictionaryEntry.fromJson(results.first);
    return core.DictMatch(
      term: entry.term,
      reading: entry.reading,
      definition: entry.definitions.isNotEmpty ? entry.definitions.first : '',
    );
  }

  /// ISO 639-1 code for [text] — the same detector [tokenize] uses.
  String detectLanguage(String text) => _impl.detectLanguage(text);

  Future<List<core.Token>> tokenize(String text) => _impl.tokenize(text);

  /// Split text into sentences (surface → sentence).
  Map<String, String> splitSentences(List<core.Token> tokens) =>
      _impl.splitSentences(tokens);
}
