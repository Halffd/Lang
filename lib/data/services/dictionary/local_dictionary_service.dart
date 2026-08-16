import 'package:lang/utils/japanese_utils.dart';
import 'package:lang/domain/entities/dictionary.dart';

/// Service for local dictionary database operations (Drift/SQLite)
/// Simplified stub implementation
class LocalDictionaryService {
  /// Search local dictionaries for exact matches
  Future<List<DriftDictionaryEntry>> searchExact(String query) async {
    return [];
  }

  /// Search by kana (hiragana/katakana)
  Future<List<DriftDictionaryEntry>> searchByKana(String kana) async {
    return [];
  }

  /// Search for Chinese characters (Hanzi/Kanji)
  Future<List<DriftDictionaryEntry>> searchHanzi(String query) async {
    return [];
  }

  /// Search for Pinyin
  Future<List<DriftDictionaryEntry>> searchPinyin(String query) async {
    return [];
  }

  /// Search with Ichi.moe for Japanese text analysis
  Future<List<IchiMoeResult>> analyzeWithIchiMoe(String text) async {
    return [];
  }

  /// Search for Japanese text with romaji/kana conversion
  Future<List<DriftDictionaryEntry>> searchJapanese(String query) async {
    return [];
  }

  /// Convert drift entries to model entries (domain DictionaryEntry)
  List<DictionaryEntry> convertToModelEntries(
    List<DriftDictionaryEntry> entries,
  ) {
    return [];
  }
}

/// Stub classes for database types
class DriftDictionaryEntry {
  final int id;
  final String term;
  final String? reading;
  final int frequency;
  final String definitions;

  DriftDictionaryEntry({
    required this.id,
    required this.term,
    this.reading,
    this.frequency = 0,
    this.definitions = '',
  });
}

class IchiMoeResult {
  final String word;
  final String? reading;
  final List<String> definitions;

  IchiMoeResult({
    required this.word,
    this.reading,
    this.definitions = const [],
  });
}
