import 'package:drift/drift.dart';
import '../../core/services/database.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../datasources/remote/ichi_moe_service.dart';

/// Service for local dictionary database operations (Drift/SQLite)
class LocalDictionaryService {
  AppDatabase get _database => AppDatabase();

  /// Search local dictionaries for exact matches
  Future<List<DriftDictionaryEntry>> searchExact(String query) async {
    return await _database.searchBoth(query);
  }

  /// Search by kana (hiragana/katakana)
  Future<List<DriftDictionaryEntry>> searchByKana(String kana) async {
    return await _database.searchBoth(kana);
  }

  /// Search for Chinese characters (Hanzi/Kanji)
  Future<List<DriftDictionaryEntry>> searchHanzi(String query) async {
    return await _database.searchHanzi(query);
  }

  /// Search for Pinyin
  Future<List<DriftDictionaryEntry>> searchPinyin(String query) async {
    return await _database.searchPinyin(query);
  }

  /// Search with Ichi.moe for Japanese text analysis
  Future<List<IchiMoeResult>> analyzeWithIchiMoe(String text) async {
    return await IchiMoeService().analyze(text);
  }

  /// Search for Japanese text with romaji/kana conversion
  Future<List<DriftDictionaryEntry>> searchJapanese(String query) async {
    final results = await _database.searchBoth(query);
    
    // If query looks like romaji, also search by kana
    if (query.isNotEmpty && !query.contains(RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]'))) {
      // Try converting to hiragana
      final kanaKit = KanaKit();
      final hiragana = kanaKit.toHiragana(query);
      if (hiragana != query) {
        final kanaResults = await _database.searchBoth(hiragana);
        final seenTerms = <String>{};
        for (final r in results) seenTerms.add(r.term);
        for (final r in kanaResults) {
          if (!seenTerms.contains(r.term)) results.add(r);
        }
      }
    }
    return results;
  }

  /// Convert drift entries to model entries
  List<model.DictionaryEntry> convertToModelEntries(List<DriftDictionaryEntry> entries) {
    return entries.map((row) {
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
  }
}