import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class DatabaseManager {
  static DatabaseManager? _instance;
  static Database? _database;
  
  DatabaseManager._();
  
  factory DatabaseManager() {
    _instance ??= DatabaseManager._();
    return _instance!;
  }
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final Directory documentsDirectory = 
        await getApplicationDocumentsDirectory();
    final String dbPath = path.join(
      documentsDirectory.path,
      'yomichan.db',
    );
    
    return await openDatabase(
      dbPath,
      version: DatabaseSchema.currentVersion,
      onCreate: DatabaseSchema.onCreate,
      onUpgrade: DatabaseSchema.onUpgrade,
      onConfigure: _onConfigure,
    );
  }
  
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
    
    // Performance optimizations
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA cache_size = -64000'); // 64MB cache
  }
  
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
  
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
  
  Future<int> getDatabaseSize() async {
    final db = await database;
    final dbPath = db.path;
    final file = File(dbPath);
    return await file.length();
  }
  
  Future<Map<String, int>> getTableSizes() async {
    final db = await database;
    final tables = [
      'dictionaries',
      'entries',
      'kanji',
      'tags',
      'pitches',
      'frequencies',
    ];
    
    final Map<String, int> sizes = {};
    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      sizes[table] = result.first['count'] as int;
    }
    
    return sizes;
  }
}