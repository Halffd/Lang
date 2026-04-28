import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:archive/archive.dart';

class DictionaryLocalDataSource {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    
    String path = join(await getDatabasesPath(), 'yomu_dict.db');
    _db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE tagMeta (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              category TEXT,
              orderValue INTEGER,
              notes TEXT,
              score INTEGER,
              dictionary TEXT
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dictionaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            version INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE terms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expression TEXT,
            reading TEXT,
            definitionTags TEXT,
            rules TEXT,
            score INTEGER,
            glossary TEXT,
            sequence INTEGER,
            termTags TEXT,
            dictionary TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_terms_expression ON terms (expression)');
        await db.execute('CREATE INDEX idx_terms_reading ON terms (reading)');
        
        await db.execute('''
          CREATE TABLE kanji (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            character TEXT,
            onyomi TEXT,
            kunyomi TEXT,
            tags TEXT,
            meanings TEXT,
            dictionary TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_kanji_character ON kanji (character)');

        await db.execute('''
          CREATE TABLE termMeta (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expression TEXT,
            mode TEXT,
            data TEXT,
            dictionary TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_termMeta_expression ON termMeta (expression)');

        await db.execute('''
          CREATE TABLE tagMeta (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            category TEXT,
            orderValue INTEGER,
            notes TEXT,
            score INTEGER,
            dictionary TEXT
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    if (_db == null) await init();
    return await _db!.query('dictionaries');
  }

  Future<void> deleteDictionary(String title) async {
    await _db?.transaction((txn) async {
      await txn.delete('terms', where: 'dictionary = ?', whereArgs: [title]);
      await txn.delete('kanji', where: 'dictionary = ?', whereArgs: [title]);
      await txn.delete('termMeta', where: 'dictionary = ?', whereArgs: [title]);
      await txn.delete('tagMeta', where: 'dictionary = ?', whereArgs: [title]);
      await txn.delete('dictionaries', where: 'title = ?', whereArgs: [title]);
    });
  }

  Future<void> importDictionaryArchive(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    
    final indexFile = archive.findFile('index.json');
    if (indexFile == null) throw Exception('index.json not found');
    
    final indexData = json.decode(utf8.decode(indexFile.content));
    final String title = indexData['title'];
    final int version = indexData['version'];

    final existing = await _db!.query('dictionaries', where: 'title = ?', whereArgs: [title]);
    if (existing.isNotEmpty) return;

    await _db!.insert('dictionaries', {'title': title, 'version': version});

    for (final file in archive) {
      if (file.name.startsWith('term_bank_')) {
        final List entries = json.decode(utf8.decode(file.content));
        await _importTermBank(entries, title);
      } else if (file.name.startsWith('kanji_bank_')) {
        final List entries = json.decode(utf8.decode(file.content));
        await _importKanjiBank(entries, title);
      } else if (file.name.startsWith('term_meta_bank_')) {
        final List entries = json.decode(utf8.decode(file.content));
        await _importTermMetaBank(entries, title);
      } else if (file.name.startsWith('tag_bank_')) {
        final List entries = json.decode(utf8.decode(file.content));
        await _importTagBank(entries, title);
      }
    }
  }

  Future<void> _importTermBank(List<dynamic> entries, String dictionaryTitle) async {
    await _db?.transaction((txn) async {
      final batch = txn.batch();
      for (var entry in entries) {
        String expression = entry[0];
        String reading = entry[1].isNotEmpty ? entry[1] : expression;
        batch.insert('terms', {
          'expression': expression,
          'reading': reading,
          'definitionTags': entry[2],
          'rules': entry[3],
          'score': entry[4],
          'glossary': json.encode(entry[5]),
          'sequence': entry[6],
          'termTags': entry[7],
          'dictionary': dictionaryTitle,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _importKanjiBank(List<dynamic> entries, String dictionaryTitle) async {
    await _db?.transaction((txn) async {
      final batch = txn.batch();
      for (var entry in entries) {
        batch.insert('kanji', {
          'character': entry[0],
          'onyomi': entry[1],
          'kunyomi': entry[2],
          'tags': entry[3],
          'meanings': json.encode(entry[4]),
          'dictionary': dictionaryTitle,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _importTermMetaBank(List<dynamic> entries, String dictionaryTitle) async {
    await _db?.transaction((txn) async {
      final batch = txn.batch();
      for (var entry in entries) {
        batch.insert('termMeta', {
          'expression': entry[0],
          'mode': entry[1],
          'data': entry[2] is Map || entry[2] is List ? json.encode(entry[2]) : entry[2].toString(),
          'dictionary': dictionaryTitle,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _importTagBank(List<dynamic> entries, String dictionaryTitle) async {
    await _db?.transaction((txn) async {
      final batch = txn.batch();
      for (var entry in entries) {
        batch.insert('tagMeta', {
          'name': entry[0],
          'category': entry[1],
          'orderValue': entry[2],
          'notes': entry[3],
          'score': entry[4],
          'dictionary': dictionaryTitle,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> lookupTerms(String query) async {
    if (_db == null) await init();
    return await _db!.query(
      'terms',
      where: 'expression = ? OR reading = ?',
      whereArgs: [query, query],
      orderBy: 'score DESC',
    );
  }

  Future<int?> getFrequency(String word) async {
    if (_db == null) await init();
    final meta = await _db!.query(
      'termMeta',
      where: 'expression = ? AND mode = ?',
      whereArgs: [word, 'freq'],
    );
    if (meta.isNotEmpty) {
      try {
        final data = meta.first['data'];
        if (data is int) return data;
        if (data is String) {
           final decoded = json.decode(data);
           if (decoded is int) return decoded;
           if (decoded is Map) return decoded['value'];
        }
      } catch (_) {}
    }
    return null;
  }
}
