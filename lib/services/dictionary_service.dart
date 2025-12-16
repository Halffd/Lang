import 'dart:convert';
import 'dart:io';
import 'package:kana_kit/kana_kit.dart';
import '../models/dictionary.dart' as model;
import 'package:drift/drift.dart' as drift;
import 'database.dart'; // Import our database definition
import '../database/database_manager.dart';

// Import sqflite for Yomichan functionality
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SearchOptions {
  final int limit;
  final bool exactMatch;
  final bool searchReadings;
  final List<int>? dictionaryIds;

  const SearchOptions({
    this.limit = 20,
    this.exactMatch = false,
    this.searchReadings = true,
    this.dictionaryIds,
  });
}

class SearchResult {
  final List<model.DictionaryEntry> entries;
  final List<model.KanjiEntry> kanji;
  final Map<String, List<model.PitchAccent>> pitchAccents;
  final Map<String, List<model.FrequencyData>> frequencies;
  final Map<int, model.Dictionary> dictionaries;
  final Map<String, model.DictionaryTag> tags;

  SearchResult({
    required this.entries,
    required this.kanji,
    required this.pitchAccents,
    required this.frequencies,
    required this.dictionaries,
    required this.tags,
  });
}

class DictionaryService {
  static AppDatabase? _database;
  static Database? _yomichanDatabase;
  final KanaKit _kanaKit = KanaKit();

  static AppDatabase get database {
    _database ??= AppDatabase();
    return _database!;
  }

  Future<Database> get yomichanDatabase async {
    _yomichanDatabase ??= await DatabaseManager().database;
    return _yomichanDatabase!;
  }

  // Search with automatic kana conversion for existing dictionary entries
  Future<model.DictionarySearchResult> search(String query, {String language = 'ja'}) async {
    if (query.isEmpty) {
      return model.DictionarySearchResult(entries: [], query: query);
    }

    try {
      // Try exact match first with the existing database
      List<DriftDictionaryEntry> results = await database.searchBoth(query);

      // If auto-convert is enabled and query is romaji, also search hiragana
      if (_isRomaji(query)) {
        final hiragana = _kanaKit.toHiragana(query);
        final kanaResults = await database.searchBoth(hiragana);

        // Merge results, avoiding duplicates
        final seenTerms = <String>{};
        for (final result in results) {
          seenTerms.add(result.term);
        }

        for (final result in kanaResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }
      }

      // Convert from database models to DictionaryEntry model
      final entries = results.map<model.DictionaryEntry>((row) {
        return model.DictionaryEntry.fromJson({
          'id': row.id,
          'dictionaryId': 1,  // Default to dictionary ID 1 since we don't have that field in this table
          'term': row.term,
          'reading': row.reading ?? '',
          'definitionTags': [],
          'rules': [],
          'popularity': row.frequency.toDouble(),
          'definitions': row.definitions.split('||'),
          'sequence': row.id,
          'termTags': []
        });
      }).toList();

      return model.DictionarySearchResult(
        entries: entries,
        query: query,
        hasMore: results.length >= 50,
      );
    } catch (e) {
      print('Search error: $e');
      return model.DictionarySearchResult(
        entries: [],
        query: query,
        hasMore: false,
      );
    }
  }

  // Yomichan search methods
  /// Search Yomichan dictionaries
  Future<List<YomichanSearchResult>> searchYomichan(String query) async {
    final db = await yomichanDatabase;
    
    // Search entries
    final results = await db.query(
      'entries',
      where: 'term = ? OR reading = ?',
      whereArgs: [query, query],
      limit: 50,
    );

    final List<YomichanSearchResult> searchResults = [];

    for (final row in results) {
      final entry = model.DictionaryEntry.fromJson(row);
      
      // Get dictionary info
      final dictionaryResult = await db.query(
        'dictionaries',
        where: 'id = ?',
        whereArgs: [entry.dictionaryId],
        limit: 1,
      );
      
      final dictionary = dictionaryResult.isNotEmpty 
          ? model.Dictionary.fromMap(dictionaryResult.first)
          : null;

      // Get pitch accents
      final pitchResults = await db.query(
        'pitches',
        where: 'dictionary_id = ? AND term = ? AND reading = ?',
        whereArgs: [entry.dictionaryId, entry.term, entry.reading],
      );
      
      final pitches = pitchResults
          .map((p) => model.PitchAccent.fromMap(p))
          .toList();

      // Get frequencies
      final freqResults = await db.query(
        'frequencies',
        where: 'dictionary_id = ? AND term = ? AND reading = ?',
        whereArgs: [entry.dictionaryId, entry.term, entry.reading],
      );
      
      final frequencies = freqResults
          .map((f) => model.FrequencyData.fromMap(f))
          .toList();

      searchResults.add(YomichanSearchResult(
        entry: entry,
        dictionary: dictionary,
        pitches: pitches,
        frequencies: frequencies,
      ));
    }

    return searchResults;
  }

