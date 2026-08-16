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
    Directory appDocDir;
    
    // Try multiple fallback paths in order
    final pathsToTry = <Directory>[];
    
    try {
      pathsToTry.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    
    // Linux XDG data directory
    final homeDir = Platform.environment['HOME'] ?? '';
    if (homeDir.isNotEmpty) {
      pathsToTry.add(Directory(path.join(homeDir, '.local', 'share', 'lang')));
      pathsToTry.add(Directory(path.join(homeDir, '.lang_db')));
    }
    
    // System temp directory as last resort
    pathsToTry.add(Directory.systemTemp.createTempSync('lang_db_').parent);

    appDocDir = pathsToTry.first;
    bool success = false;
    
    for (final dir in pathsToTry) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        // Test write access
        final testFile = File(path.join(dir.path, '.write_test'));
        await testFile.writeAsString('test');
        await testFile.delete();
        appDocDir = dir;
        success = true;
        break;
      } catch (_) {
        continue;
      }
    }
    
    if (!success) {
      // Ultimate fallback - use system temp directly
      appDocDir = Directory.systemTemp.createTempSync('lang_db_').parent;
    }

    final String dbPath = path.join(
      appDocDir.path,
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
      'tones',
    ];

    final Map<String, int> sizes = {};
    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      sizes[table] = result.first['count'] as int;
    }

    return sizes;
  }
}
