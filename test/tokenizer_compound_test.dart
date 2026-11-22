import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenizerService compound matching', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseSchema.onCreate(db, DatabaseSchema.currentVersion);

      // The dictionary stores the compound under its kanji form only —
      // the kana surface かいどく has no entry of its own.
      await db.insert('dictionaries', {
        'id': 1,
        'name': 'Test Dictionary',
        'title': 'Test Dictionary',
        'revision': 'test',
        'format': 3,
        'author': 'test',
        'description': 'test',
        'url': '',
        'attribution': '',
        'imported_at': 0,
      });
      await db.insert('entries', {
        'dictionary_id': 1,
        'term': '解読',
        'reading': 'かいどく',
        'definitions': '["reading and interpretation"]',
        'popularity': 100,
      });
      await db.insert('entries', {
        'dictionary_id': 1,
        'term': '回',
        'reading': 'かい',
        'definitions': '["times, counter"]',
        'popularity': 10,
      });
      await db.insert('entries', {
        'dictionary_id': 1,
        'term': '毒',
        'reading': 'どく',
        'definitions': "['poison']",
        'popularity': 10,
      });

      DatabaseManager.setTestDatabase(db);
    });

    tearDown(() async {
      DatabaseManager.clearTestDatabase();
      await db.close();
    });

    test('kana compound matched by reading stays one token', () async {
      final tokens = await TokenizerService().tokenize('かいどく');

      expect(tokens, hasLength(1));
      expect(tokens.single.surface, 'かいどく');
      expect(tokens.single.partOfSpeech, 'word');
      expect(tokens.single.reading, 'かいどく');
      expect(tokens.single.startIndex, 0);
      expect(tokens.single.endIndex, 4);
    });

    test('compound keeps its neighbours segmented', () async {
      final tokens = await TokenizerService().tokenize('本かいどく');

      expect(tokens.map((t) => t.surface), contains('かいどく'));
      final compound = tokens.firstWhere((t) => t.surface == 'かいどく');
      expect(compound.endIndex - compound.startIndex, 4);
    });

    test('kanji term still matches directly', () async {
      final tokens = await TokenizerService().tokenize('解読');

      expect(tokens, hasLength(1));
      expect(tokens.single.surface, '解読');
      expect(tokens.single.reading, 'かいどく');
    });
  });
}
