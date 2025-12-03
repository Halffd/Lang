import 'dart:convert';
import 'package:kana_kit/kana_kit.dart';
import '../models/dictionary_entry.dart';
import 'database.dart' as db;
import 'package:drift/drift.dart' as drift;

class DictionaryService {
  static db.AppDatabase? _database;
  final KanaKit _kanaKit = KanaKit();

  static db.AppDatabase get database {
    _database ??= db.AppDatabase();
    return _database!;
  }

  // Search with automatic kana conversion
  Future<DictionarySearchResult> search(String query, {String language = 'ja'}) async {
    if (query.isEmpty) {
      return DictionarySearchResult(entries: [], query: query);
    }

    try {
      // Try exact map first
      List<db.DictionaryEntry> results = await database.searchBoth(query);

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

      // Convert from database models to DictionaryEntry
      final entries = results.map(_rowToEntry).toList();

      return DictionarySearchResult(
        entries: entries,
        query: query,
        hasMore: results.length >= 50,
      );
    } catch (e) {
      print('Search error: $e');
      return DictionarySearchResult(
        entries: [],
        query: query,
        hasMore: false,
      );
    }
  }

  Future<List<String>> translateText(String text, String fromLang, String toLang) async {
    // In a real implementation, this would use a translation API
    // For now, we'll just return a mock translation
    await Future.delayed(const Duration(milliseconds: 500));

    if (fromLang == 'ja' && toLang == 'en') {
      return ['This is a mock translation of "$text" from Japanese to English'];
    } else if (fromLang == 'en' && toLang == 'ja') {
      return ['これは「$text」の英語から日本語へのモック翻訳です'];
    } else {
      return ['Translation from $fromLang to $toLang is not supported yet'];
    }
  }

  bool isJapanese(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF\uFF00-\uFFEF\u4E00-\u9FAF]');
    return japaneseRegex.hasMatch(text);
  }

  String toHiragana(String text) {
    return _kanaKit.toHiragana(text);
  }

  String toKatakana(String text) {
    return _kanaKit.toKatakana(text);
  }

  String toRomaji(String text) {
    return _kanaKit.toRomaji(text);
  }

  // Check if string is likely romaji
  bool _isRomaji(String text) {
    return !text.contains(RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]'));
  }

  // Get entry by exact term
  Future<DictionaryEntry?> getByTerm(String term) async {
    final result = await database.getByTerm(term);
    if (result != null) {
      return _rowToEntry(result);
    }
    return null;
  }

  // Convert database row to DictionaryEntry model
  DictionaryEntry _rowToEntry(db.DictionaryEntry row) {
    return DictionaryEntry(
      term: row.term,
      reading: row.reading ?? '',
      definitions: jsonDecode(row.definitions).cast<String>(),
      tags: row.tags != null ? row.tags!.split(',') : [],
      frequency: row.frequency,
      examples: row.examples != null ? jsonDecode(row.examples!).cast<String>() : [],
      metadata: row.metadata != null ? jsonDecode(row.metadata!) : null,
    );
  }

  // Initialize database with dictionary data
  Future<void> importDictionary(List<Map<String, dynamic>> entries) async {
    final companions = entries.map((json) {
      return db.DictionaryEntriesCompanion.insert(
        term: json['term'],
        reading: drift.Value(json['reading']),
        definitions: jsonEncode(json['definitions']),
        tags: drift.Value(json['tags']?.join(',')),
        frequency: drift.Value(json['frequency'] ?? -1),
        examples: drift.Value(jsonEncode(json['examples'] ?? [])),
        metadata: drift.Value(jsonEncode(json['metadata'] ?? {})),
      );
    }).toList();

    await database.insertBatch(companions);
  }

  // Alias for compatibility with existing code
  Future<List<DictionaryEntry>> searchDictionary(String query) async {
    final result = await search(query);
    return result.entries;
  }
}
