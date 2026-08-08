import 'dart:async';
import 'package:sqflite/sqflite.dart';
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
import 'remote_dictionary_service.dart';

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
  final Map<String, List<model.WiktionaryEntry>> wiktionaryDetails;

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
  final RemoteDictionaryService _remoteService = RemoteDictionaryService();
  final KanaKit _kanaKit = KanaKit();

  static AppDatabase get database {
    _database ??= AppDatabase();
    return _database!;
  }

  Future<Database> get yomichanDatabase async {
    _yomichanDatabase ??= await DatabaseManager().database;
    return _yomichanDatabase!;
  }

  // Main search method
  Future<model.DictionarySearchResult> search(String query, {String language = 'ja'}) async {
    if (query.isEmpty) {
      return model.DictionarySearchResult(entries: [], query: query);
    }

    try {
      // Detect language of the query
      final detectedLanguage = _remoteService.detectLanguage(query);

      // If it's European text, use Wiktionary primarily
      if (_remoteService.isEuropeanText(query)) {
        return await _remoteService.searchEuropeanWord(query, language: language);
      }

      // For non-European text (Japanese, Chinese), use existing database search
      List<DriftDictionaryEntry> results = await database.searchBoth(query);

      // Handle Japanese kana conversion if needed
      if (_remoteService.isRomaji(query)) {
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

      // Handle Chinese text
      if (ChineseUtil.containsChinese(query)) {
        final chineseResults = await database.searchHanzi(query);
        final otherResults = await database.searchBoth(query);

        final seenTerms = <String>{};
        for (final result in results) seenTerms.add(result.term);

        for (final result in chineseResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }

        for (final result in otherResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }
      } else if (ChineseUtil.looksLikeChinesePinyin(query) || _isLikelyPinyin(query)) {
        final pinyinResults = await database.searchPinyin(query);
        final seenTerms = <String>{};
        for (final result in results) seenTerms.add(result.term);

        for (final result in pinyinResults) {
          if (!seenTerms.contains(result.term)) {
            results.add(result);
            seenTerms.add(result.term);
          }
        }
      }

      // Convert to DictionaryEntry models
      final entries = results.map<model.DictionaryEntry>((row) {
        return model.DictionaryEntry.fromJson({
          'id': row.id,
          'dictionaryId': 1,
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
      return model.DictionarySearchResult(entries: [], query: query, hasMore: false);
    }
  }

  // Delegate to remote service for European text
  Future<model.DictionarySearchResult> _searchEuropeanText(String query, String language) async {
    return await _remoteService.searchEuropeanWord(query, language: language);
  }

  // Yomichan search methods
  Future<List<YomichanSearchResult>> searchYomichan(String query) async {
    final db = await _yomichanDatabase;
    List<Map<String, Object?>> results = [];

    if (ChineseUtil.containsChinese(query)) {
      results = await _yomichanDatabase!.query(
        'entries',
        where: 'term = ? OR reading = ?',
        whereArgs: [query, query],
        limit: 50,
      );
    } else if (ChineseUtil.looksLikeChinesePinyin(query) || _isLikelyPinyin(query)) {
      results = await _yomichanDatabase!.query(
        'entries',
        where: 'reading LIKE ? OR term LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 50,
      );
    } else {
      results = await _yomichanDatabase!.query(
        'entries',
        where: 'term = ? OR reading = ?',
        whereArgs: [query, query],
        limit: 50,
      );
    }

    if (results.isEmpty) {
      try {
        final ftsResults = await _yomichanDatabase!.rawQuery(
          'SELECT e.* FROM entries e JOIN entries_fts f ON e.id = f.rowid WHERE f.definitions MATCH ? LIMIT 50',
          [query],
        );
        if (ftsResults.isNotEmpty) results = ftsResults;
      } catch (e) {
        results = await _yomichanDatabase!.query(
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
      final dictionaryResult = await _yomichanDatabase!.query(
        'dictionaries', where: 'id = ?', whereArgs: [entry.dictionaryId], limit: 1,
      );
      final dictionary = dictionaryResult.isNotEmpty ? model.Dictionary.fromMap(dictionaryResult.first) : null;

      final pitchResults = await _yomichanDatabase!.query('pitches', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final pitches = pitchResults.map((p) => model.PitchAccent.fromMap(p)).toList();

      final toneResults = await _yomichanDatabase!.query('tones', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();

      final freqResults = await _yomichanDatabase!.query('frequencies', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final frequencies = freqResults.map((f) => model.FrequencyData.fromMap(f)).toList();

      searchResults.add(YomichanSearchResult(entry: entry, dictionary: dictionary, pitches: pitches, tones: tones, frequencies: frequencies));
    }
    return searchResults;
  }

  Future<List<YomichanKanjiResult>> searchKanji(String character) async {
    final db = await _yomichanDatabase;
    List<Map<String, Object?>> results = [];

    if (ChineseUtil.containsChinese(character)) {
      results = await _yomichanDatabase!.query('kanji', where: 'character = ?', whereArgs: [character]);
    } else {
      results = await _yomichanDatabase!.query('kanji', where: 'character = ?', whereArgs: [character]);
    }

    final List<YomichanKanjiResult> searchResults = [];
    for (final row in results) {
      final kanji = model.KanjiEntry.fromMap(row);
      final dictionaryResult = await _yomichanDatabase!.query('dictionaries', where: 'id = ?', whereArgs: [kanji.dictionaryId], limit: 1);
      final dictionary = dictionaryResult.isNotEmpty ? model.Dictionary.fromMap(dictionaryResult.first) : null;

      List<ToneInfo> tones = [];
      if (ChineseUtil.containsChinese(kanji.character)) {
        final toneResults = await _yomichanDatabase!.query('tones', where: 'term = ?', whereArgs: [kanji.character]);
        tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();
      }

      searchResults.add(YomichanKanjiResult(kanji: kanji, dictionary: dictionary, tones: tones));
    }
    return searchResults;
  }

  Future<List<model.YomichanDictionary>> getYomichanDictionaries() async {
    final db = await _yomichanDatabase;
    final results = await db.query('dictionaries', orderBy: 'priority DESC, id ASC');
    return results.map((row) => model.YomichanDictionary.fromMap(row)).toList();
  }

  Future<void> toggleYomichanDictionary(int id, bool enabled) async {
    final db = await _yomichanDatabase;
    await db.update('dictionaries', {'enabled': enabled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteYomichanDictionary(int id) async {
    final db = await _yomichanDatabase;
    await db.transaction((txn) async {
      await txn.delete('entries', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('kanji', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('pitches', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('frequencies', where: 'dictionary_id = ?', whereArgs: [id]);
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<model.DictionaryStats> getDictionaryStats(int id) async {
    final db = await _yomichanDatabase;
    final entriesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM entries WHERE dictionary_id = ?', [id])) ?? 0;
    final kanjiCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM kanji WHERE dictionary_id = ?', [id])) ?? 0;
    return model.DictionaryStats(entries: entriesCount, kanji: kanjiCount);
  }

  // Compatibility methods
  Future<List<model.YomichanDictionary>> getAllDictionaries() async => getYomichanDictionaries();
  Future<void> updateDictionary(model.YomichanDictionary dictionary) async {
    final db = await _yomichanDatabase;
    await db.update('dictionaries', dictionary.toMap(), where: 'id = ?', whereArgs: [dictionary.id]);
  }
  Future<void> deleteDictionary(int id) async => deleteYomichanDictionary(id);

  Future<SearchResult> searchTerm(String term, {SearchOptions options = const SearchOptions()}) async {
    final Map<String, int> searchTermsWithPriority = {term: 0};
    final allForms = JapaneseGrammar.getAllPossibleForms(term);
    for (int i = 0; i < allForms.length; i++) {
      if (allForms[i] != term && !searchTermsWithPriority.containsKey(allForms[i])) {
        searchTermsWithPriority[allForms[i]] = i + 1;
      }
    }
    if (JapaneseGrammar.hasKanji(term)) {
      try {
        final kanaReading = JapaneseGrammar.kanaKit.toHiragana(term);
        if (kanaReading != term && !searchTermsWithPriority.containsKey(kanaReading)) {
          searchTermsWithPriority[kanaReading] = 1000;
        }
      } catch (e) {}
    }

    List<YomichanSearchResult> yomichanResults = [];
    List<YomichanKanjiResult> kanjiResults = [];
    final Set<String> seenEntryIds = {};
    final Set<String> seenKanjiIds = {};

    final sortedTerms = searchTermsWithPriority.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    for (var entry in sortedTerms) {
      final searchTerm = entry.key;
      if (searchTerm.length == 1 && IdeographicUtil.containsIdeographic(searchTerm)) {
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        _addUniqueResults(results, kanji, seenEntryIds, seenKanjiIds, yomichanResults, kanjiResults);
        if (yomichanResults.length < 5) {
          final particleResults = await searchByParticle(searchTerm);
          _addUniqueResults(particleResults, [], seenEntryIds, seenKanjiIds, yomichanResults, kanjiResults);
        }
      } else if (ChineseUtil.containsChinese(searchTerm)) {
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        _addUniqueResults(results, kanji, seenEntryIds, seenKanjiIds, yomichanResults, kanjiResults);
      } else {
        final results = await searchYomichan(searchTerm);
        final kanji = await searchKanji(searchTerm);
        _addUniqueResults(results, kanji, seenEntryIds, seenKanjiIds, yomichanResults, kanjiResults);
      }
      if (yomichanResults.isNotEmpty || kanjiResults.isNotEmpty) break;
    }

    final entries = yomichanResults.map((r) => r.entry).toList();
    final kanji = kanjiResults.map((r) => r.kanji).toList();
    final pitchAccents = <String, List<model.PitchAccent>>{};
    final toneInfo = <String, List<ToneInfo>>{};
    final frequencies = <String, List<model.FrequencyData>>{};
    final dictionaries = <int, model.Dictionary>{};

    for (final result in yomichanResults) {
      final key = '${result.entry.term}_${result.entry.reading}';
      if (result.pitches.isNotEmpty) pitchAccents[key] = result.pitches;
      if (result.tones.isNotEmpty) toneInfo[key] = result.tones;
      if (result.frequencies.isNotEmpty) frequencies[key] = result.frequencies;
      if (result.dictionary != null && result.dictionary!.id != null) dictionaries[result.dictionary!.id!] = result.dictionary!;
    }
    for (final result in kanjiResults) {
      if (result.dictionary != null && result.dictionary!.id != null) dictionaries[result.dictionary!.id!] = result.dictionary!;
    }

    final wiktionaryDetails = <String, List<model.WiktionaryEntry>>{};
    for (final entry in entries) {
      final key = '${entry.term}_${entry.reading}';
      final details = await fetchWiktionaryDetails(entry.term);
      if (details.isNotEmpty) wiktionaryDetails[key] = details;
    }

    return SearchResult(
      entries: entries, kanji: kanji, pitchAccents: pitchAccents, toneInfo: toneInfo,
      frequencies: frequencies, dictionaries: dictionaries, tags: {}, etymology: {},
      wiktionaryDetails: wiktionaryDetails,
    );
  }

  void _addUniqueResults(
    List<YomichanSearchResult> results,
    List<YomichanKanjiResult> kanji,
    Set<String> seenEntryIds,
    Set<String> seenKanjiIds,
    List<YomichanSearchResult> yomichanResults,
    List<YomichanKanjiResult> kanjiResults,
  ) {
    for (final result in results) {
      final key = '${result.entry.dictionaryId}_${result.entry.id}';
      if (!seenEntryIds.contains(key)) {
        yomichanResults.add(result);
        seenEntryIds.add(key);
      }
    }
    for (final result in kanji) {
      final key = '${result.kanji.dictionaryId}_${result.kanji.id}';
      if (!seenKanjiIds.contains(key)) {
        kanjiResults.add(result);
        seenKanjiIds.add(key);
      }
    }
  }

  Future<List<model.DictionaryEntry>> searchDictionary(String query) async {
    final results = await searchYomichan(query);
    return results.map((r) => r.entry).toList();
  }

  Future<SearchResult> _searchChineseCharacter(String character) async {
    final results = await searchYomichan(character);
    final kanji = await searchKanji(character);
    return SearchResult(
      entries: results.map((r) => r.entry).toList(),
      kanji: kanji.map((r) => r.kanji).toList(),
      pitchAccents: {}, toneInfo: {}, frequencies: {}, dictionaries: {}, tags: {},
    );
  }

  // Helper methods
  bool _isLikelyPinyin(String text) {
    final cleanText = text.trim().toLowerCase();
    return RegExp(r'^[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ\s]+$').hasMatch(cleanText) &&
           cleanText.isNotEmpty &&
           !ChineseUtil.containsChinese(text) &&
           !ChineseUtil.containsJapaneseKanji(text);
  }

  Future<List<YomichanSearchResult>> searchByParticle(String particle) async {
    final db = await _yomichanDatabase;
    final allTermsResult = await db.query('entries', columns: ['term']);
    final terms = allTermsResult.map((row) => row['term'] as String).toSet().toList();
    final matchingTerms = <String>[];
    for (final term in terms) {
      if (IdeographicUtil.containsIdeographic(term)) {
        final components = IdeographicUtil.getComponents(term);
        if (components.contains(particle) || term.contains(particle)) matchingTerms.add(term);
      }
    }
    if (matchingTerms.isEmpty) return [];
    final placeholders = List.filled(matchingTerms.length, '?').join(',');
    final results = await db.query('entries', where: 'term IN ($placeholders)', whereArgs: matchingTerms, limit: 50);
    final List<YomichanSearchResult> searchResults = [];
    for (final row in results) {
      final entry = model.DictionaryEntry.fromJson(row);
      final dictionaryResult = await _yomichanDatabase!.query('dictionaries', where: 'id = ?', whereArgs: [entry.dictionaryId], limit: 1);
      final dictionary = dictionaryResult.isNotEmpty ? model.Dictionary.fromMap(dictionaryResult.first) : null;
      final pitchResults = await _yomichanDatabase!.query('pitches', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final pitches = pitchResults.map((p) => model.PitchAccent.fromMap(p)).toList();
      final toneResults = await _yomichanDatabase!.query('tones', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final tones = toneResults.map((t) => ToneInfo.fromMap(t)).toList();
      final freqResults = await _yomichanDatabase!.query('frequencies', where: 'dictionary_id = ? AND term = ? AND reading = ?', whereArgs: [entry.dictionaryId, entry.term, entry.reading]);
      final frequencies = freqResults.map((f) => model.FrequencyData.fromMap(f)).toList();
      searchResults.add(YomichanSearchResult(entry: entry, dictionary: dictionary, pitches: pitches, tones: tones, frequencies: frequencies));
    }
    return searchResults;
  }

  Future<List<ToneInfo>> searchTones(String term, {String? language}) async {
    final db = await _yomichanDatabase;
    List<Map<String, Object?>> results;
    if (language != null) {
      results = await db.query('tones', where: 'term = ? AND language = ?', whereArgs: [term, language], limit: 50);
    } else {
      results = await db.query('tones', where: 'term = ?', whereArgs: [term], limit: 50);
    }
    return results.map((row) => ToneInfo.fromMap(row)).toList();
  }

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

  Future<List<model.WiktionaryEntry>> fetchWiktionaryDetails(String word, {String language = 'en'}) async {
    try {
      final service = WiktionaryEtymologyService();
      return await service.fetchWordDetails(word, language);
    } catch (e) {
      print('Error fetching Wiktionary details for $word: $e');
      return [];
    }
  }
}

// Helper classes
class YomichanSearchResult {
  final model.DictionaryEntry entry;
  final model.Dictionary? dictionary;
  final List<model.PitchAccent> pitches;
  final List<ToneInfo> tones;
  final List<model.FrequencyData> frequencies;

  YomichanSearchResult({required this.entry, this.dictionary, required this.pitches, required this.tones, required this.frequencies});
}

class YomichanKanjiResult {
  final model.KanjiEntry kanji;
  final model.Dictionary? dictionary;
  final List<ToneInfo> tones;

  YomichanKanjiResult({required this.kanji, this.dictionary, required this.tones});
}