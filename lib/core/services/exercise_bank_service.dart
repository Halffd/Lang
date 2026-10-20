import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:sqflite/sqflite.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/presentation/screens/study/ai_exercise_parser.dart';

/// Pre-generated exercise bank: exercises stored in the yomichan
/// database, deduped by normalized prompt hash, QA-flaggable, served
/// instantly for common languages/levels with live generation as the
/// top-up for gaps.
class ExerciseBankService {
  ExerciseBankService._();
  static final ExerciseBankService instance = ExerciseBankService._();

  static const String _table = 'exercise_bank';

  bool _tableEnsured = false;

  /// Normalize + hash key for dedupe (mimiuchi review lever 2).
  static String normalize(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  static String dedupeKey(AiExercise e) {
    if (e.type == 'match' && e.pairs != null) {
      // match has no prompt — the normalized pair set is the identity
      final pairs =
          e.pairs!
              .map(
                (p) =>
                    '${normalize(p['left'] ?? '')}=${normalize(p['right'] ?? '')}',
              )
              .toList()
            ..sort();
      return 'match|${pairs.join(';')}';
    }
    return '${e.type}|${normalize(e.prompt)}';
  }

  Future<dynamic> get _db async => DatabaseManager().database;

  Future<void> _ensureTable() async {
    if (_tableEnsured) return;
    final db = await _db;
    // standalone table: no schema-version bump needed (additive)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_bank (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dedupe_key TEXT NOT NULL UNIQUE,
        language TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'any',
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        qa_status TEXT NOT NULL DEFAULT 'pending',
        source TEXT NOT NULL DEFAULT 'pregenerated',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exbank_lang_level '
      'ON exercise_bank (language, level)',
    );
    _tableEnsured = true;
  }

  /// Insert exercises, skipping any whose dedupe key already exists
  /// (batch-job dedupe: multiple pre-generation runs stay clean).
  /// Returns the number actually inserted.
  Future<int> insertMany(
    List<AiExercise> exercises, {
    required String language,
    String level = 'any',
    String source = 'pregenerated',
  }) async {
    await _ensureTable();
    final db = await _db;
    var inserted = 0;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in exercises) {
      final payload = jsonEncode({
        'type': e.type,
        'prompt': e.prompt,
        if (e.promptSub != null) 'prompt_sub': e.promptSub,
        'answer': e.answer,
        if (e.choices != null) 'choices': e.choices,
        if (e.pairs != null) 'pairs': [for (final p in e.pairs!) p],
        if (e.breakdown != null)
          'breakdown': [
            for (final b in e.breakdown!)
              {
                'char': b.char,
                if (b.reading != null) 'reading': b.reading,
                'meaning': b.meaning,
              },
          ],
      });
      batch.insert(_table, {
        'dedupe_key': dedupeKey(e),
        'language': language,
        'level': level,
        'type': e.type,
        'payload': payload,
        'qa_status': 'pending',
        'source': source,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final results = await batch.commit(noResult: true);
    inserted = results.length;
    if (inserted > 0 && kDebugMode) {
      debugPrint('exercise bank: inserted $inserted of ${exercises.length}');
    }
    return inserted;
  }

  /// Fetch up to [limit] exercises for a language/level, preferring
  /// QA-verified ones. Flagged rows are never served.
  Future<List<AiExercise>> fetch({
    required String language,
    String level = 'any',
    int limit = 50,
  }) async {
    await _ensureTable();
    final db = await _db;
    final rows = await db.query(
      _table,
      where:
          "language = ? AND (level = ? OR level = ?) AND qa_status != 'flagged'",
      whereArgs: [language, level, 'any'],
      orderBy: "CASE qa_status WHEN 'verified' THEN 0 ELSE 1 END, id",
      limit: limit,
    );
    final out = <AiExercise>[];
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload']?.toString() ?? '{}');
        if (payload is Map) {
          out.add(
            AiExercise.fromJson(
              payload.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      } catch (_) {
        continue; // skip malformed rows
      }
    }
    return out;
  }

  /// Pending rows with their ids, for the semantic-QA grader batch job.
  Future<List<({int id, AiExercise exercise})>> fetchPending({
    String language = '',
    int limit = 100,
  }) async {
    await _ensureTable();
    final db = await _db;
    final rows = await db.query(
      _table,
      where: language.isEmpty
          ? "qa_status = 'pending'"
          : "qa_status = 'pending' AND language = ?",
      whereArgs: language.isEmpty ? null : [language],
      orderBy: 'id',
      limit: limit,
    );
    final out = <({int id, AiExercise exercise})>[];
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload']?.toString() ?? '{}');
        if (payload is Map) {
          out.add((
            id: row['id']! as int,
            exercise: AiExercise.fromJson(
              payload.map((k, v) => MapEntry(k.toString(), v)),
            ),
          ));
        }
      } catch (_) {
        continue; // skip malformed rows
      }
    }
    return out;
  }

  Future<int> count({required String language, String level = 'any'}) async {
    await _ensureTable();
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'language = ? AND (level = ? OR level = ?)',
      whereArgs: [language, level, 'any'],
    );
    return rows.length;
  }

  /// Batch QA: mark a row verified/flagged (second-AI-pass results land
  /// here asynchronously, never blocking lesson start).
  Future<void> setQaStatus(int id, String status) async {
    await _ensureTable();
    final db = await _db;
    await db.update(
      _table,
      {'qa_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove flagged exercises from the bank (batch QA cleanup).
  Future<int> purgeFlagged() async {
    await _ensureTable();
    final db = await _db;
    return db.delete(_table, where: "qa_status = 'flagged'");
  }
}
