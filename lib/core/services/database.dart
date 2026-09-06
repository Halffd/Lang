import 'dart:io';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Define the table - rename to avoid conflicts with model
class DriftDictionaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get term => text()();
  TextColumn get reading => text().nullable()();
  TextColumn get definitions => text()(); // Store as JSON array string
  TextColumn get tags => text().nullable()();
  IntColumn get frequency => integer().withDefault(const Constant(-1))();
  TextColumn get examples => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON string
}

// Table for tone information (Mandarin, Cantonese, etc.)
class DriftTones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dictionaryId => integer()();
  TextColumn get term => text()();
  TextColumn get reading => text()();
  TextColumn get language => text()(); // 'mandarin', 'cantonese', etc.
  TextColumn get tones => text()(); // JSON string containing tone patterns
}

// Table for tracking word occurrences during text analysis
class WordOccurrences extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  TextColumn get reading => text().nullable()();
  TextColumn get baseForm => text().nullable()();
  IntColumn get position => integer()();
  IntColumn get sentenceId =>
      integer().nullable()(); // To track which sentence a word came from
}

// Table for Japanese text FTS5 analysis
class JapaneseTextFts extends Table {
  TextColumn get content => text()();
}

// Table for Chinese text FTS5 analysis
class ChineseTextFts extends Table {
  TextColumn get content => text()();
}

@DriftDatabase(
  tables: [
    DriftDictionaryEntries,
    DriftTones,
    WordOccurrences,
    JapaneseTextFts,
    ChineseTextFts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for tests (no path_provider needed).
  @visibleForTesting
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  // Search methods for existing dictionary entries
  Future<List<DriftDictionaryEntry>> searchByTerm(String query) async {
    return (select(driftDictionaryEntries)
          ..where((entry) => entry.term.like('%$query%'))
          ..limit(50))
        .get();
  }

  Future<List<DriftDictionaryEntry>> searchByReading(String query) async {
    if (query.isEmpty) return [];
    return (select(driftDictionaryEntries)
          ..where((entry) => entry.reading.like('%$query%'))
          ..limit(50))
        .get();
  }

  Future<List<DriftDictionaryEntry>> searchBoth(String query) async {
    if (query.isEmpty) return [];
    return (select(driftDictionaryEntries)
          ..where(
            (entry) =>
                entry.term.like('%$query%') | entry.reading.like('%$query%'),
          )
          ..limit(50))
        .get();
  }

  // Search method for Pinyin support
  Future<List<DriftDictionaryEntry>> searchPinyin(String query) async {
    if (query.isEmpty) return [];
    // Search in both term and reading fields for the query
    return (select(driftDictionaryEntries)
          ..where(
            (entry) =>
                entry.term.like('%$query%') | entry.reading.like('%$query%'),
          )
          ..limit(50))
        .get();
  }

  // Search specifically for Chinese characters (hanzi)
  Future<List<DriftDictionaryEntry>> searchHanzi(String query) async {
    if (query.isEmpty) return [];
    // Exact match for the Chinese character
    return (select(driftDictionaryEntries)
          ..where(
            (entry) => entry.term.like('%$query%') & entry.term.isNotNull(),
          )
          ..limit(50))
        .get();
  }

  // Insert entry for existing dictionary
  Future<int> insertEntry(DriftDictionaryEntriesCompanion entry) {
    return into(driftDictionaryEntries).insert(entry);
  }

  // Batch insert for initial import
  Future<void> insertBatch(
    List<DriftDictionaryEntriesCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAll(driftDictionaryEntries, entries);
    });
  }

  // Get entry by exact term
  Future<DriftDictionaryEntry?> getByTerm(String term) async {
    final results =
        await (select(driftDictionaryEntries)
              ..where((entry) => entry.term.equals(term))
              ..limit(1))
            .get();
    return results.isNotEmpty ? results.first : null;
  }

  // Get all entries (for debugging/testing)
  Future<List<DriftDictionaryEntry>> getAllEntries() async {
    return select(driftDictionaryEntries).get();
  }

  // Tone-related methods
  Future<List<DriftTone>> getTonesByTerm(String term) async {
    return (select(driftTones)..where((tone) => tone.term.equals(term))).get();
  }

  Future<List<DriftTone>> getTonesByTermAndLanguage(
    String term,
    String language,
  ) async {
    return (select(driftTones)..where(
          (tone) => tone.term.equals(term) & tone.language.equals(language),
        ))
        .get();
  }

  Future<int> insertTone(DriftTonesCompanion entry) {
    return into(driftTones).insert(entry);
  }

  Future<void> insertToneBatch(List<DriftTonesCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(driftTones, entries);
    });
  }

  // Methods for text analysis and word occurrence tracking
  Future<void> insertWordOccurrences(
    List<WordOccurrencesCompanion> entries,
  ) async {
    // Batch insert for performance
    await batch((batch) {
      batch.insertAll(wordOccurrences, entries);
    });
  }

  Future<int> clearWordOccurrences() async {
    return await (delete(
      wordOccurrences,
    )..where((tbl) => const Constant(true))).go();
  }

  // Get word frequencies from the current analysis
  Future<List<WordFrequencyResult>> getWordFrequencies() async {
    final results = await customSelect('''
      SELECT
        word,
        COUNT(*) as occurrence_count,
        MIN(position) as first_occurrence
      FROM word_occurrences
      GROUP BY word
      ORDER BY occurrence_count DESC, first_occurrence ASC
    ''').get();

    return results
        .map(
          (row) => WordFrequencyResult(
            word: row.read<String>('word'),
            count: row.read<int>('occurrence_count'),
            firstOccurrence: row.read<int>('first_occurrence'),
          ),
        )
        .toList();
  }

  // Get word frequencies with dictionary information
  Future<List<WordFrequencyWithDefinition>>
  getWordFrequenciesWithDefinitions() async {
    final results = await customSelect('''
      SELECT
        wo.word,
        COUNT(wo.word) as occurrence_count,
        MIN(wo.position) as first_occurrence,
        de.definitions,
        de.reading as dict_reading,
        de.frequency as popularity
      FROM word_occurrences wo
      LEFT JOIN drift_dictionary_entries de ON wo.word = de.term
      GROUP BY wo.word
      ORDER BY occurrence_count DESC, first_occurrence ASC
    ''').get();

    return results
        .map(
          (row) => WordFrequencyWithDefinition(
            word: row.read<String>('word'),
            count: row.read<int>('occurrence_count'),
            firstOccurrence: row.read<int>('first_occurrence'),
            definitions: row.read<String?>('definitions'),
            reading: row.read<String?>('dict_reading'),
            popularity: row.read<int?>('popularity') ?? -1,
          ),
        )
        .toList();
  }
}

// Connection setup for cross-platform
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'jmdict.db'));

    return NativeDatabase.createInBackground(file);
  });
}

// Data classes for query results
class WordFrequencyResult {
  final String word;
  final int count;
  final int firstOccurrence;

  WordFrequencyResult({
    required this.word,
    required this.count,
    required this.firstOccurrence,
  });
}

class WordFrequencyWithDefinition {
  final String word;
  final int count;
  final int firstOccurrence;
  final String? definitions;
  final String? reading;
  final int popularity;

  WordFrequencyWithDefinition({
    required this.word,
    required this.count,
    required this.firstOccurrence,
    this.definitions,
    this.reading,
    this.popularity = -1,
  });
}
