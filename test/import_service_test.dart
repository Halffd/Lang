// ImportService end-to-end: builds a real yomichan-format zip
// (index.json + term/tag banks), imports it into an in-memory
// sqlite database via sqflite_common_ffi and verifies the
// imported rows.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lang/data/repositories/import_service.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/database/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.onCreate(db, DatabaseSchema.currentVersion);
    DatabaseManager.setTestDatabase(db);
  });

  tearDown(() async {
    DatabaseManager.clearTestDatabase();
    await db.close();
  });

  Directory makeDictionaryZip(String title) {
    final dir = Directory.systemTemp.createTempSync('yomichan_zip');
    final zipDir = Directory('${dir.path}/dict');
    zipDir.createSync();

    File('${zipDir.path}/index.json').writeAsStringSync(
      jsonEncode({
        'title': title,
        'revision': 'test-1',
        'format': 3,
        'author': 'tester',
      }),
    );

    // v3 schema: [term, reading, defTags, rules, score,
    //             glossary list, sequence, termTags]
    File('${zipDir.path}/term_bank_1.json').writeAsStringSync(
      jsonEncode([
        [
          '読む',
          'よむ',
          '',
          'v5',
          100,
          ['to read'],
          0,
          '',
        ],
      ]),
    );

    File('${zipDir.path}/tag_bank_1.json').writeAsStringSync(
      jsonEncode([
        ['v5', 'pos', 0, 'godan verb', 0],
      ]),
    );
    // zip the folder contents at root level (parser looks for flat names)
    final archive = Archive();
    for (final f in zipDir.listSync()) {
      if (f is File) {
        archive.addFile(
          ArchiveFile(
            f.path.split('/').last,
            f.lengthSync(),
            f.readAsBytesSync(),
          ),
        );
      }
    }
    final out = File('${dir.path}/dict.zip');
    out.writeAsBytesSync(ZipEncoder().encode(archive));
    return dir;
  }

  test('imports a yomichan dictionary zip end to end', () async {
    final dir = makeDictionaryZip('Test Dict');
    final service = ImportService();

    final dict = await service.importDictionary(File('${dir.path}/dict.zip'));

    expect(dict.title, 'Test Dict');
    // name is sanitized to a storage-safe form
    expect(dict.name, 'test_dict');

    // dictionary row exists
    final dicts = await db.query('dictionaries');
    expect(dicts.length, 1);
    expect(dicts.first['name'], 'test_dict');

    // term imported with reading + definition
    final terms = await db.query(
      'entries',
      where: 'dictionary_id = ?',
      whereArgs: [dict.id],
    );
    expect(terms, isNotEmpty);
    final termRow = terms.first;
    expect(termRow['term'], '読む');

    // tag imported
    final tags = await db.query(
      'tags',
      where: 'dictionary_id = ?',
      whereArgs: [dict.id],
    );
    expect(tags, isNotEmpty);
    expect(tags.first['name'], 'v5');

    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('duplicate dictionary name is rejected', () async {
    final dir = makeDictionaryZip('Dupe Dict');
    final service = ImportService();

    await service.importDictionary(File('${dir.path}/dict.zip'));

    await expectLater(
      service.importDictionary(File('${dir.path}/dict.zip')),
      throwsException,
    );

    // still exactly one dictionary
    final dicts = await db.query('dictionaries');
    expect(dicts.length, 1);

    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('malformed zip (no index.json) fails with error status', () async {
    final dir = Directory.systemTemp.createTempSync('bad_zip');
    final archive = Archive()
      ..addFile(ArchiveFile('term_bank_1.json', 2, utf8.encode('[]')));
    final out = File('${dir.path}/bad.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final service = ImportService();
    await expectLater(service.importDictionary(out), throwsException);
    dir.deleteSync(recursive: true);
  });

  test('v5 -> v6 migration adds entry media columns', () async {
    // create a v5-schema entries table (no media columns), then
    // run the upgrade path exactly as the migrator would
    final db2 = await databaseFactory.openDatabase(
      ':memory:migration_${DateTime.now().microsecondsSinceEpoch}',
    );
    await db2.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dictionary_id INTEGER NOT NULL,
        term TEXT NOT NULL,
        reading TEXT NOT NULL,
        definition_tags TEXT,
        rules TEXT,
        popularity REAL NOT NULL DEFAULT 0,
        definitions TEXT NOT NULL,
        sequence INTEGER,
        term_tags TEXT
      )
    ''');
    await DatabaseSchema.onUpgrade(db2, 5, 6);

    // media columns now exist and accept writes
    await db2.insert('entries', {
      'dictionary_id': 1,
      'term': 'x',
      'reading': 'y',
      'definitions': '["z"]',
      'popularity': 0,
      'audio_url': 'a.mp3',
      'image_url': 'i.png',
      'image_caption': 'cap',
    });
    final row = await db2.query('entries');
    expect(row.first['audio_url'], 'a.mp3');
    await db2.close();
  });
}
