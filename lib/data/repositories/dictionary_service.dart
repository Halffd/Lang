import 'dart:convert';
import 'dart:io';
import 'package:kana_kit/kana_kit.dart';
import 'package:pinyin/pinyin.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../../domain/entities/tone_model.dart';
import '../../domain/entities/etymology_model.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/services/database.dart';
import '../../database/database_manager.dart';
import '../../utils/chinese_util.dart';
import '../../utils/ideographic_util.dart';
import '../datasources/remote/wiktionary_etymology_service.dart';
import '../datasources/remote/wiktionary_service.dart';
import '../datasources/remote/ichi_moe_service.dart';

// Import sqflite for Yomichan functionality
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kana_kit/kana_kit.dart';
import '../../utils/japanese_grammar.dart';

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
  final Map<String, List<ToneInfo>> toneInfo;
  final Map<String, List<model.FrequencyData>> frequencies;
  final Map<int, model.Dictionary> dictionaries;
  final Map<String, model.DictionaryTag> tags;
  final Map<String, List<EtymologyEntry>> etymology;
  final Map<String, List<WiktionaryEntry>> wiktionaryDetails;

  SearchResult({
    required this.entries,
    required this.kanji,
    required this.pitchAccents,
    required this.toneInfo,
    required this.frequencies,
    required this.dictionaries,
    required this.tags,
    this.etymology = const {},
    this.wiktionaryDetails = const {},
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
      // First detect the language of the query
      final detectedLanguage = _detectLanguage(query);

      // If it's European text, use Wiktionary primarily
      if (_isEuropeanText(query)) {
        return await _searchEuropeanText(query, detectedLanguage);
      }

      // For non-European text (Japanese, Chinese), use existing database search
      List<DriftDictionaryEntry> results = await database.searchBoth(query);

      // Handle Japanese kana conversion if needed
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

      // Handle Chinese Pinyin conversion if needed
      if (ChineseUtil.containsChinese(query)) {
        // Search for the original Chinese text
        final chineseResults = await database.searchHanzi(query);

        // Also try the original searchBoth for broader matches
        final otherResults = await database.searchBoth(query);

        // Add Chinese results if not already present
        final seenTerms = <String>{};
        for (final result in results) {
          seenTerms.add(result.term);
        }

        for (final result in chineseResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }

        // Add other results too
        for (final result in otherResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }
      } else if (ChineseUtil.looksLikeChinesePinyin(query) || _isLikelyPinyin(query)) {
        // If query looks like Pinyin, search for the corresponding Chinese characters
        // This would require a reverse Pinyin lookup which is complex,
        // so we'll do a more targeted approach later
        // For now, we'll just search the database for any pinyin-like entries
        final pinyinResults = await database.searchPinyin(query);
        final seenTerms = <String>{};
        for (final result in results) {
          seenTerms.add(result.term);
        }

        for (final result in pinyinResults) {
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

  /// Search European text using Wiktionary
  Future<model.DictionarySearchResult> _searchEuropeanText(String query, String language) async {
    try {
      // Search in Wiktionary for European languages
      final wiktionaryEntries = await fetchWiktionaryDetails(query, language: language);

      if (wiktionaryEntries.isNotEmpty) {
        // Convert Wiktionary entries to DictionaryEntry format
        final entries = wiktionaryEntries.map((wiktionaryEntry) {
          return model.DictionaryEntry.fromJson({
            'id': 0, // Placeholder ID
            'dictionaryId': 0, // Placeholder dictionary ID
            'term': query,
            'reading': '', // No reading for European languages
            'definitionTags': [], // No tags
            'rules': [], // No rules
            'popularity': 0.0, // No popularity yet
            'definitions': [wiktionaryEntry.definition], // Use Wiktionary definition
            'sequence': null, // No sequence
            'termTags': [] // No tags
          });
        }).toList();

        return model.DictionarySearchResult(
          entries: entries,
          query: query,
          hasMore: false,
        );
      } else {
        // If no Wiktionary results, try the existing database as fallback
        final fallbackResults = await database.searchBoth(query);
        final entries = fallbackResults.map<model.DictionaryEntry>((row) {
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
          hasMore: fallbackResults.length >= 50,
        );
      }
    } catch (e) {
      print('European language search error: $e');
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

    List<Map<String, Object?>> results = [];

    // Handle Chinese character search
    if (ChineseUtil.containsChinese(query)) {
      // Search for exact Chinese characters
      results = await db.query(
        'entries',
        where: 'term = ? OR reading = ?',
        whereArgs: [query, query],
        limit: 50,
      );
    }
    // Handle Pinyin search - search for Chinese entries that match the Pinyin
    else if (ChineseUtil.looksLikeChinesePinyin(query) || _isLikelyPinyin(query)) {
      // For now, search for Pinyin in reading field or similar fields
      // This would require the dictionary to have Pinyin annotations
      results = await db.query(
        'entries',
        where: 'reading LIKE ? OR term LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 50,
      );
    }
    // Handle regular Japanese search
    else {
      // Search entries with exact match first
      results = await db.query(
        'entries',
        where: 'term = ? OR reading = ?',
        whereArgs: [query, query],
        limit: 50,
      );
    }

    // If no exact matches found, try full-text search on definitions
    if (results.isEmpty) {
      try {
        // Use FTS5 for meaning/definition search
        final ftsResults = await db.rawQuery(
          'SELECT e.* FROM entries e JOIN entries_fts f ON e.id = f.rowid WHERE f.definitions MATCH ? LIMIT 50',
          [query],
        );
        if (ftsResults.isNotEmpty) {
          results = ftsResults;
        }
      } catch (e) {
        // FTS may not be available in some cases, fallback to LIKE search
        results = await db.query(
          'entries',
          where: 'definitions LIKE ?',
          whereArgs: ['%$query%'],
          limit: 50,
        );
      }
    }

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

      // Get tone information
      final toneResults = await db.query(
        'tones',
        where: 'dictionary_id = ? AND term = ? AND reading = ?',
        whereArgs: [entry.dictionaryId, entry.term, entry.reading],
      );

      final tones = toneResults
          .map((t) => ToneInfo.fromMap(t))
          .toList();

      searchResults.add(YomichanSearchResult(
        entry: entry,
        dictionary: dictionary,
        pitches: pitches,
        tones: tones,
        frequencies: frequencies,
      ));
    }

    return searchResults;
  }

  /// Search kanji/Chinese characters
  Future<List<YomichanKanjiResult>> searchKanji(String character) async {
    final db = await yomichanDatabase;

    List<Map<String, Object?>> results = [];

    // Handle Chinese character search
    if (ChineseUtil.containsChinese(character)) {
      // Search for Chinese characters in the kanji table
      results = await db.query(
        'kanji',
        where: 'character = ?',
        whereArgs: [character],
      );
    }
    // Handle regular Japanese Kanji search
    else {
      results = await db.query(
        'kanji',
        where: 'character = ?',
        whereArgs: [character],
      );
    }

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

      // For Chinese characters, also get tone information
      List<ToneInfo> tones = [];
      if (ChineseUtil.containsChinese(kanji.character)) {
        final toneResults = await db.query(
          'tones',
          where: 'term = ?',
          whereArgs: [kanji.character],
        );
        tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();
      }

      searchResults.add(YomichanKanjiResult(
        kanji: kanji,
        dictionary: dictionary,
        tones: tones,
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
    // Build a prioritized list of search terms with exact matches first
    final Map<String, int> searchTermsWithPriority = {};
    
    // Highest priority: exact term
    searchTermsWithPriority[term] = 0;
    
    // High priority: normalized forms
    final allForms = JapaneseGrammar.getAllPossibleForms(term);
    for (int i = 0; i < allForms.length; i++) {
      if (allForms[i] != term && !searchTermsWithPriority.containsKey(allForms[i])) {
        searchTermsWithPriority[allForms[i]] = i + 1;
      }
    }
    
    // Add kana conversion if available
    if (JapaneseGrammar.hasKanji(term)) {
      try {
        final kanaReading = JapaneseGrammar.kanaKit.toHiragana(term);
        if (kanaReading != term && !searchTermsWithPriority.containsKey(kanaReading)) {
          searchTermsWithPriority[kanaReading] = 1000;
        }
      } catch (e) {
        // If conversion fails, continue with original term
      }
    }

    // Now perform the search with prioritized forms
    List<YomichanSearchResult> yomichanResults = [];
    List<YomichanKanjiResult> kanjiResults = [];
    final Set<String> seenEntryIds = {};
    final Set<String> seenKanjiIds = {};

    // Search in order of priority
    final sortedTerms = searchTermsWithPriority.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    
    for (var entry in sortedTerms) {
      final searchTerm = entry.key;
      
      if (searchTerm.length == 1 && IdeographicUtil.containsIdeographic(searchTerm)) {
        // Single character - try regular search first
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        
        // Add only new results
        for (final result in results) {
          if (!seenEntryIds.contains('${result.entry.dictionaryId}_${result.entry.id}')) {
            yomichanResults.add(result);
            seenEntryIds.add('${result.entry.dictionaryId}_${result.entry.id}');
          }
        }
        for (final result in kanji) {
          if (!seenKanjiIds.contains('${result.kanji.dictionaryId}_${result.kanji.id}')) {
            kanjiResults.add(result);
            seenKanjiIds.add('${result.kanji.dictionaryId}_${result.kanji.id}');
          }
        }

        // If regular search yields results, try particle search only if we have few
        if (yomichanResults.length < 5) {
          final particleResults = await searchByParticle(searchTerm);
          for (final result in particleResults) {
            if (!seenEntryIds.contains('${result.entry.dictionaryId}_${result.entry.id}')) {
              yomichanResults.add(result);
              seenEntryIds.add('${result.entry.dictionaryId}_${result.entry.id}');
            }
          }
        }
      } else if (ChineseUtil.containsChinese(searchTerm)) {
        // Chinese character search
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        
        for (final result in results) {
          if (!seenEntryIds.contains('${result.entry.dictionaryId}_${result.entry.id}')) {
            yomichanResults.add(result);
            seenEntryIds.add('${result.entry.dictionaryId}_${result.entry.id}');
          }
        }
        for (final result in kanji) {
          if (!seenKanjiIds.contains('${result.kanji.dictionaryId}_${result.kanji.id}')) {
            kanjiResults.add(result);
            seenKanjiIds.add('${result.kanji.dictionaryId}_${result.kanji.id}');
          }
        }
      } else {
        // Regular Japanese or other search
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        
        for (final result in results) {
          if (!seenEntryIds.contains('${result.entry.dictionaryId}_${result.entry.id}')) {
            yomichanResults.add(result);
            seenEntryIds.add('${result.entry.dictionaryId}_${result.entry.id}');
          }
        }
        for (final result in kanji) {
          if (!seenKanjiIds.contains('${result.kanji.dictionaryId}_${result.kanji.id}')) {
            kanjiResults.add(result);
            seenKanjiIds.add('${result.kanji.dictionaryId}_${result.kanji.id}');
          }
        }
      }
      
      // If we have good results from the primary term, stop searching
      if (yomichanResults.isNotEmpty || kanjiResults.isNotEmpty) {
        break;
      }
    }

    // Remove any remaining duplicates (shouldn't happen but just in case)
    final uniqueYomichan = <YomichanSearchResult>[];
    final uniqueKanji = <YomichanKanjiResult>[];
    final seenY = <String>{};
    final seenK = <String>{};
    
    for (final result in yomichanResults) {
      final key = '${result.entry.dictionaryId}_${result.entry.id}';
      if (!seenY.contains(key)) {
        uniqueYomichan.add(result);
        seenY.add(key);
      }
    }
    
    for (final result in kanjiResults) {
      final key = '${result.kanji.dictionaryId}_${result.kanji.id}';
      if (!seenK.contains(key)) {
        uniqueKanji.add(result);
        seenK.add(key);
      }
    }
    
    yomichanResults = uniqueYomichan;
    kanjiResults = uniqueKanji;

  // Convert to SearchResult format
  final entries = yomichanResults.map((r) => r.entry).toList();
    final kanji = kanjiResults.map((r) => r.kanji).toList();

    final pitchAccents = <String, List<model.PitchAccent>>{};
    final toneInfo = <String, List<ToneInfo>>{};
    final frequencies = <String, List<model.FrequencyData>>{};
    final dictionaries = <int, model.Dictionary>{};

    for (final result in yomichanResults) {
      final key = '${result.entry.term}_${result.entry.reading}';

      if (result.pitches.isNotEmpty) {
        pitchAccents[key] = result.pitches;
      }

      if (result.tones.isNotEmpty) {
        toneInfo[key] = result.tones;
      }

      if (result.frequencies.isNotEmpty) {
        frequencies[key] = result.frequencies;
      }

      if (result.dictionary != null && result.dictionary!.id != null) {
        dictionaries[result.dictionary!.id!] = result.dictionary!;
      }
    }

    for (final result in kanjiResults) {
       if (result.dictionary != null && result.dictionary!.id != null) {
        dictionaries[result.dictionary!.id!] = result.dictionary!;
      }
    }

    // Fetch Wiktionary details for all entries
    final wiktionaryDetails = <String, List<WiktionaryEntry>>{};
    for (final entry in entries) {
      final key = '${entry.term}_${entry.reading}';
      final details = await fetchWiktionaryDetails(entry.term);
      if (details.isNotEmpty) {
        wiktionaryDetails[key] = details;
      }
    }

    return SearchResult(
      entries: entries,
      kanji: kanji,
      pitchAccents: pitchAccents,
      toneInfo: toneInfo,
      frequencies: frequencies,
      dictionaries: dictionaries,
      tags: {}, // Tags not implemented in searchYomichan yet
      etymology: {}, // Placeholder for etymology - to be populated later
      wiktionaryDetails: wiktionaryDetails,
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

  /// Check if the text looks like pinyin (for Chinese)
  bool _isLikelyPinyin(String text) {
    // Check if the text contains only Latin letters and spaces, which is typical for Pinyin
    final cleanText = text.trim().toLowerCase();
    return RegExp(r'^[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ\s]+$').hasMatch(cleanText) &&
           cleanText.isNotEmpty &&
           !ChineseUtil.containsChinese(text) &&
           !ChineseUtil.containsJapaneseKanji(text);
  }

  /// Search for entries containing specific ideographic particles/components
  Future<List<YomichanSearchResult>> searchByParticle(String particle) async {
    final db = await yomichanDatabase;

    // Get all terms from the database
    final allTermsResult = await db.query('entries', columns: ['term']);
    final terms = allTermsResult.map((row) => row['term'] as String).toSet().toList();

    // Find terms that contain the particle
    final matchingTerms = <String>[];
    for (final term in terms) {
      if (IdeographicUtil.containsIdeographic(term)) {
        final components = IdeographicUtil.getComponents(term);
        if (components.contains(particle) || term.contains(particle)) {
          matchingTerms.add(term);
        }
      }
    }

    // Query for all matching terms
    if (matchingTerms.isNotEmpty) {
      final placeholders = List.filled(matchingTerms.length, '?').join(',');
      final results = await db.query(
        'entries',
        where: 'term IN ($placeholders)',
        whereArgs: matchingTerms,
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

        // Get tone information
        final toneResults = await db.query(
          'tones',
          where: 'dictionary_id = ? AND term = ? AND reading = ?',
          whereArgs: [entry.dictionaryId, entry.term, entry.reading],
        );

        final tones = toneResults
            .map((t) => ToneInfo.fromMap(t))
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
          tones: tones,
          frequencies: frequencies,
        ));
      }

      return searchResults;
    }

    return [];
  }

  /// Search for tone information by term
  Future<List<ToneInfo>> searchTones(String term, {String? language}) async {
    final db = await yomichanDatabase;

    List<Map<String, Object?>> results;

    if (language != null) {
      results = await db.query(
        'tones',
        where: 'term = ? AND language = ?',
        whereArgs: [term, language],
        limit: 50,
      );
    } else {
      results = await db.query(
        'tones',
        where: 'term = ?',
        whereArgs: [term],
        limit: 50,
      );
    }

    return results.map((row) => ToneInfo.fromMap(row)).toList();
  }

  /// Fetch etymology information for a word
  Future<List<EtymologyEntry>> fetchEtymology(String word, {String language = 'en'}) async {
    try {
      final service = WiktionaryEtymologyService();
      final result = await service.fetchEtymologyDetailed(word, language);
      return result.sections.map((section) => EtymologyEntry(
        sectionTitle: section.title,
        originalLanguage: section.originalLanguage,
        content: section.content,
      )).toList();
    } catch (e) {
      print('Error fetching etymology for $word: $e');
      return [];
    }
  }

  /// Fetch detailed Wiktionary information including meanings and examples
  Future<List<WiktionaryEntry>> fetchWiktionaryDetails(String word, {String language = 'en'}) async {
    try {
      final service = WiktionaryEtymologyService();
      return await service.fetchWordDetails(word, language);
    } catch (e) {
      print('Error fetching Wiktionary details for $word: $e');
      return [];
    }
  }

  /// Detect the language/script of input text
  String _detectLanguage(String text) {
    // Check for specific character ranges to determine the language/script
    if (ChineseUtil.containsChinese(text)) {
      return 'zh';  // Chinese
    } else if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) {
      // Contains hiragana or katakana
      return 'ja';  // Japanese
    } else if (RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text)) {
      // Contains Arabic script
      return 'ar';  // Arabic
    } else if (RegExp(r'[\u0590-\u05FF]').hasMatch(text)) {
      // Contains Hebrew script
      return 'he';  // Hebrew
    } else if (RegExp(r'[\u0400-\u04FF\u0500-\u052F]').hasMatch(text)) {
      // Contains Cyrillic script (Russian, etc.)
      return 'ru';  // Russian as example
    } else if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) {
      // Contains Korean Hangul
      return 'ko';  // Korean
    } else if (RegExp(r'[\u1780-\u17FF\u19E0-\u19FF]').hasMatch(text)) {
      // Contains Khmer script
      return 'km';  // Khmer
    } else if (RegExp(r'[\u0900-\u097F\u1CD0-\u1CFF]').hasMatch(text)) {
      // Contains Devanagari script (Hindi, etc.)
      return 'hi';  // Hindi
    } else if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) {
      // Contains Sinhala script
      return 'si';  // Sinhala
    } else if (RegExp(r'[\u1000-\u109F]').hasMatch(text)) {
      // Contains Myanmar script
      return 'my';  // Myanmar
    } else {
      // It's likely a Latin-based script (European languages, English, etc.)
      // We'll return 'en' as a default for Latin scripts
      return 'en';
    }
  }

  /// Check if the text is primarily European (Latin-based script)
  bool _isEuropeanText(String text) {
    // Check if the text contains mainly Latin characters (European languages, English, etc.)
    // Count the ratio of Latin characters to other characters
    int latinCount = 0;
    int otherCount = 0;

    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if ((codeUnit >= 65 && codeUnit <= 122) || // A-Z, a-z
          (codeUnit >= 48 && codeUnit <= 57) || // 0-9
          codeUnit == 32 || // space
          (codeUnit >= 192 && codeUnit <= 687)) { // Extended Latin characters used in European languages
        latinCount++;
      } else {
        otherCount++;
      }
    }

    // If more than 50% are Latin characters, consider it European text
    return latinCount > 0 && otherCount < latinCount;
  }

  /// Tokenize text by finding the longest matching dictionary entries or using Wiktionary for European languages
  Future<List<Token>> tokenizeText(String text) async {
    // If it's European text (or any Latin-based script), use Wiktionary as primary source
    if (_isEuropeanText(text)) {
      return await _tokenizeEuropeanText(text);
    } else if (ChineseUtil.containsChinese(text)) {
      return await _tokenizeChineseText(text);
    } else {
      // For Japanese or other supported scripts, use existing approach
      return await _tokenizeJapaneseText(text);
    }
  }

  /// Tokenize European text - split by spaces and punctuation, then look up in Wiktionary
  Future<List<Token>> _tokenizeEuropeanText(String text) async {
    final List<Token> tokens = [];

    // Split by words while preserving spaces and punctuation
    final words = text.split(RegExp(r'(\s+|[^\w\s]+)')); // Split by word boundaries

    for (final word in words) {
      if (word.trim().isNotEmpty) {
        if (_isWordLike(word)) {
          // Look up the word in Wiktionary
          final wiktionaryEntries = await fetchWiktionaryDetails(word, language: _detectLanguage(word));

          if (wiktionaryEntries.isNotEmpty) {
            // Convert Wiktionary entry to DictionaryEntry format
            final entry = _convertWiktionaryToDictionaryEntry(wiktionaryEntries.first, word);
            tokens.add(Token(
              text: word,
              entry: entry,
              isWord: true,
            ));
          } else {
            // If no Wiktionary entry, add as non-word token
            tokens.add(Token(
              text: word,
              isWord: false,
            ));
          }
        } else {
          // Add punctuation/spaces as non-word tokens
          tokens.add(Token(
            text: word,
            isWord: false,
          ));
        }
      }
    }

    return tokens;
  }

  /// Check if text looks like a word (not just punctuation or spaces)
  bool _isWordLike(String text) {
    // Check if text contains at least one alphabetic character
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  /// Convert Wiktionary entry to DictionaryEntry format
  model.DictionaryEntry _convertWiktionaryToDictionaryEntry(WiktionaryEntry wiktionaryEntry, String term) {
    // Create a DictionaryEntry from Wiktionary data
    return model.DictionaryEntry(
      id: 0, // We need to ensure proper ID handling
      dictionaryId: 0, // Placeholder value
      term: term,
      reading: '', // No reading for European languages
      definitionTags: [], // No tags in this simple conversion
      rules: [], // No rules
      popularity: 0.0, // No popularity for Wiktionary entries
      definitions: [wiktionaryEntry.definition], // Use the main definition
      sequence: null, // No sequence
      termTags: [], // No term tags
    );
  }

  /// Tokenize Chinese text
  Future<List<Token>> _tokenizeChineseText(String text) async {
    final db = await yomichanDatabase;
    final List<Token> tokens = [];
    int cursor = 0;

    while (cursor < text.length) {
      bool matchFound = false;

      // Try to match Chinese characters in various lengths
      int maxLength = 3; // Chinese words are typically 1-3 characters
      if (cursor + maxLength > text.length) {
        maxLength = text.length - cursor;
      }

      final candidates = <String>[];
      for (int i = maxLength; i >= 1; i--) {
        candidates.add(text.substring(cursor, cursor + i));
      }

      if (candidates.isNotEmpty) {
        final placeholders = List.filled(candidates.length, '?').join(',');
        final results = await db.query(
          'entries',
          where: 'term IN ($placeholders)',
          whereArgs: candidates,
          orderBy: 'length(term) DESC', // Prioritize longer matches
          limit: 1, // Get the longest one
        );

        if (results.isNotEmpty) {
          final row = results.first;
          final entry = model.DictionaryEntry.fromJson(row);
          tokens.add(Token(
            text: entry.term,
            entry: entry,
            isWord: true,
          ));
          cursor += entry.term.length;
          matchFound = true;
        }
      }

      if (!matchFound) {
        // No dictionary match, consume one character
        tokens.add(Token(
          text: text[cursor],
          isWord: false,
        ));
        cursor++;
      }
    }

    return tokens;
  }

  /// Tokenize Japanese text
  Future<List<Token>> _tokenizeJapaneseText(String text) async {
    final db = await yomichanDatabase;
    final List<Token> tokens = [];
    int cursor = 0;

    while (cursor < text.length) {
      bool matchFound = false;

      // Try to match longest possible word (up to 10 chars) for Japanese
      int maxLength = 10;
      if (cursor + maxLength > text.length) {
        maxLength = text.length - cursor;
      }

      final candidates = <String>[];
      for (int i = maxLength; i >= 1; i--) {
        candidates.add(text.substring(cursor, cursor + i));
      }

      // Batch query for all candidates
      // We prioritize longer matches by checking them in order or sorting results
      if (candidates.isNotEmpty) {
        final placeholders = List.filled(candidates.length, '?').join(',');
        final results = await db.query(
          'entries',
          where: 'term IN ($placeholders)',
          whereArgs: candidates,
          orderBy: 'length(term) DESC', // Prioritize longer matches
          limit: 1, // Get the longest one
        );

        if (results.isNotEmpty) {
          final row = results.first;
          final entry = model.DictionaryEntry.fromJson(row);
          tokens.add(Token(
            text: entry.term,
            entry: entry,
            isWord: true,
          ));
          cursor += entry.term.length;
          matchFound = true;
        }
      }

      if (!matchFound) {
        // No dictionary match, consume one character
        tokens.add(Token(
          text: text[cursor],
          isWord: false,
        ));
        cursor++;
      }
    }

    return tokens;
  }

  /// Fetch detailed information from Wiktionary using the new WiktionaryService
  /// This method implements the JavaScript-originated function logic in Dart
  Future<List<String>> fetchWiktionaryDetailed(String word, [bool isChinese = false]) async {
    try {
      final service = WiktionaryService();
      final result = await service.fetchDetailedWordInformation(word, isChinese);

      // result is a List<List<String>> where:
      // result[0] = japaneseContent
      // result[1] = originContent
      // result[2] = alternativeContent
      // result[3] = allContent
      // result[4] = otherContent

      if (result.length >= 5) {
        // Combine relevant content from various sections
        final combinedContent = <String>[];
        combinedContent.addAll(result[0]);  // japaneseContent
        combinedContent.addAll(result[1]);  // originContent
        combinedContent.addAll(result[2]);  // alternativeContent
        combinedContent.addAll(result[3]);  // allContent
        combinedContent.addAll(result[4]);  // otherContent

        return combinedContent;
      }

      return [];
    } catch (e) {
      print('Error fetching detailed Wiktionary data: $e');
      return [];
    }
  }

  /// Enhanced method to fetch detailed word information for any language
  /// This integrates with the new WiktionaryService to support multi-language word lookup
  Future<List<String>> fetchWordDetailsMultiLanguage(String word, String detectedLanguage) async {
    try {
      final service = WiktionaryService();
      return await service.fetchWordDetailsForAnyLanguage(word, detectedLanguage);
    } catch (e) {
      print('Error fetching multi-language word details: $e');
      return [];
    }
  }

  /// Fetch data from ichi.moe for Japanese terms
  /// This method implements the JavaScript-originated function logic in Dart
  Future<List<model.DictionaryEntry>> searchIchiMoe(String term, {bool useRomaji = true}) async {
    try {
      final service = IchiMoeService();
      return await service.searchWithDetails(term, useRomaji: useRomaji);
    } catch (e) {
      print('Error fetching ichi.moe data: $e');
      return [];
    }
  }
}

class Token {
  final String text;
  final model.DictionaryEntry? entry;
  final bool isWord;
  
  Token({
    required this.text,
    this.entry,
    this.isWord = false,
  });
}

class ImportProgress {
  final String status;
  final double progress;

  ImportProgress({required this.status, required this.progress});
}

class YomichanSearchResult {
  final model.DictionaryEntry entry;
  final model.Dictionary? dictionary;
  final List<model.PitchAccent> pitches;
  final List<ToneInfo> tones;
  final List<model.FrequencyData> frequencies;

  YomichanSearchResult({
    required this.entry,
    required this.dictionary,
    required this.pitches,
    required this.tones,
    required this.frequencies,
  });
}

class YomichanKanjiResult {
  final model.KanjiEntry kanji;
  final model.Dictionary? dictionary;
  final List<ToneInfo> tones;

  YomichanKanjiResult({
    required this.kanji,
    required this.dictionary,
    this.tones = const [],
  });
}