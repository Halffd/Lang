import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Define the table
class DictionaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get term => text()();
  TextColumn get reading => text().nullable()();
  TextColumn get definitions => text()();  // Store as JSON array string
  TextColumn get tags => text().nullable()();
  IntColumn get frequency => integer().withDefault(const Constant(-1))();
  TextColumn get examples => text().nullable()();
  TextColumn get metadata => text().nullable()();  // JSON string
}

@DriftDatabase(tables: [DictionaryEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Search methods
  Future<List<DictionaryEntry>> searchByTerm(String query) async {
    return (select(dictionaryEntries)
          ..where((entry) => entry.term.like('%$query%'))
          ..limit(50))
        .get();
  }

  Future<List<DictionaryEntry>> searchByReading(String query) async {
    if (query.isEmpty) return [];
    return (select(dictionaryEntries)
          ..where((entry) => entry.reading.like('%$query%'))
          ..limit(50))
        .get();
  }

  Future<List<DictionaryEntry>> searchBoth(String query) async {
    if (query.isEmpty) return [];
    return (select(dictionaryEntries)
          ..where((entry) =>
              entry.term.like('%$query%') |
              entry.reading.like('%$query%'))
          ..limit(50))
        .get();
  }

  // Insert entry
  Future<int> insertEntry(DictionaryEntriesCompanion entry) {
    return into(dictionaryEntries).insert(entry);
  }

  // Batch insert for initial import
  Future<void> insertBatch(List<DictionaryEntriesCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(dictionaryEntries, entries);
    });
  }

  // Get entry by exact term
  Future<DictionaryEntry?> getByTerm(String term) async {
    final results = await (select(dictionaryEntries)
          ..where((entry) => entry.term.equals(term))
          ..limit(1))
        .get();
    return results.isNotEmpty ? results.first : null;
  }

  // Get all entries (for debugging/testing)
  Future<List<DictionaryEntry>> getAllEntries() async {
    return select(dictionaryEntries).get();
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