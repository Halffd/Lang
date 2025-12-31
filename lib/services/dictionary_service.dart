import 'dart:convert';
import 'dart:io';
import 'package:kana_kit/kana_kit.dart';
import 'package:pinyin/pinyin.dart';
import '../models/dictionary.dart' as model;
import '../models/tone_model.dart';
import '../models/etymology_model.dart';
import 'package:drift/drift.dart' as drift;
import 'database.dart'; // Import our database definition
import '../database/database_manager.dart';
import '../utils/chinese_util.dart';
import '../utils/ideographic_util.dart';
import 'wiktionary_etymology_service.dart';

// Import sqflite for Yomichan functionality
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kana_kit/kana_kit.dart';
import '../utils/japanese_grammar.dart';

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
      // Try exact match first with the existing database
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
    // Normalize the search term and get all possible forms
    final allForms = JapaneseGrammar.getAllPossibleForms(term);

    // If term contains kanji, also search for kana readings to address the kanji search issue
    List<String> searchTerms = [term];
    if (JapaneseGrammar.hasKanji(term)) {
      try {
        final kanaReading = JapaneseGrammar.kanaKit.toHiragana(term);
        if (kanaReading != term) {
          searchTerms.add(kanaReading);
        }
      } catch (e) {
        // If conversion fails, continue with original term
      }
    }
    // Add normalized verb forms
    searchTerms.addAll(allForms);
    // Remove duplicates
    searchTerms = searchTerms.toSet().toList();

    // Now perform the search with all possible forms
    List<YomichanSearchResult> yomichanResults = [];
    List<YomichanKanjiResult> kanjiResults = [];

    // Check if it's an ideographic particle search (single character that could be a radical/component)
    for (var searchTerm in searchTerms) {
      if (searchTerm.length == 1 && IdeographicUtil.containsIdeographic(searchTerm)) {
        // First try regular search
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        yomichanResults.addAll(results);
        kanjiResults.addAll(kanji);

        // If regular search yields few results, also try particle search
        if (yomichanResults.length < 5) {
          final particleResults = await searchByParticle(searchTerm);
          for (final result in particleResults) {
            if (!yomichanResults.any((r) => r.entry.id == result.entry.id)) {
              yomichanResults.add(result);
            }
          }
        }
      }
      // If it's a Chinese character search, search with multiple strategies
      else if (ChineseUtil.containsChinese(searchTerm)) {
        // Direct search for Chinese characters
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        yomichanResults.addAll(results);
        kanjiResults.addAll(kanji);

        // If no results and it looks like Pinyin, also search with Pinyin variations
        if (results.isEmpty && kanji.isEmpty) {
          final pinyinVariants = ChineseUtil.getAllSearchVariations(searchTerm);
          for (final variant in pinyinVariants) {
            if (variant != searchTerm) {
              final variantResults = await searchYomichan(variant);
              final variantKanjiResults = await searchKanji(variant);

              // Add unique results
              for (final result in variantResults) {
                if (!yomichanResults.any((r) => r.entry.id == result.entry.id)) {
                  yomichanResults.add(result);
                }
              }

              for (final result in variantKanjiResults) {
                if (!kanjiResults.any((r) => r.kanji.id == result.kanji.id)) {
                  kanjiResults.add(result);
                }
              }
            }
          }
        }
      }
      else if (ChineseUtil.looksLikeChinesePinyin(searchTerm) || _isLikelyPinyin(searchTerm)) {
      // First search directly
      final results = await searchYomichan(searchTerm);
      final kanji = await searchKanji(searchTerm);
      yomichanResults.addAll(results);
      kanjiResults.addAll(kanji);

      // Then search with variations
      final pinyinVariants = [
        ChineseUtil.toPinyinWithoutTone(searchTerm),
        ChineseUtil.toPinyinWithToneNumber(searchTerm),
        ChineseUtil.getPinyinInitials(searchTerm)
      ];

      for (final variant in pinyinVariants) {
        if (variant.isNotEmpty && variant != searchTerm) {
          final variantResults = await searchYomichan(variant);
          final variantKanjiResults = await searchKanji(variant);

          // Add unique results
          for (final result in variantResults) {
            if (!yomichanResults.any((r) => r.entry.id == result.entry.id)) {
              yomichanResults.add(result);
            }
          }

          for (final result in variantKanjiResults) {
            if (!kanjiResults.any((r) => r.kanji.id == result.kanji.id)) {
              kanjiResults.add(result);
            }
          }
        }
      }
    }
    // Default search for Japanese or other content
    else {
      final results = await searchYomichan(searchTerm);
      final kanji = await searchKanji(searchTerm);
      yomichanResults.addAll(results);
      kanjiResults.addAll(kanji);
    }
  } // End of for loop

  // Remove duplicates if needed
  yomichanResults = yomichanResults.toSet().toList();
  kanjiResults = kanjiResults.toSet().toList();

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

  /// Tokenize text by finding the longest matching dictionary entries
  Future<List<Token>> tokenizeText(String text) async {
    final db = await yomichanDatabase;
    final List<Token> tokens = [];
    int cursor = 0;

    // Split by lines first to preserve structure if needed, but here we process the whole text
    // We'll iterate through the text
    while (cursor < text.length) {
      bool matchFound = false;

      // For Chinese text, we need different tokenization strategy
      if (cursor < text.length && ChineseUtil.containsChinese(text[cursor])) {
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
      }
      else {
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