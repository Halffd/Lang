import 'package:flutter/foundation.dart';
import 'dart:async';

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lang/core/services/audio_service.dart';
import 'package:lang/data/datasources/note_local_data_source.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/utils/chinese_util.dart';

/// Service for Yomichan dictionary database operations
class YomichanService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await DatabaseManager().database;
    return _database!;
  }

  /// Browse dictionary entries starting with [prefix], ordered by
  /// term (A-Z browse for the dictionary screen). Limits to
  /// [limit] entries offset by [offset] for paging.
  Future<List<YomichanSearchResult>> browseEntries(
    String prefix, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final escaped = prefix.replaceAll('%', '\\%');
    var rows = await db.query(
      'entries',
      where: 'term LIKE ? ESCAPE \'\\\'',
      whereArgs: ['$escaped%'],
      orderBy: 'term',
      limit: limit,
      offset: offset,
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'entries',
        where: 'reading LIKE ? ESCAPE \'\\\'',
        whereArgs: ['$escaped%'],
        orderBy: 'reading',
        limit: limit,
        offset: offset,
      );
    }

    final results = <YomichanSearchResult>[];
    final seen = <String>{};
    for (final row in rows) {
      final entry = DictionaryEntry.fromJson(row);
      final key = '${entry.dictionaryId}_${entry.id}';
      if (seen.contains(key)) continue;
      seen.add(key);
      final result = await _buildSearchResult(db, entry);
      if (result != null) results.add(result);
    }
    return results;
  }

  /// Search for dictionary entries by term
  Future<List<YomichanSearchResult>> searchEntries(String query) async {
    final db = await database;
    final results = <YomichanSearchResult>[];
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
      final entry = DictionaryEntry.fromJson(row);
      final key = '${entry.dictionaryId}_${entry.id}';
      if (seenEntryIds.contains(key)) continue;
      seenEntryIds.add(key);

      final result = await _buildSearchResult(db, entry);
      if (result != null) results.add(result);
    }

    return results;
  }

  /// Search for kanji/Chinese characters
  Future<List<YomichanKanjiResult>> searchKanji(String character) async {
    final db = await database;
    final results = <YomichanKanjiResult>[];

    var rows = await db.query(
      'kanji',
      where: 'character = ?',
      whereArgs: [character],
    );

    for (final row in rows) {
      final kanji = KanjiEntry.fromMap(row);
      final dictResult = await db.query(
        'dictionaries',
        where: 'id = ?',
        whereArgs: [kanji.dictionaryId],
        limit: 1,
      );

      final dictionary = dictResult.isNotEmpty
          ? Dictionary.fromMap(dictResult.first)
          : null;

      List<ToneInfo> tones = [];
      if (ChineseUtil.containsChinese(kanji.character)) {
        final toneResults = await db.query(
          'tones',
          where: 'term = ?',
          whereArgs: [kanji.character],
        );
        tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();
      }

      results.add(
        YomichanKanjiResult(kanji: kanji, dictionary: dictionary, tones: tones),
      );
    }

    return results;
  }

  Future<YomichanSearchResult?> _buildSearchResult(
    Database db,
    DictionaryEntry entry,
  ) async {
    // Get dictionary info
    final dictResult = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [entry.dictionaryId],
      limit: 1,
    );
    final dictionary = dictResult.isNotEmpty
        ? Dictionary.fromMap(dictResult.first)
        : null;

    // Get pitch accents
    final pitchResults = await db.query(
      'pitches',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final pitches = pitchResults.map((p) => PitchAccent.fromMap(p)).toList();

    // Get tone information
    final toneResults = await db.query(
      'tones',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();

    // Get frequencies
    final freqResults = await db.query(
      'frequencies',
      where: 'dictionary_id = ? AND term = ? AND reading = ?',
      whereArgs: [entry.dictionaryId, entry.term, entry.reading],
    );
    final frequencies = freqResults
        .map((f) => FrequencyData.fromMap(f))
        .toList();

    return YomichanSearchResult(
      entry: entry,
      dictionary: dictionary,
      pitches: pitches,
      tones: tones,
      frequencies: frequencies,
    );
  }

  /// Get all dictionaries
  Future<List<YomichanDictionary>> getDictionaries() async {
    final db = await database;
    final results = await db.query(
      'dictionaries',
      orderBy: 'priority DESC, id ASC',
    );
    return results.map((row) => YomichanDictionary.fromMap(row)).toList();
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
      await txn.delete(
        'frequencies',
        where: 'dictionary_id = ?',
        whereArgs: [id],
      );
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Get dictionary statistics
  Future<DictionaryStats> getStats(int id) async {
    final db = await database;
    final entriesCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM entries WHERE dictionary_id = ?',
            [id],
          ),
        ) ??
        0;
    final kanjiCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM kanji WHERE dictionary_id = ?',
            [id],
          ),
        ) ??
        0;
    return DictionaryStats(entries: entriesCount, kanji: kanjiCount);
  }

  /// Look up a single word (wrapper around searchEntries)
  Future<List<YomichanSearchResult>> lookupWord(
    String query,
    String language,
  ) async {
    return searchEntries(query);
  }

  /// Enrich a word with full details (wrapper around searchEntries)
  Future<AnalyzedWord?> enrichWord(
    String word,
    String language, {
    bool showIchiMoe = true,
    bool showWiktionary = true,
    bool showKanji = true,
    bool showEtymology = true,
  }) async {
    final results = await searchEntries(word);
    if (results.isEmpty) return null;

    final result = results.first;
    return AnalyzedWord(
      word: result.entry.term,
      reading: AnalyzedWord.readingFor(
        language: language,
        term: result.entry.term,
        yomichanReading: result.entry.reading,
      ),
      frequency: result.frequencies.isNotEmpty
          ? result.frequencies.first.value.toInt()
          : null,
      ichiMoeDefinitions: result.entry.definitions
          .where((d) => d.isNotEmpty)
          .toList(),
      localDefinitions: result.dictionary != null
          ? [
              {
                'id': result.dictionary!.id,
                'name': result.dictionary!.title,
                'definition': result.entry.definitions.join('||'),
              },
            ]
          : [],
    );
  }

  final NoteLocalDataSource _notes = NoteLocalDataSource();

  /// Save a word to favorites
  Future<void> saveWord(String word, {String? sentence}) async {
    await _notes.addWord(word, sentence: sentence);
  }

  /// Remove a saved word
  Future<void> removeSavedWord(String word) async {
    await _notes.removeWord(word);
  }

  /// Add word to history
  Future<void> addToHistory(String word) async {
    await _notes.addToHistory(word);
  }

  /// Get saved words
  Future<List<Map<String, dynamic>>> getSavedWords() async {
    return _notes.getSavedEntries();
  }

  /// Get history
  Future<List<String>> getHistory() async {
    return _notes.getHistory();
  }

  /// Initialize service
  Future<void> init() async {
    try {
      await database; // Ensure database is initialized
    } catch (e) {
      debugPrint('YomichanService init error: $e');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // dictionary export (Yomichan-format zip)
  // ----------------------------------------------------------

  /// Export an installed dictionary back to a Yomichan-format archive:
  /// index.json + term_bank_N + kanji_bank_N + tag_bank_N files, ready
  /// for re-import. Throws when the dictionary does not exist.
  Future<Uint8List> exportDictionaryArchive(String title) async {
    final db = await database;
    final dictRows = await db.query(
      'dictionaries',
      where: 'name = ?',
      whereArgs: [title],
      limit: 1,
    );
    if (dictRows.isEmpty) {
      throw Exception('dictionary "\$title" not found');
    }
    final dictId = dictRows.first['id'] as int;

    final termRows = await db.query(
      'entries',
      where: 'dictionary_id = ?',
      whereArgs: [dictId],
      orderBy: 'id',
    );
    final kanjiRows = await db.query(
      'kanji',
      where: 'dictionary_id = ?',
      whereArgs: [dictId],
    );
    final tagRows = await db.query(
      'tags',
      where: 'dictionary_id = ?',
      whereArgs: [dictId],
    );

    List<List<dynamic>> splitBanks(
      List<Map<String, Object?>> rows,
      List<dynamic> Function(Map<String, Object?> row) toEntry,
    ) {
      final banks = <List<dynamic>>[];
      var current = <dynamic>[];
      for (final row in rows) {
        current.add(toEntry(row));
        if (current.length >= 10000) {
          banks.add(current);
          current = <dynamic>[];
        }
      }
      if (current.isNotEmpty || banks.isEmpty) banks.add(current);
      return banks;
    }

    List<dynamic> decodeJsonColumn(Object? raw) {
      try {
        return jsonDecode(raw?.toString() ?? '[]') as List;
      } catch (_) {
        return [];
      }
    }

    final files = <String, String>{};
    files['index.json'] = jsonEncode({
      'title': title,
      'version': 1,
      'revision': 'export-\${DateTime.now().millisecondsSinceEpoch}',
    });

    // Yomichan term entry:
    // [term, reading, definitionTags, rules, score, glossary, sequence,
    //  termTags]
    final termBanks = splitBanks(termRows, (row) {
      final score = (row['popularity'] as num?)?.toDouble() ?? 0;
      return [
        row['term'] ?? '',
        row['reading'] ?? '',
        row['definition_tags'] ?? '',
        row['rules'] ?? '',
        score.round(),
        decodeJsonColumn(row['definitions']),
        (row['sequence'] as num?)?.toInt() ?? 0,
        row['term_tags'] ?? '',
      ];
    });
    for (var i = 0; i < termBanks.length; i++) {
      files['term_bank_\${i + 1}.json'] = jsonEncode(termBanks[i]);
    }

    if (kanjiRows.isNotEmpty) {
      final kanjiBanks = splitBanks(kanjiRows, (row) {
        return [
          row['character'] ?? '',
          row['onyomi'] ?? '',
          row['kunyomi'] ?? '',
          row['tags'] ?? '',
          decodeJsonColumn(row['meanings']),
        ];
      });
      for (var i = 0; i < kanjiBanks.length; i++) {
        files['kanji_bank_\${i + 1}.json'] = jsonEncode(kanjiBanks[i]);
      }
    }

    if (tagRows.isNotEmpty) {
      final tagBanks = splitBanks(tagRows, (row) {
        return [
          row['name'] ?? '',
          row['category'] ?? '',
          (row['sort_order'] as num?)?.toInt() ?? 0,
          row['notes'] ?? '',
          ((row['popularity'] as num?)?.toDouble() ?? 0).round(),
        ];
      });
      for (var i = 0; i < tagBanks.length; i++) {
        files['tag_bank_\${i + 1}.json'] = jsonEncode(tagBanks[i]);
      }
    }

    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile.string(e.key, e.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Play audio for text via the app audio service
  Future<void> playAudio(String text, String language) async {
    final audio = AudioService();
    await audio.init();
    await audio.play(text, language);
  }
}
