import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/app_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FileKvStorage', () {
    late FileKvStorage storage;
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('filekv_test');
      storage = FileKvStorage(baseDir: temp);
    });

    tearDown(() async {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    });

    test('write then read returns the payload', () async {
      await storage.write('clip_items', '[{"id":"1"}]');
      expect(await storage.read('clip_items'), '[{"id":"1"}]');
    });

    test('read of missing key returns null', () async {
      expect(await storage.read('nope'), isNull);
    });

    test('write overwrites and creates one file per key', () async {
      await storage.write('a', '1');
      await storage.write('a', '2');
      await storage.write('b', '3');
      expect(await storage.read('a'), '2');
      expect(await storage.read('b'), '3');
      expect(temp.listSync().whereType<File>().length, 2);
    });

    test('delete removes the file', () async {
      await storage.write('gone', 'x');
      await storage.delete('gone');
      expect(await storage.read('gone'), isNull);
    });

    test('sanitize: hostile key does not escape the base dir', () async {
      await storage.write('../escape', 'x');
      final files = temp.listSync(recursive: true).whereType<File>();
      expect(files.every((f) => f.path.startsWith(temp.path)), isTrue);
      expect(await storage.read('../escape'), 'x');
    });
  });

  group('SqliteKvStorage', () {
    late SqliteKvStorage storage;
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('sqlitekv_test');
      // point the sqflite factory at the temp dir via openDatabase path
      // handling — SqliteKvStorage.create uses getApplicationSupportDirectory,
      // which the plugin mock does not implement here, so open directly
      final db = await databaseFactory.openDatabase('${temp.path}/kv_test.db');
      await db.execute('''
            CREATE TABLE IF NOT EXISTS kv (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      storage = SqliteKvStorage.forDb(db);
    });

    tearDown(() async {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    });

    test('write then read returns the payload', () async {
      await storage.write('history', '[1,2,3]');
      expect(await storage.read('history'), '[1,2,3]');
    });

    test('read of missing key returns null', () async {
      expect(await storage.read('nope'), isNull);
    });

    test('write is an upsert', () async {
      await storage.write('k', 'old');
      await storage.write('k', 'new');
      expect(await storage.read('k'), 'new');
    });

    test('delete removes the row', () async {
      await storage.write('k', 'v');
      await storage.delete('k');
      expect(await storage.read('k'), isNull);
    });
  });

  group('AppStorage', () {
    test('readWithMigration imports a legacy string once', () async {
      AppStorage.resetForTest();
      SharedPreferences.setMockInitialValues({'legacy_key': 'legacy_payload'});
      final temp = await Directory.systemTemp.createTemp('mig_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final out = await AppStorage.readWithMigration(
        'migrated_key',
        legacyPrefsKey: 'legacy_key',
      );
      expect(out, 'legacy_payload');
      // second read comes from the backend, not the legacy prefs
      final again = await AppStorage.readWithMigration('migrated_key');
      expect(again, 'legacy_payload');
    });

    test('readWithMigration serializes a legacy string list', () async {
      AppStorage.resetForTest();
      SharedPreferences.setMockInitialValues({
        'history_list': ['a', 'b'],
      });
      final temp = await Directory.systemTemp.createTemp('mig_list_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final out = await AppStorage.readWithMigration(
        'history',
        legacyPrefsKey: 'history_list',
      );
      expect(out, '["a","b"]');
    });

    test('exportAll/importAll roundtrip through the files backend', () async {
      AppStorage.resetForTest();
      final temp = await Directory.systemTemp.createTemp('export_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      await AppStorage.instance.write('a', '1');
      await AppStorage.instance.write('b', '2');
      final docs = await AppStorage.exportAll();
      expect(docs['a'], '1');
      expect(docs['b'], '2');

      await AppStorage.instance.delete('a');
      await AppStorage.importAll({'a': '1'});
      expect(await AppStorage.instance.read('a'), '1');
    });

    test('kind falls back to sqlite when unset', () {
      AppStorage.resetForTest();
      expect(AppStorage.kind, StorageBackendKind.sqlite);
    });

    test(
      'writeMedia/readMedia/deleteMedia roundtrip (files backend)',
      () async {
        AppStorage.resetForTest();
        final temp = await Directory.systemTemp.createTemp('media_files_test');
        addTearDown(() => temp.delete(recursive: true));
        await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
        addTearDown(AppStorage.resetForTest);

        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final ref = await AppStorage.writeMedia(bytes);
        expect(MediaRef.isFile(ref), isTrue);

        final out = await AppStorage.readMedia(ref);
        expect(out, bytes);

        await AppStorage.deleteMedia(ref);
        expect(await AppStorage.readMedia(ref), isNull);
      },
    );

    test(
      'writeMedia/readMedia/deleteMedia roundtrip (sqlite backend)',
      () async {
        AppStorage.resetForTest();
        final temp = await Directory.systemTemp.createTemp('media_sql_test');
        addTearDown(() => temp.delete(recursive: true));

        final db = await databaseFactory.openDatabase('${temp.path}/m.db');
        await db.execute('''
            CREATE TABLE IF NOT EXISTS media (
              id TEXT PRIMARY KEY,
              data BLOB NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        await AppStorage.init(StorageBackendKind.sqlite, sqliteDb: db);
        addTearDown(AppStorage.resetForTest);

        final bytes = Uint8List.fromList([7, 8, 9]);
        final ref = await AppStorage.writeMedia(bytes);
        expect(MediaRef.isBlob(ref), isTrue);

        final out = await AppStorage.readMedia(ref);
        expect(out, bytes);

        await AppStorage.deleteMedia(ref);
        expect(await AppStorage.readMedia(ref), isNull);
      },
    );
  });
}
