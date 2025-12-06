import 'dart:convert';
import 'dart:io';
import 'package:kana_kit/kana_kit.dart';
import '../models/dictionary.dart' as model;
import 'package:drift/drift.dart' as drift;
import 'database.dart'; // Import our database definition

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

  Database get yomichanDatabase {
    _yomichanDatabase ??= _getYomichanDbInstance();
    return _yomichanDatabase!;
  }

  Database _getYomichanDbInstance() {
    throw UnimplementedError("Yomichan database creation not implemented yet");
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
    // For now, return empty results until full Yomichan implementation is complete
    return [];
  }

  /// Search kanji
  Future<List<YomichanKanjiResult>> searchKanji(String character) async {
    // For now, return empty results until full Yomichan implementation is complete
    return [];
  }

  /// Get all dictionaries
  Future<List<model.YomichanDictionary>> getYomichanDictionaries() async {
    // For now, return empty until we complete the Yomichan implementation
    return [];
  }

  /// Toggle dictionary enabled status
  Future<void> toggleYomichanDictionary(int id, bool enabled) async {
    // For now, do nothing until we complete the Yomichan implementation
  }

  /// Delete dictionary
  Future<void> deleteYomichanDictionary(int id) async {
    // For now, do nothing until we complete the Yomichan implementation
  }

  /// Get dictionary statistics
  Future<model.DictionaryStats> getDictionaryStats(int id) async {
    // For now, return zero stats until we complete the Yomichan implementation
    return model.DictionaryStats(entries: 0, kanji: 0);
  }

  // Compatibility methods for existing screens

  /// Get all dictionaries (for compatibility)
  Future<List<model.YomichanDictionary>> getAllDictionaries() async {
    return await getYomichanDictionaries();
  }

  /// Update dictionary (for compatibility)
  Future<void> updateDictionary(model.YomichanDictionary dictionary) async {
    // For now, do nothing until we complete the Yomichan implementation
  }

  /// Delete dictionary (for compatibility) 
  Future<void> deleteDictionary(int id) async {
    await deleteYomichanDictionary(id);
  }

  /// Search term (for compatibility)
  Future<SearchResult> searchTerm(String term, {SearchOptions options = const SearchOptions()}) async {
    final searchResult = await search(term);

    // Return a SearchResult with empty fields except for entries
    return SearchResult(
      entries: searchResult.entries,
      kanji: [],
      pitchAccents: {},
      frequencies: {},
      dictionaries: {},
      tags: {},
    );
  }

  /// Search dictionary (for compatibility)
  Future<List<model.DictionaryEntry>> searchDictionary(String query) async {
    final result = await search(query);
    return result.entries;
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
  final dynamic entry; // Placeholder - would be properly typed
  final dynamic dictionary; // Placeholder - would be properly typed
  final List<dynamic> pitches; // Placeholder - would be properly typed
  final List<dynamic> frequencies; // Placeholder - would be properly typed

  YomichanSearchResult({
    required this.entry,
    required this.dictionary,
    required this.pitches,
    required this.frequencies,
  });
}

class YomichanKanjiResult {
  final dynamic kanji; // Placeholder - would be properly typed
  final dynamic dictionary; // Placeholder - would be properly typed

  YomichanKanjiResult({
    required this.kanji,
    required this.dictionary,
  });
}