  /// Search kanji
  Future<List<YomichanKanjiResult>> searchKanji(String character) async {
    final db = await yomichanDatabase;
    
    final results = await db.query(
      'kanji',
      where: 'character = ?',
      whereArgs: [character],
    );

    final List<YomichanKanjiResult> searchResults = [];

    for (final row in results) {
      final kanji = model.KanjiEntry.fromMap(row);
      
      // Get dictionary info
      final dictionaryResult = await db.query(
        'dictionaries',
        where: 'id = ?',
        whereArgs: [kanji.dictionaryId],
        limit: 1,
      );
      
      final dictionary = dictionaryResult.isNotEmpty 
          ? model.Dictionary.fromMap(dictionaryResult.first)
          : null;

      searchResults.add(YomichanKanjiResult(
        kanji: kanji,
        dictionary: dictionary,
      ));
    }

    return searchResults;
  }

  /// Get all dictionaries
  Future<List<model.YomichanDictionary>> getYomichanDictionaries() async {
    final db = await yomichanDatabase;
    final results = await db.query('dictionaries', orderBy: 'priority DESC, id ASC');
    
    return results.map((row) => model.YomichanDictionary.fromMap(row)).toList();
  }

  /// Toggle dictionary enabled status
  Future<void> toggleYomichanDictionary(int id, bool enabled) async {
    final db = await yomichanDatabase;
    await db.update(
      'dictionaries',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete dictionary
  Future<void> deleteYomichanDictionary(int id) async {
    final db = await yomichanDatabase;
    await db.transaction((txn) async {
      // Delete all related data
      await txn.delete('entries', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('kanji', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('pitches', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('frequencies', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Get dictionary statistics
  Future<model.DictionaryStats> getDictionaryStats(int id) async {
    final db = await yomichanDatabase;
    
    final entriesCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM entries WHERE dictionary_id = ?',
      [id],
    )) ?? 0;
    
    final kanjiCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM kanji WHERE dictionary_id = ?',
      [id],
    )) ?? 0;
    
    return model.DictionaryStats(entries: entriesCount, kanji: kanjiCount);
  }

  // Compatibility methods for existing screens

  /// Get all dictionaries (for compatibility)
  Future<List<model.YomichanDictionary>> getAllDictionaries() async {
    return await getYomichanDictionaries();
  }

  /// Update dictionary (for compatibility)
  Future<void> updateDictionary(model.YomichanDictionary dictionary) async {
    final db = await yomichanDatabase;
    await db.update(
      'dictionaries',
      dictionary.toMap(),
      where: 'id = ?',
      whereArgs: [dictionary.id],
    );
  }

  /// Delete dictionary (for compatibility) 
  Future<void> deleteDictionary(int id) async {
    await deleteYomichanDictionary(id);
  }

  /// Search term (for compatibility)
  Future<SearchResult> searchTerm(String term, {SearchOptions options = const SearchOptions()}) async {
    // Search Yomichan entries
    final yomichanResults = await searchYomichan(term);
    
    // Search Kanji
    final kanjiResults = await searchKanji(term);

    // Convert to SearchResult format
    final entries = yomichanResults.map((r) => r.entry).toList();
    final kanji = kanjiResults.map((r) => r.kanji).toList();
    
    final pitchAccents = <String, List<model.PitchAccent>>{};
    final frequencies = <String, List<model.FrequencyData>>{};
    final dictionaries = <int, model.Dictionary>{};
    
    for (final result in yomichanResults) {
      final key = '${result.entry.term}_${result.entry.reading}';
      
      if (result.pitches.isNotEmpty) {
        pitchAccents[key] = result.pitches;
      }
      
      if (result.frequencies.isNotEmpty) {
        frequencies[key] = result.frequencies;
      }
      
      if (result.dictionary != null) {
        dictionaries[result.dictionary!.id] = result.dictionary!;
      }
    }

    for (final result in kanjiResults) {
       if (result.dictionary != null) {
        dictionaries[result.dictionary!.id] = result.dictionary!;
      }
    }

    return SearchResult(
      entries: entries,
      kanji: kanji,
      pitchAccents: pitchAccents,
      frequencies: frequencies,
      dictionaries: dictionaries,
      tags: {}, // Tags not implemented in searchYomichan yet
    );
  }

  /// Search dictionary (for compatibility)
  Future<List<model.DictionaryEntry>> searchDictionary(String query) async {
    final results = await searchYomichan(query);
    return results.map((r) => r.entry).toList();
  }

  // Helper methods
  bool _isRomaji(String text) {
    return !text.contains(RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]'));
  }
}

// Support classes
class ImportProgress {
  final String status;
  final double progress;

  ImportProgress({required this.status, required this.progress});
}

class YomichanSearchResult {
  final model.DictionaryEntry entry;
  final model.Dictionary? dictionary;
  final List<model.PitchAccent> pitches;
  final List<model.FrequencyData> frequencies;

  YomichanSearchResult({
    required this.entry,
    required this.dictionary,
    required this.pitches,
    required this.frequencies,
  });
}

class YomichanKanjiResult {
  final model.KanjiEntry kanji;
  final model.Dictionary? dictionary;

  YomichanKanjiResult({
    required this.kanji,
    required this.dictionary,
  });
}