import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/database/schema.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/dictionary_screen.dart';
import 'package:lang/presentation/screens/writer_screen.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('browseEntries query', () {
    late final db;
    setUpAll(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseSchema.onCreate(db, DatabaseSchema.currentVersion);
      // seed a few entries across two dictionaries
      for (var i = 0; i < 3; i++) {
        await db.insert('entries', {
          'dictionary_id': 1,
          'term': 'あ$i',
          'reading': 'あ$i',
          'definitions': '["def $i"]',
          'popularity': 1.0 * (3 - i),
        });
      }
      await db.insert('entries', {
        'dictionary_id': 1,
        'term': 'byte',
        'reading': 'ばいと',
        'definitions': '["byte"]',
        'popularity': 0.0,
      });
    });

    test('prefix browse orders terms and pages by limit', () async {
      final rows = await db.query(
        'entries',
        where: "term LIKE ? ESCAPE '\\'",
        whereArgs: ['あ%'],
        orderBy: 'term',
        limit: 2,
        offset: 0,
      );
      expect(rows, hasLength(2));
      expect(rows.first['term'], 'あ0');
      expect(rows.last['term'], 'あ1');

      final page2 = await db.query(
        'entries',
        where: "term LIKE ? ESCAPE '\\'",
        whereArgs: ['あ%'],
        orderBy: 'term',
        limit: 2,
        offset: 2,
      );
      expect(page2, hasLength(1));
      expect(page2.first['term'], 'あ2');
    });

    test('escaped percent literals do not match everything', () async {
      final rows = await db.query(
        'entries',
        where: "term LIKE ? ESCAPE '\\'",
        whereArgs: ['100\\%'],
      );
      expect(rows, isEmpty);
    });
  });

  group('DictionaryScreen', () {
    testWidgets('shows browse and radicals tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(storage),
          child: ChangeNotifierProvider<AnalyzerProvider>(
            create: (_) => AnalyzerProvider(),
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const DictionaryScreen(),
            ),
          ),
        ),
      );
      // fixed pumps: browse queries the real dictionary database
      // whose async load does not settle within pumpAndSettle bounds
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dictionaries'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('Radicals'), findsOneWidget);
      // browse input present
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('WriterScreen', () {
    testWidgets('shows editor and empty token state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(storage),
          child: ChangeNotifierProvider<AnalyzerProvider>(
            create: (_) => AnalyzerProvider(),
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const WriterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Writer'), findsOneWidget);
      expect(find.text('Write in your target language...'), findsOneWidget);
      expect(find.text('Tokens appear here as you type'), findsOneWidget);

      // analyze button disabled while empty
      final icon = find.byIcon(Icons.text_increase);
      final button = tester.widget<IconButton>(
        find.ancestor(of: icon, matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing text enables the analyze action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(storage),
          child: ChangeNotifierProvider<AnalyzerProvider>(
            create: (_) => AnalyzerProvider(),
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const WriterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'hello world');
      await tester.pump();

      final icon = find.byIcon(Icons.text_increase);
      final button = tester.widget<IconButton>(
        find.ancestor(of: icon, matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('TokenizerService', () {
    test('empty text returns no tokens', () async {
      final tokens = await TokenizerService().tokenize('');
      expect(tokens, isEmpty);
    });
  });
}
