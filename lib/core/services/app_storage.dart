import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where JSON document stores (clipboard manager, history, saved words,
/// screenshot registry…) keep their payloads.
enum StorageBackendKind { sqlite, files }

StorageBackendKind storageBackendFromName(String? name) =>
    name == 'files' ? StorageBackendKind.files : StorageBackendKind.sqlite;

/// Key–value storage for serialized JSON documents.
abstract class KvStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Local-files backend: one pretty-printed JSON file per key under
/// `<app-support>/lang_storage/`. Human-readable, easy to back up,
/// trivially inspectable.
class FileKvStorage implements KvStorage {
  FileKvStorage({required Directory baseDir}) : _base = baseDir;

  final Directory _base;

  static Future<FileKvStorage> create({Directory? baseDir}) async {
    final Directory base;
    if (baseDir != null) {
      base = baseDir..createSync(recursive: true);
    } else {
      final support = await getApplicationSupportDirectory();
      base = Directory(p.join(support.path, 'lang_storage'))
        ..createSync(recursive: true);
    }
    return FileKvStorage(baseDir: base);
  }

  File _fileFor(String key) {
    // sanitize: keys are simple identifiers, but never trust them blindly
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File(p.join(_base.path, '$safe.json'));
  }

  @override
  Future<String?> read(String key) async {
    final f = _fileFor(key);
    if (!f.existsSync()) return null;
    try {
      return f.readAsStringSync();
    } catch (e) {
      debugPrint('FileKvStorage read($key) failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final f = _fileFor(key);
    // atomic-ish: write temp then rename
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(value, flush: true);
    try {
      tmp.renameSync(f.path);
    } catch (_) {
      // rename across odd filesystems: fall back to a direct write
      f.writeAsStringSync(value, flush: true);
      try {
        tmp.deleteSync();
      } catch (_) {}
    }
  }

  @override
  Future<void> delete(String key) async {
    final f = _fileFor(key);
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// SQLite backend: a single `kv` table through sqflite. Shares the FFI
/// factory already configured for the dictionary database on desktop.
class SqliteKvStorage implements KvStorage {
  SqliteKvStorage._(this._db);

  /// Test hook: wrap an externally created database (sqflite FFI with a
  /// temp path) instead of the app-support default.
  @visibleForTesting
  factory SqliteKvStorage.forDb(Database db) => SqliteKvStorage._(db);

  final Database _db;
  static Database? _dbRef;

  static Future<SqliteKvStorage> create() async {
    if (_dbRef != null) return SqliteKvStorage._(_dbRef!);
    final support = await getApplicationSupportDirectory();
    final dbPath = p.join(support.path, 'lang_storage.db');
    _dbRef = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS kv (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS media (
            id TEXT PRIMARY KEY,
            data BLOB NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
      },
    );
    return SqliteKvStorage._(_dbRef!);
  }

  @override
  Future<String?> read(String key) async {
    try {
      final rows = await _db.query(
        'kv',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e) {
      debugPrint('SqliteKvStorage read($key) failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _db.insert('kv', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete('kv', where: 'key = ?', whereArgs: [key]);
  }
}

/// Facade the services use. Chosen once at startup from the persisted
/// setting; every store reads/writes through [instance]. On the first
/// read of a key, data still living in the legacy SharedPreferences
/// payload is imported once and the legacy copy is left in place
/// (harmless, and it keeps downgrade paths open).
class AppStorage {
  AppStorage._();

  static KvStorage? _backend;
  static StorageBackendKind? _kind;
  static final Set<String> _migrated = {};

  /// Initialize with the user's chosen backend. Call once at startup
  /// before any store loads. Falls back to files when SQLite cannot
  /// open (desktop FFI misconfigured etc.) so the app never hard-fails.
  static Future<void> init(
    StorageBackendKind kind, {
    Directory? filesBaseDir,
    Database? sqliteDb,
  }) async {
    _kind = kind;
    if (_backend != null) return;
    if (kind == StorageBackendKind.sqlite) {
      try {
        _backend = sqliteDb != null
            ? SqliteKvStorage.forDb(sqliteDb)
            : await SqliteKvStorage.create();
        return;
      } catch (e) {
        debugPrint(
          'AppStorage: sqlite backend unavailable ($e); '
          'falling back to files',
        );
      }
    }
    _backend = await FileKvStorage.create(baseDir: filesBaseDir);
  }

  static KvStorage get instance {
    final b = _backend;
    if (b != null) return b;
    // Uninitialized access (tests that never call init, or a code path
    // that loaded before main's init): degrade to an in-memory store so
    // services keep working instead of crashing. Production always runs
    // init() first, so this branch never fires there.
    debugPrint('AppStorage: accessed before init(); using in-memory fallback');
    return _fallback ??= InMemoryKvStorage();
  }

  static InMemoryKvStorage? _fallback;

  static StorageBackendKind get kind {
    final k = _kind;
    if (k != null) return k;
    return StorageBackendKind.sqlite;
  }

  /// True only when the active backend is the real SQLite store. Callers
  /// deciding between blob and file payloads must check this, not
  /// [kind]: [kind] reports the configured intent, which can differ from
  /// the active backend after a fallback (or before init in tests).
  static bool get isSqliteBackend => _backend is SqliteKvStorage;

  /// Read [key] with one-time import from the legacy SharedPreferences
  /// payload [legacyPrefsKey] when the backend has no value yet.
  static Future<String?> readWithMigration(
    String key, {
    String? legacyPrefsKey,
  }) async {
    final current = await instance.read(key);
    if (current != null) return current;
    if (legacyPrefsKey == null) return null;
    if (_migrated.contains(key)) return null;
    _migrated.add(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      // legacy values may be strings OR string lists (the old history
      // store used setStringList); both serialize to JSON text here.
      // getString throws a cast error on list-typed values in some
      // prefs impls, so each read is guarded.
      String? legacy;
      try {
        legacy = prefs.getString(legacyPrefsKey);
      } catch (_) {
        legacy = null;
      }
      if (legacy == null) {
        try {
          final list = prefs.getStringList(legacyPrefsKey);
          if (list != null) legacy = jsonEncode(list);
        } catch (_) {}
      }
      if (legacy == null || legacy.isEmpty) return null;
      await instance.write(key, legacy);
      return legacy;
    } catch (_) {
      return null;
    }
  }

  /// Test hook: reset to uninitialized (tests then call init with their
  /// own kind / temp directories via sqflite FFI in-memory or temp dir).
  @visibleForTesting
  static void resetForTest() {
    _backend = null;
    _kind = null;
    _fallback = null;
    _migrated.clear();
  }

  // ----------------------------------------------------------
  // media (image bytes)
  //
  // Binary payloads follow the active backend: SQLite stores them in a
  // `media` BLOB table; the files backend writes into
  // `lang_storage/media/`. References are self-describing (`db:<id>` /
  // `file:<path>`) so entries created under one backend stay readable
  // after switching.
  // ----------------------------------------------------------

  static const String _blobPrefix = 'db:';
  static const String _filePrefix = 'file:';

  static int _mediaSeq = 0;

  /// Store [bytes]; returns an opaque ref for [readMedia]/[deleteMedia].
  static Future<String> writeMedia(Uint8List bytes) async {
    if (isSqliteBackend) {
      final id =
          'm_${DateTime.now().millisecondsSinceEpoch}_'
          '${bytes.length}_${_mediaSeq++}';
      final db = (_backend as SqliteKvStorage)._db;
      await db.insert('media', {
        'id': id,
        'data': bytes,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return '$_blobPrefix$id';
    }
    final dir = await _mediaDir();
    final name =
        'img_${DateTime.now().millisecondsSinceEpoch}_${_mediaSeq++}.png';
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return '$_filePrefix${f.path}';
  }

  static Future<Directory> _mediaDir() async {
    if (_backend is FileKvStorage) {
      return Directory(p.join((_backend as FileKvStorage)._base.path, 'media'))
        ..createSync(recursive: true);
    }
    // in-memory fallback backend: park payloads in the system temp dir
    // (no path_provider channel available there)
    return Directory.systemTemp.createTemp('lang_media_fallback');
  }

  /// Read bytes for a media ref (null when missing/unreadable).
  static Future<Uint8List?> readMedia(String ref) async {
    try {
      if (ref.startsWith(_blobPrefix)) {
        if (_backend is! SqliteKvStorage) return null;
        final id = ref.substring(_blobPrefix.length);
        final db = (_backend as SqliteKvStorage)._db;
        final rows = await db.query(
          'media',
          columns: ['data'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final data = rows.first['data'];
        if (data is Uint8List) return data;
        if (data is List<int>) return Uint8List.fromList(data);
        return null;
      }
      final path = ref.startsWith(_filePrefix)
          ? ref.substring(_filePrefix.length)
          : ref;
      final f = File(path);
      if (!f.existsSync()) return null;
      return await f.readAsBytes();
    } catch (e) {
      debugPrint('AppStorage.readMedia failed: $e');
      return null;
    }
  }

  /// Delete the payload behind [ref]; missing payloads are ignored.
  static Future<void> deleteMedia(String ref) async {
    try {
      if (ref.startsWith(_blobPrefix)) {
        if (_backend is! SqliteKvStorage) return;
        final id = ref.substring(_blobPrefix.length);
        final db = (_backend as SqliteKvStorage)._db;
        await db.delete('media', where: 'id = ?', whereArgs: [id]);
        return;
      }
      final path = ref.startsWith(_filePrefix)
          ? ref.substring(_filePrefix.length)
          : ref;
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Export every stored document (both backends) as a JSON map — used
  /// by the backup service and by backend switching.
  static Future<Map<String, String>> exportAll() async {
    final out = <String, String>{};
    // sqlite: select all
    if (_backend is SqliteKvStorage) {
      try {
        final db = (_backend as SqliteKvStorage)._db;
        final rows = await db.query('kv');
        for (final row in rows) {
          out[row['key'] as String] = row['value'] as String;
        }
      } catch (_) {}
    } else if (_backend is FileKvStorage) {
      final dir = (_backend as FileKvStorage)._base;
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        try {
          final key = p.basenameWithoutExtension(f.path);
          out[key] = f.readAsStringSync();
        } catch (_) {}
      }
    }
    return out;
  }

  /// Import a map of key→payload (backup restore path).
  static Future<void> importAll(Map<String, String> docs) async {
    for (final e in docs.entries) {
      await instance.write(e.key, e.value);
    }
  }

  /// JSON encode helper so services stop re-encoding inline.
  static String encodeList(List<Map<String, dynamic>> list) => jsonEncode(list);
}

/// Volatile store used only when [AppStorage.init] has not run.
class InMemoryKvStorage implements KvStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Typed media ref helpers so call sites do not parse prefixes.
class MediaRef {
  /// True when [ref] points at SQLite blob storage.
  static bool isBlob(String ref) => ref.startsWith('db:');

  /// True when [ref] points at a file on disk (or a legacy bare path).
  static bool isFile(String ref) => !isBlob(ref);
}
