import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../../database/database_manager.dart';

/// Service for Yomichan dictionary database operations
class YomichanService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await DatabaseManager().database;
    return _database!;
  }

  /// Search for dictionary entries by term
  Future<List<model.YomichanSearchResult>> searchEntries(String query) async {
    final db = await database;
    final results = <model.YomichanSearchResult>[];
    final seenEntryIds = <String>{};

    // Exact match first
    var rows = await db.query(
      'entries',
      where: 'term = ? OR reading = ?',
      whereArgs: [query, query],
      limit: 50,
    );

    if (rows.isEmpty) {
      // Try FTS5 search on definitions
      try {
        final ftsResults = await db.rawQuery(
          'SELECT e.* FROM entries e JOIN entries_fts f ON e.id = f.rowid WHERE f.definitions MATCH ? LIMIT 50',
          [query],
        );
        if (ftsResults.isNotEmpty) rows = ftsResults;
      } catch (_) {
        // Fallback to LIKE search
        rows = await db.query(
          'entries',
          where: 'definitions LIKE ?',
          whereArgs: ['%$query%'],
          limit: 50,
        );
      }
    }

    for (final row in rows) {
      final entry = model.DictionaryEntry.fromJson(row);
      final key = '${entry.dictionaryId}_${entry.id}';
      if (seenEntryIds.contains(key)) continue;
      seenEntryIds.add(key);

      final result = await _buildSearchResult(db, entry);
      if (result != null) results.add(result);
    }

    return results;
  }

  /// Search for kanji/Chinese characters
  Future<List<model.YomichanKanjiResult>> searchKanji(String character) async {
    final db = await database;
    final results = <model.YomichanKanjiResult>[];

    var rows = await db.query(
      'kanji',
      where: 'character = ?',
      whereArgs: [character],
    );

    for (final row in rows) {
      final kanji = model.KanjiEntry.fromMap(row);
      final dictResult = await db.query(
        'dictionaries',
        where: 'id = ?',
        whereArgs: [kanji.dictionaryId],
        limit: 1,
      );

      final dictionary = dictResult.isNotEmpty
          ? model.Dictionary.fromMap(dictResult.first)
          : null;

      List<model.ToneInfo> tones = [];
      if (ChineseUtil.containsChinese(kanji.character)) {
        final toneResults = await db.query(
          'tones',
          where: 'term = ?',
          whereArgs: [kanji.character],
        );
        tones = toneResults.map((t) => model.ToneInfo.fromMap(t)).toList();
      }

      results.add(model.YomichanKanjiResult(
        kanji: kanji,
        dictionary: dictionary,
        tones: tones,
      ));
    }

    return results;
  }

  Future<model.YomichanSearchResult?> _buildSearchResult(Database db, model.DictionaryEntry entry) async {
    // Get dictionary info
    final dictResult = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [entry.dictionaryId],
      limit: 1,
    );
    final dictionary = dictResult.isNotEmpty ? model.Dictionary.fromMap(dictResult.first) : null;

    // Get pitch accents
    final pitchResults = await db.query(
      'pitches',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final pitches = pitchResults.map((p) => model.PitchAccent.fromMap(p)).toList();

    // Get tone information
    final toneResults = await db.query(
      'tones',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final tones = toneResults.map((t) => model.ToneInfo.fromMap(t)).toList();

    // Get frequencies
    final freqResults = await db.query(
      'frequencies',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final frequencies = freqResults.map((f) => model.FrequencyData.fromMap(f)).toList();

    return model.YomichanSearchResult(
      entry: entry,
      dictionary: dictionary,
      pitches: pitches,
      tones: tones,
      frequencies: frequencies,
    );
  }

  /// Get all dictionaries
  Future<List<model.YomichanDictionary>> getDictionaries() async {
    final db = await database;
    final results = await db.query('dictionaries', orderBy: 'priority DESC, id ASC');
    return results.map((row) => model.YomichanDictionary.fromMap(row)).toList();
  }

  /// Toggle dictionary enabled status
  Future<void> toggleDictionary(int id, bool enabled) async {
    final db = await database;
    await db.update(
      'dictionaries',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete dictionary and all related data
  Future<void> deleteDictionary(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('entries', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('kanji', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('pitches', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('frequencies', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Get dictionary statistics
  Future<model.DictionaryStats> getStats(int id) async {
    final db = await database;
    final entriesCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM entries WHERE dictionary_id = ?', [id],
    )) ?? 0;
    final kanjiCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM kanji WHERE dictionary_id = ?', [id],
    )) ?? 0;
    return model.DictionaryStats(entries: entriesCount, kanji: kanjiCount);
  }
}