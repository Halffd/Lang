import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/database/schema.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/annotated_line.dart';
import 'package:lang/presentation/widgets/video/player_side_pane.dart';
import 'package:lang/utils/chapter_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// An in-memory dictionary with one Japanese entry, so the reading
  /// annotations have a reading to draw. Created outside the widget
  /// tester's fake-async zone, where the real sqlite I/O would never
  /// complete.
  Database? testDictionary;

  setUpAll(() {
    sqfliteFfiInit();
    // the no-isolate factory keeps its futures on the test isolate, so
    // they complete under the widget tester's fake clock
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.onCreate(db, DatabaseSchema.currentVersion);
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
      'term': '日本語',
      'reading': 'にほんご',
      'definitions': '["the Japanese language"]',
      'popularity': 100,
    });
    DatabaseManager.setTestDatabase(db);
    testDictionary = db;
  });

  tearDown(() async {
    DatabaseManager.clearTestDatabase();
    await testDictionary?.close();
    testDictionary = null;
  });

  Future<void> pumpPane(
    WidgetTester tester, {
    required PlayerPaneTab tab,
    String description = '',
    List<YouTubeChapter> chapters = const [],
    Duration position = Duration.zero,
    List<({String text, Duration start})> transcript = const [],
    List<Widget> settings = const [],
    ValueChanged<PlayerPaneTab>? onTabChanged,
    ValueChanged<YouTubeChapter>? onSelectChapter,
    ValueChanged<int>? onSelectLine,
    ValueChanged<int>? onLookupLine,
    bool inPopupScope = false,
    String readingStyle = 'off',
    Widget Function(BuildContext, String, bool)? transcriptBuilder,
  }) async {
    // the pane reads the font scale from AppState
    SharedPreferences.setMockInitialValues({'reading_style': readingStyle});
    final storage = StorageService();
    await storage.init();
    final state = AppState(storage);
    Widget pane = Scaffold(
      body: SizedBox(
        width: 360,
        height: 600,
        child: PlayerSidePane(
          tab: tab,
          onTabChanged: onTabChanged ?? (_) {},
          description: description,
          chapters: chapters,
          currentPosition: position,
          transcript: transcript,
          settings: settings,
          onSelectChapter: onSelectChapter,
          onSelectLine: onSelectLine,
          onLookupLine: onLookupLine,
          transcriptBuilder: transcriptBuilder,
        ),
      ),
    );
    if (inPopupScope) pane = PopupDictionaryScope(child: pane);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: pane,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a tab for each section', (tester) async {
    await pumpPane(tester, tab: PlayerPaneTab.description);

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping a tab reports the new tab', (tester) async {
    final chosen = <PlayerPaneTab>[];
    await pumpPane(
      tester,
      tab: PlayerPaneTab.description,
      onTabChanged: chosen.add,
    );

    await tester.tap(find.text('Chapters'));
    await tester.pump();

    expect(chosen, [PlayerPaneTab.chapters]);
  });

  testWidgets('the description tab shows the description text', (
    tester,
  ) async {
    await pumpPane(
      tester,
      tab: PlayerPaneTab.description,
      description: 'A lesson about Japanese grammar.',
    );

    expect(find.text('A lesson about Japanese grammar.'), findsOneWidget);
  });

  testWidgets('the description tab says so when there is none', (
    tester,
  ) async {
    await pumpPane(tester, tab: PlayerPaneTab.description);

    expect(find.text('No description available.'), findsOneWidget);
  });

  testWidgets('the chapters tab lists the chapters', (tester) async {
    await pumpPane(
      tester,
      tab: PlayerPaneTab.chapters,
      chapters: const [
        YouTubeChapter(
          title: 'Opening',
          start: Duration.zero,
          end: Duration(minutes: 1),
        ),
        YouTubeChapter(
          title: 'Grammar',
          start: Duration(minutes: 1),
          end: Duration(minutes: 5),
        ),
      ],
    );

    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
  });

  testWidgets('the chapters tab says so when there are none', (tester) async {
    await pumpPane(tester, tab: PlayerPaneTab.chapters);

    expect(find.text('No chapters in this video.'), findsOneWidget);
  });

  testWidgets('tapping a chapter reports it', (tester) async {
    final chosen = <YouTubeChapter>[];
    const chapter = YouTubeChapter(
      title: 'Grammar',
      start: Duration(minutes: 1),
      end: Duration(minutes: 5),
    );
    await pumpPane(
      tester,
      tab: PlayerPaneTab.chapters,
      chapters: const [chapter],
      onSelectChapter: chosen.add,
    );

    await tester.tap(find.text('Grammar'));
    await tester.pump();

    expect(chosen, [chapter]);
  });

  testWidgets('the transcript tab lists the lines', (tester) async {
    await pumpPane(
      tester,
      tab: PlayerPaneTab.transcript,
      transcript: [
        (text: 'First line', start: Duration.zero),
        (text: 'Second line', start: Duration(seconds: 5)),
      ],
    );

    expect(find.text('First line'), findsOneWidget);
    expect(find.text('Second line'), findsOneWidget);
  });

  testWidgets('the transcript tab says so when no track is loaded', (
    tester,
  ) async {
    await pumpPane(tester, tab: PlayerPaneTab.transcript);

    expect(find.text('No subtitle track loaded.'), findsOneWidget);
  });

  testWidgets('tapping a transcript line reports its index', (tester) async {
    final selected = <int>[];
    await pumpPane(
      tester,
      tab: PlayerPaneTab.transcript,
      transcript: [
        (text: 'First line', start: Duration.zero),
        (text: 'Second line', start: Duration(seconds: 5)),
      ],
      onSelectLine: selected.add,
    );

    await tester.tap(find.text('Second line'));
    await tester.pump();

    expect(selected, [1]);
  });

  testWidgets('long-pressing a transcript line reports its index', (
    tester,
  ) async {
    final looked = <int>[];
    await pumpPane(
      tester,
      tab: PlayerPaneTab.transcript,
      transcript: [
        (text: 'First line', start: Duration.zero),
        (text: 'Second line', start: Duration(seconds: 5)),
      ],
      onLookupLine: looked.add,
    );

    await tester.longPress(find.text('First line'));
    await tester.pump();

    expect(looked, [0]);
  });

  testWidgets('the settings tab shows the supplied settings', (tester) async {
    await pumpPane(
      tester,
      tab: PlayerPaneTab.settings,
      settings: const [Text('A setting')],
    );

    expect(find.text('A setting'), findsOneWidget);
  });

  testWidgets('the settings tab says so when there are none', (tester) async {
    await pumpPane(tester, tab: PlayerPaneTab.settings);

    expect(find.text('No settings available.'), findsOneWidget);
  });

  testWidgets('hovering a transcript word opens its definition', (
    tester,
  ) async {
    // The video tab's plain hover rides on the popup dictionary's own
    // global pointer listener, so the side pane needs no widget of its
    // own: the scope plus the enabled flag is the whole contract.
    await pumpPane(
      tester,
      tab: PlayerPaneTab.transcript,
      transcript: [(text: '日本語のテスト', start: Duration.zero)],
      inPopupScope: true,
    );

    final controller = PopupDictionaryController.instance;
    controller.config = PopupDictionaryConfig(
      allowedScreens: {PopupScreenScope.video},
    );
    controller.currentRouteName = 'video';
    controller.lookupBuilder =
        (context, lookup) async => Directionality(
          textDirection: TextDirection.ltr,
          child: Text('def:${lookup.term}'),
        );
    controller.plainHoverEnabled = true;
    addTearDown(() {
      controller.plainHoverEnabled = false;
      controller.lookupBuilder = null;
      controller.currentRouteName = '';
    });

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    // aim at a glyph: the transcript line's text widget fills the tile,
    // so its centre can land past the last character
    final line = tester.getRect(find.text('日本語のテスト'));
    await gesture.moveTo(Offset(line.left + 8, line.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isPopupOpen, isTrue);
    expect(find.text('def:日本語のテスト'), findsOneWidget);
  });

  testWidgets('hovering an annotated transcript word opens its definition', (
    tester,
  ) async {
    // The transcript line is rendered the way the video tab renders it:
    // with the reading annotations on, the kanji sits in an inline
    // widget and the plain text of the line holds only the object
    // replacement placeholder. The hover has to find the word in the
    // inline widget, not in the placeholder.
    await pumpPane(
      tester,
      tab: PlayerPaneTab.transcript,
      transcript: [(text: '日本語のテスト', start: Duration.zero)],
      inPopupScope: true,
      readingStyle: 'furigana',
      transcriptBuilder: (context, text, active) => AnnotatedLine(
        text: text,
        appState: context.read<AppState>(),
        fontSize: 12,
        weight: FontWeight.normal,
      ),
    );
    // the tokenizer resolves the reading asynchronously
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final controller = PopupDictionaryController.instance;
    controller.config = PopupDictionaryConfig(
      allowedScreens: {PopupScreenScope.video},
    );
    controller.currentRouteName = 'video';
    controller.lookupBuilder =
        (context, lookup) async => Directionality(
          textDirection: TextDirection.ltr,
          child: Text('def:${lookup.term}'),
        );
    controller.plainHoverEnabled = true;
    addTearDown(() {
      controller.plainHoverEnabled = false;
      controller.lookupBuilder = null;
      controller.currentRouteName = '';
    });

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    // the kanji is annotated: the reading sits above it in the same
    // inline widget, so the kanji's own box is the one to aim at
    final kanji = tester.getRect(find.text('日本語'));
    await gesture.moveTo(kanji.center);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isPopupOpen, isTrue);
    expect(find.text('def:日本語'), findsOneWidget);
  });
}
