import 'package:flutter_test/flutter_test.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Database Schema Tests', () {
    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('Database schema creates FTS5 table properly', () async {
      // Open an in-memory database for testing
      final database = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      // Create all the tables using the schema
      await DatabaseSchema.onCreate(database, DatabaseSchema.currentVersion);
      
      // Check that the FTS5 table was created
      final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((row) => row['name'] as String).toList();
      
      expect(tableNames, contains('entries'));
      expect(tableNames, contains('entries_fts')); // This should be present now
      expect(tableNames, contains('pitches'));
      expect(tableNames, contains('frequencies'));
      expect(tableNames, contains('tones'));
      
      // Check that indexes were created
      final indexes = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='index';");
      final indexNames = indexes.map((row) => row['name'] as String).toList();
      
      expect(indexNames, contains('idx_entries_term_reading'));
      expect(indexNames, contains('idx_frequencies_term_reading_dict'));
      expect(indexNames, contains('idx_pitches_term_reading_dict'));
      expect(indexNames, contains('idx_tones_term_reading_dict'));
      
      await database.close();
    });

    test('FTS5 triggers work properly', () async {
      final database = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseSchema.onCreate(database, DatabaseSchema.currentVersion);
      
      // Insert a test entry
      await database.insert('entries', {
        'dictionary_id': 1,
        'term': 'test',
        'reading': 'てすと',
        'definitions': 'This is a test definition for FTS5 testing',
      });
      
      // Check that the FTS table was updated by the trigger
      final ftsResults = await database.query('entries_fts', where: 'definitions MATCH ?', whereArgs: ['test']);
      expect(ftsResults.length, 1);
      
      // Update the entry
      await database.update('entries', {
        'definitions': 'Updated test definition',
      }, where: 'term = ?', whereArgs: ['test']);
      
      // Check that FTS was updated
      final updatedFtsResults = await database.query('entries_fts', where: 'definitions MATCH ?', whereArgs: ['Updated']);
      expect(updatedFtsResults.length, 1);
      
      // Delete the entry
      await database.delete('entries', where: 'term = ?', whereArgs: ['test']);
      
      // Check that FTS was updated
      final deletedFtsResults = await database.query('entries_fts', where: 'definitions MATCH ?', whereArgs: ['Updated']);
      expect(deletedFtsResults.length, 0);
      
      await database.close();
    });
  });
}