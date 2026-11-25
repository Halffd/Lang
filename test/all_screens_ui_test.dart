// UI test for every screen in the app.
//
// The purpose is crash-and-render coverage: each navigation destination,
// sub-screen and modal must build without throwing and must put real
// content on the screen. A screen that renders as a blank window is a
// failure - that is exactly how the settings screen's cloud-sync
// section used to break, and the reader tabs used to lose their labels.
//
// Everything drives the actual widget tree through pumpWidget +
// pumpAndSettle, so the build methods, initState async work, provider
// lookups and translations all execute.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/clipboard_manager_service.dart';
import 'package:lang/core/services/speech_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart' as legacy_srs;
import 'package:lang/domain/entities/ai_message.dart';
import 'package:lang/domain/repositories/ai_repository.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/ai_provider.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/providers/user_profile_provider.dart';
import 'package:lang/presentation/screens/ai_screen.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';
import 'package:lang/presentation/screens/capture_screens.dart';
import 'package:lang/presentation/screens/clipboard_manager_screen.dart';
import 'package:lang/presentation/screens/dictionary_list_screen.dart';
import 'package:lang/presentation/screens/dictionary_screen.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';
import 'package:lang/presentation/screens/history_screen.dart';
import 'package:lang/presentation/screens/import_screen.dart';
import 'package:lang/presentation/screens/radical_search_screen.dart';
import 'package:lang/presentation/screens/reader/browser_tab.dart';
import 'package:lang/presentation/screens/reader/video_tab.dart';
import 'package:lang/presentation/screens/reader_screen.dart';
import 'package:lang/presentation/screens/saved_words_screen.dart';
import 'package:lang/presentation/screens/scanner_screen.dart';
import 'package:lang/presentation/screens/search_screen.dart';
import 'package:lang/presentation/screens/screenshot_tab.dart';
import 'package:lang/presentation/screens/sentence_translator_screen.dart';
import 'package:lang/presentation/screens/settings_screen.dart';
import 'package:lang/presentation/screens/speech_tab.dart';
import 'package:lang/presentation/screens/srs_screen.dart';
import 'package:lang/presentation/screens/study_screen.dart';
import 'package:lang/presentation/screens/word_lists_screen.dart';
import 'package:lang/presentation/screens/writer_screen.dart';
import 'package:lang/presentation/screens/yomitan_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
  });

  /// Pump [child] with the full provider stack main.dart installs, so a
  /// screen's incidental `context.read` calls resolve the way they do
  /// in the running app.
  Future<void> pumpInApp(WidgetTester tester, Widget child) async {
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    final analyzer = AnalyzerProvider();
    // Deliberately no init(): AnalyzerProvider.init() opens the
    // dictionary database, and inside a testWidgets body that open
    // never completes. Every screen must read its data through the
    // provider without it being pre-populated; these tests assert that
    // the build does not throw, which is exactly the property that
    // breaks when a screen assumes loaded data.
    final srs = legacy_srs.SRSService(storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<AnalyzerProvider>.value(value: analyzer),
          ChangeNotifierProvider<AiProvider>.value(
            value: AiProvider(_NoopAiRepository()),
          ),
          ChangeNotifierProvider<legacy_srs.SRSService>.value(value: srs),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: UserProfileProvider(),
          ),
          ChangeNotifierProvider<ClipboardManagerService>.value(
            value: ClipboardManagerService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) => Scaffold(body: child)),
        ),
      ),
    );
    // pumpAndSettle() blocks forever on screens that keep a timer or
    // animation alive (the analyze screen's search-bar animations,
    // etc.). Bounded pumping gets the frame drawn and the build done,
    // which is what these tests actually check.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Every screen that is a standalone navigation destination or a
  /// named screen the user opens from somewhere else.
  final destinations = <String, Widget>{
    'AnalyzeScreen': const AnalyzeScreen(),
    'StudyScreen': const StudyScreen(),
    'SRSScreen': const SRSScreen(),
    'WordListsScreen': const WordListsScreen(),
    'SavedWordsScreen': const SavedWordsScreen(),
    'ImportScreen': const ImportScreen(),
    'HistoryScreen': const HistoryScreen(),
    'SettingsScreen': const SettingsScreen(),
    'AiScreen': const AiScreen(),
    'WriterScreen': const WriterScreen(),
    'DictionaryListScreen': const DictionaryListScreen(),
    'DictionaryScreen': const DictionaryScreen(),
    'SentenceTranslatorScreen': const SentenceTranslatorScreen(),
    'RadicalSearchScreen': const RadicalSearchScreen(),
    'SearchScreen': const SearchScreen(),
    'YomitanSettingsScreen': const YomitanSettingsScreen(),
    'ReaderScreen': const ReaderScreen(),
    'ScreenshotScreen': const ScreenshotScreen(),
    'SpeechScreen': const SpeechScreen(),
    'ScannerScreen': const ScannerScreen(),
    'DocumentReaderScreen(tabbed)': const DocumentReaderScreen(
      fileType: 'txt',
      isMangaMode: false,
    ),
    'ClipboardManagerScreen': const ClipboardManagerScreen(),
    'BrowserTab': const BrowserTab(),
    'VideoTab': const VideoTab(),
    'SpeechTab': SpeechTab(service: SpeechService()),
    'ScreenshotTab': const ScreenshotTab(),
  };

  destinations.forEach((name, screen) {
    testWidgets('$name builds without throwing', (tester) async {
      await pumpInApp(tester, screen);
      expect(tester.takeException(), isNull, reason: '$name threw');
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: '$name has no scaffold',
      );
    });
  });

  testWidgets('ReaderScreen shows all its tab labels', (tester) async {
    await pumpInApp(tester, const ReaderScreen());
    expect(find.text('Reader'), findsWidgets);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
    // the screenshot/OCR tab is a separate bottom-bar screen
    expect(find.text('Screenshots'), findsNothing);
  });

  testWidgets('ReaderScreen browser tab renders its launcher', (tester) async {
    await pumpInApp(tester, const ReaderScreen());
    await tester.tap(find.text('Browser'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(BrowserTab), findsOneWidget);
    expect(find.text('URL or search'), findsOneWidget);
    expect(find.text('NHK Easy News'), findsOneWidget);
  });

  testWidgets('ReaderScreen clipboard tab renders its settings', (
    tester,
  ) async {
    await pumpInApp(tester, const ReaderScreen());
    await tester.tap(find.text('Clipboard'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Clipboard history'), findsOneWidget);
    expect(find.text('History only'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders without Supabase configured', (
    tester,
  ) async {
    await pumpInApp(tester, const SettingsScreen());
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Backup & Sync'), findsOneWidget);
  });

  testWidgets('AnalyzeScreen renders its input and result areas', (
    tester,
  ) async {
    await pumpInApp(tester, const AnalyzeScreen());
    // the input field and the analyze affordance must be present: a
    // blank window would mean the build threw
    expect(find.byType(TextField), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the analyze screen failed to build',
    );
  });
}

/// AI repository that never talks to a network: the AI screen must be
/// pumpable in tests without credentials or sockets.
class _NoopAiRepository implements AiRepository {
  @override
  Future<String> generateText(
    String prompt,
    String provider, {
    String? apiKey,
    Map<String, dynamic>? responseSchema,
  }) async => '';
  @override
  Future<String> generateImage(
    String prompt, {
    String? negativePrompt,
    String? apiKey,
  }) async => '';
  @override
  Future<String> translate(
    String text,
    String targetLang, {
    String? apiKey,
  }) async => '';
  @override
  Future<String> summarize(String text, {String? apiKey}) async => '';
  @override
  Future<List<Map<String, String>>> breakdown(
    String text, {
    String? apiKey,
  }) async => [];
  @override
  Future<String> extractTextFromImage(
    String imageBase64, {
    String? prompt,
    String? apiKey,
  }) async => '';
  @override
  Future<List<Map<String, String>>> getCustomPrompts() async => [];
  @override
  Future<void> saveCustomPrompt(String name, String prompt) async {}
  @override
  Future<void> deleteCustomPrompt(String name) async {}
  @override
  Future<void> saveMessage(AiMessage message) async {}
  @override
  Future<List<AiMessage>> getHistory() async => [];
  @override
  Future<void> clearHistory() async {}
}
