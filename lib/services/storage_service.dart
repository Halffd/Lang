import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class StorageService {
  late SharedPreferences _prefs;
  late Database _database;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize SQLite database with proper platform support
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'yomitan_search.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Create tables
        await db.execute(
          'CREATE TABLE dictionary_entries(id INTEGER PRIMARY KEY, term TEXT, reading TEXT, definitions TEXT, tags TEXT, frequency INTEGER, examples TEXT, metadata TEXT)',
        );
        await db.execute(
          'CREATE TABLE saved_words(id INTEGER PRIMARY KEY, word TEXT UNIQUE, details TEXT, date_added INTEGER)',
        );
        await db.execute(
          'CREATE TABLE search_history(id INTEGER PRIMARY KEY, query TEXT UNIQUE, date INTEGER)',
        );
      },
    );
  }
  
  // SharedPreferences methods
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);
  double? getDouble(String key) => _prefs.getDouble(key);
  String? getString(String key) => _prefs.getString(key);
  List<String>? getStringList(String key) => _prefs.getStringList(key);
  
  Map<String, dynamic>? getJson(String key) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return json.decode(jsonString) as Map<String, dynamic>;
  }
  
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  Future<bool> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);
  
  Future<bool> setJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, json.encode(value));
  }
  
  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
  
  // Database methods for saved words
  Future<int> saveDictionaryEntry(Map<String, dynamic> entry) async {
    return await _database.insert(
      'dictionary_entries',
      {
        'term': entry['term'],
        'reading': entry['reading'],
        'definitions': json.encode(entry['definitions']),
        'tags': json.encode(entry['tags'] ?? []),
        'frequency': entry['frequency'] ?? -1,
        'examples': json.encode(entry['examples'] ?? []),
        'metadata': json.encode(entry['metadata'] ?? {}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getDictionaryEntries(String term) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'dictionary_entries',
      where: 'term = ?',
      whereArgs: [term],
    );
    
    return maps.map((map) {
      return {
        'term': map['term'],
        'reading': map['reading'],
        'definitions': json.decode(map['definitions']),
        'tags': json.decode(map['tags']),
        'frequency': map['frequency'],
        'examples': json.decode(map['examples']),
        'metadata': json.decode(map['metadata']),
      };
    }).toList();
  }
  
  Future<int> saveWord(String word, Map<String, dynamic> details) async {
    return await _database.insert(
      'saved_words',
      {
        'word': word,
        'details': json.encode(details),
        'date_added': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getSavedWords() async {
    final List<Map<String, dynamic>> maps = await _database.query('saved_words', orderBy: 'date_added DESC');
    
    return maps.map((map) {
      return {
        'word': map['word'],
        'details': json.decode(map['details']),
        'date_added': DateTime.fromMillisecondsSinceEpoch(map['date_added']),
      };
    }).toList();
  }
  
  Future<int> deleteWord(String word) async {
    return await _database.delete(
      'saved_words',
      where: 'word = ?',
      whereArgs: [word],
    );
  }
  
  Future<int> addSearchQuery(String query) async {
    return await _database.insert(
      'search_history',
      {
        'query': query,
        'date': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<String>> getSearchHistory({int limit = 50}) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'search_history',
      orderBy: 'date DESC',
      limit: limit,
    );
    
    return List<String>.from(maps.map((map) => map['query']));
  }
  
  Future<void> clearSearchHistory() async {
    await _database.delete('search_history');
  }
}
