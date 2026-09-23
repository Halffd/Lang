import 'dart:async';
import 'dart:io';
import 'package:lang/utils/layout_config.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'l10n/app_localizations.dart';
import 'presentation/widgets/structured_definition.dart';
import 'utils/font_scale.dart';
import 'utils/japanese_grammar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/services/clipboard_monitor_service.dart';
import 'core/services/history_service.dart';
import 'core/services/popup_dictionary_controller.dart';
import 'core/services/screenshot_service.dart';
import 'core/services/supabase_service.dart';
import 'data/services/ocr_service.dart';
import 'data/services/anki_connect_service.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/desktop_ipc_service.dart';
import 'data/datasources/ai_local_data_source.dart';
import 'data/datasources/ai_remote_data_source.dart';
import 'data/repositories/ai_repository_impl.dart';
import 'data/repositories/srs_service.dart';
import 'domain/entities/dictionary.dart' show YomichanSearchResult;
import 'domain/entities/app_state.dart';
import 'domain/entities/popup_dictionary_config.dart';
import 'presentation/providers/analyzer_provider.dart';
import 'presentation/screens/analyze_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/saved_words_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/ai_screen.dart';
import 'presentation/screens/reader_screen.dart';
import 'presentation/screens/srs_screen.dart';
import 'presentation/screens/study_screen.dart';
import 'presentation/screens/dictionary_screen.dart';
import 'presentation/screens/writer_screen.dart';
import 'presentation/providers/ai_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'data/datasources/supabase_data_source.dart';
import 'core/services/srs_service.dart' as srs_core;
import 'presentation/providers/srs_provider.dart';
import 'presentation/providers/supabase_provider.dart';
import 'presentation/providers/user_profile_provider.dart';
import 'presentation/providers/user_data_provider.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/widgets/user_badge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final desktopIPC = DesktopIPCService();
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    await desktopIPC.initialize();
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  final supabaseService = SupabaseService();
  final syncService = RealtimeSyncService();
  final storageService = StorageService();
  await storageService.init();
  SRSService? srsServiceLegacy;
  SupabaseDataSource? supabaseDataSource;
  srs_core.SrsService? srsServiceCore;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await supabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);
      await supabaseService.signInAnonymously();
      supabaseDataSource = SupabaseDataSource(Supabase.instance.client);
      srsServiceCore = srs_core.SrsService();
      syncService.connect();
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  final aiRemoteDataSource = AiRemoteDataSource();
  final aiLocalDataSource = AiLocalDataSource();

  final aiRepository = AiRepositoryImpl(
    remoteDataSource: aiRemoteDataSource,
    localDataSource: aiLocalDataSource,
  );

  final appState = AppState(storageService);

  final analyzerProvider = AnalyzerProvider();
  await analyzerProvider.init();
  // Sync provider learning language with persisted preference
  analyzerProvider.appState = appState;
  analyzerProvider.restoreLanguage(appState.learningLanguage);

  // Feed layout settings into the shared LayoutConfig so every widget sees
  // them without needing Provider.
  _syncLayout(appState);
  appState.addListener(() => _syncLayout(appState));

  // Clipboard history: record copied text in the activity feed
  await HistoryService.instance.load();
  final clipboardMonitor = ClipboardMonitorService.instance;
  // auto search mode: search copied text automatically
  clipboardMonitor.onClipboardChanged = (text) {
    analyzerProvider.searchWord(text);
  };
  // auto OCR for clipboard images: recognize then search
  final ocrService = OcrService();
  await ocrService.initialize();
  clipboardMonitor.onClipboardImage = (imageBytes) async {
    try {
      final result = await ocrService.recognizeFromBytes(
        imageBytes,
        engine: OcrEngine.mlKit,
      );
      if (result.isSuccess) return result.text;
      return null;
    } catch (_) {
      return null;
    }
  };
  // popup dictionary: global yomichan-style lookup on any screen
  _setupPopupDictionary(appState, analyzerProvider);

  clipboardMonitor.startMonitoring(appState);
  // restart monitor when clipboard settings change
  appState.addListener(() {
    clipboardMonitor.restartMonitoring(appState);
  });

  // screenshots: restore registry, restart auto capture on its saved
  // interval, register global hotkeys for each capture kind
  await ScreenshotService.instance.load();

  Future<String?> ocrRunner(String path) async {
    try {
      // honor the persisted OCR engine choice; ai falls back to
      // mlKit here since the AI provider isn't wired into hotkeys
      var engine = OcrService.engineFromName(appState.ocrEngine);
      if (engine == OcrEngine.ai) engine = OcrEngine.mlKit;
      if (appState.ocrApiEndpoint.isNotEmpty) {
        ocrService.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await ocrService.recognizeFromFile(
        path,
        engine: engine,
        language: appState.learningLanguage,
        apiKey: appState.ocrApiKey,
      );
      return result.isSuccess ? result.text : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> runAutoOcr(ScreenshotItem item) async {
    if (!appState.screenshotAutoOcr) return;
    try {
      final text = await ocrRunner(item.path);
      if (text != null && text.trim().isNotEmpty) {
        ScreenshotService.instance.setOcrText(item.id, text.trim());
        if (appState.screenshotCopyOcrText) {
          await Clipboard.setData(ClipboardData(text: text.trim()));
        }
      }
    } catch (_) {
      // auto OCR is best-effort
    }
  }

  Future<void> copyImageRunner(String path) async {
    final bytes = await File(path).readAsBytes();
    final item = DataWriterItem(suggestedName: 'screenshot.png');
    item.add(Formats.png(bytes));
    await ClipboardWriter.instance.write([item]);
  }

  Future<void> copyTextRunner(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  if (appState.screenshotAutoIntervalMin > 0) {
    ScreenshotService.instance.startAutoCapture(
      intervalMinutes: appState.screenshotAutoIntervalMin,
      onCaptured: runAutoOcr,
    );
  }
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    Future<void> captureHotkey(ScreenshotKind kind) async {
      final item = await ScreenshotService.instance.captureWithPipeline(
        kind,
        autoOcr: appState.screenshotAutoOcr,
        copyOcrText: appState.screenshotCopyOcrText,
        copyImage: appState.screenshotCopyImage,
        ocrRunner: ocrRunner,
        copyImageRunner: copyImageRunner,
        copyTextRunner: copyTextRunner,
      );
      if (item != null) {
        await desktopIPC.showNotification(
          title: 'Screenshot',
          body: 'Captured ${kind.name}',
        );
      }
    }

    desktopIPC.registerScreenshotHotkeys(
      onFullscreen: () => captureHotkey(ScreenshotKind.fullscreen),
      onMonitor: () => captureHotkey(ScreenshotKind.monitor),
      onWindow: () => captureHotkey(ScreenshotKind.window),
      onRegion: () => captureHotkey(ScreenshotKind.region),
      onPreviousRegion: () => captureHotkey(ScreenshotKind.previousRegion),
      onToggleAuto: () async {
        // toggle between off and the saved interval (1 min default)
        final current = appState.screenshotAutoIntervalMin;
        final next = current > 0 ? 0 : 1;
        appState.setScreenshotAutoIntervalMin(next);
        if (next > 0) {
          ScreenshotService.instance.startAutoCapture(
            intervalMinutes: next,
            onCaptured: runAutoOcr,
          );
        } else {
          ScreenshotService.instance.stopAutoCapture();
        }
      },
    );
  }

  final aiProvider = AiProvider(aiRepository);
  await aiProvider.init();

  srsServiceLegacy = SRSService(storageService);
  await srsServiceLegacy.initialize();

  SupabaseProvider? supabaseProvider;
  SrsProvider? srsProvider;
  UserDataProvider? userDataProvider;
  final userProfileProvider = UserProfileProvider(
    ds: supabaseDataSource,
    syncService: syncService,
  );
  if (supabaseDataSource != null && srsServiceCore != null) {
    supabaseProvider = SupabaseProvider(
      supabaseService: supabaseService,
      syncService: syncService,
    );
    srsProvider = SrsProvider(
      srsService: srsServiceCore,
      supabaseDataSource: supabaseDataSource,
      syncService: syncService,
    );
    await srsProvider.init();
    userDataProvider = UserDataProvider(dataSource: supabaseDataSource);

    // Auto-sync saved words on startup and on local changes (debounced).
    void pushPulledWords(List<Map<String, dynamic>> rows) {
      for (final r in rows) {
        final w = r['word'] as String?;
        if (w != null) appState.addSavedWord(w, details: r);
      }
    }

    Future<void> runSync() async {
      final words = <Map<String, dynamic>>[
        for (final w in appState.savedWords)
          <String, dynamic>{'word': w, ...?appState.savedWordsDetails[w]},
      ];
      final missing = await userDataProvider!.syncSavedWords(words);
      pushPulledWords(missing);
    }

    // Initial sync, then debounce on saved-words changes.
    unawaited(runSync());
    Timer? debounce;
    int lastWordsLen = appState.savedWords.length;
    appState.addListener(() {
      final len = appState.savedWords.length;
      if (len != lastWordsLen) {
        lastWordsLen = len;
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 5), runSync);
      }
    });

    // Realtime: when another device writes a saved word, pull it down.
    syncService.onSavedWordsChange((table, newRow, oldRow) {
      if (newRow != null) {
        final w = newRow['word'] as String?;
        if (w != null && !appState.savedWords.contains(w)) {
          appState.addSavedWord(w, details: newRow);
        }
      }
    });

    // Realtime: history items recorded on another device add themselves to
    // the local history feed.
    syncService.onSeenWordsChange((table, newRow, oldRow) {
      final word = newRow?['word'] as String?;
      if (word != null &&
          word.isNotEmpty &&
          !HistoryService.instance.items.any(
            (i) => i.category == HistoryCategory.word && i.title == word,
          )) {
        HistoryService.instance.record(
          HistoryCategory.word,
          word,
          subtitle: 'synced',
        );
      }
    });
  }

  // profile loads from local prefs + pulls from Supabase when available
  await userProfileProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: analyzerProvider),
        ChangeNotifierProvider.value(value: aiProvider),
        ChangeNotifierProvider.value(value: srsServiceLegacy),
        ChangeNotifierProvider.value(value: userProfileProvider),
        if (supabaseProvider != null)
          ChangeNotifierProvider.value(value: supabaseProvider),
        if (srsProvider != null)
          ChangeNotifierProvider.value(value: srsProvider),
        if (userDataProvider != null)
          ChangeNotifierProvider.value(value: userDataProvider),
      ],
      child: const LangApp(),
    ),
  );
}

/// Feed AppState layout settings into the global LayoutConfig.
void _syncLayout(AppState a) {
  LayoutConfig.instance.update(
    mode: switch (a.layoutMode) {
      'mobile' => LayoutMode.mobile,
      'tablet' => LayoutMode.tablet,
      'desktop' => LayoutMode.desktop,
      'centered' => LayoutMode.centered,
      _ => LayoutMode.auto,
    },
    paddingScale: a.paddingScale,
    marginScale: a.marginScale,
    borderRadiusScale: a.borderRadiusScale,
    borderWidthScale: a.borderWidthScale,
    contentMaxWidth: a.contentMaxWidth,
    contentHeightFraction: a.contentHeightFraction,
  );
}

/// Wire the global popup dictionary: config from app state,
/// lookup through the shared analyzer pipeline (yomichan lookup +
/// dictionary settings filtering), auto-anki + auto-copy actions.
void _setupPopupDictionary(AppState appState, AnalyzerProvider analyzer) {
  final controller = PopupDictionaryController.instance;
  controller.config = appState.popupDictionaryConfig;
  controller.currentLearningLanguage = appState.learningLanguage;
  controller.activeProfileName = appState.currentProfile;

  // profile alternation: follow the active SRS profile name
  appState.addListener(() {
    controller.updateConfig(appState.popupDictionaryConfig);
    controller.currentLearningLanguage = appState.learningLanguage;
    controller.activeProfileName = appState.currentProfile;
  });

  // modifier keys feed the shift/ctrl/alt/meta hover triggers
  HardwareKeyboard.instance.addHandler((event) {
    final map = <PhysicalKeyboardKey, PopupExtraModifier>{
      PhysicalKeyboardKey.shiftLeft: PopupExtraModifier.shift,
      PhysicalKeyboardKey.shiftRight: PopupExtraModifier.shift,
      PhysicalKeyboardKey.controlLeft: PopupExtraModifier.ctrl,
      PhysicalKeyboardKey.controlRight: PopupExtraModifier.ctrl,
      PhysicalKeyboardKey.altLeft: PopupExtraModifier.alt,
      PhysicalKeyboardKey.altRight: PopupExtraModifier.alt,
      PhysicalKeyboardKey.metaLeft: PopupExtraModifier.meta,
      PhysicalKeyboardKey.metaRight: PopupExtraModifier.meta,
    };
    for (final entry in map.entries) {
      if (event.physicalKey == entry.key) {
        controller.onModifierKey(event is KeyDownEvent, entry.value);
        // hover triggers need the current position re-evaluated;
        // the next hover event handles that
        break;
      }
    }
    return false;
  });

  controller.lookupBuilder = (context, lookup) async {
    final config = controller.config;
    final candidates = JapaneseGrammar.popupLookupCandidates(
      lookup.term,
      detectCompounds: config.detectCompounds,
      detectConjugations: config.detectConjugations,
    );
    for (final candidate in candidates) {
      final results = await analyzer.lookupWordDirect(candidate);
      if (results.isEmpty) continue;
      if (results.firstOrNull == null) continue;

      final result = results.first;
      return _PopupDictionaryBody(
        result: result,
        sentence: lookup.sentence,
        onAnki: () async {
          final config = controller.config;
          if (!config.autoAnki) return;
          try {
            final anki = AnkiConnectService();
            final deck = config.ankiDeck.isEmpty
                ? 'Lang Popup'
                : config.ankiDeck;
            await anki.addNote(
              deckName: deck,
              modelName: 'Lang Popup Note',
              fields: {
                'Word': result.entry.term,
                'Reading': result.entry.reading,
                'Meaning': result.entry.definitions.take(3).join('; '),
                'Sentence': lookup.sentence,
              },
            );
          } catch (_) {
            // anki is best-effort
          }
        },
      );
    }
    return null;
  };
}

/// Compact popup body for a dictionary result.
class _PopupDictionaryBody extends StatefulWidget {
  final YomichanSearchResult result;
  final String sentence;
  final VoidCallback onAnki;

  const _PopupDictionaryBody({
    required this.result,
    required this.sentence,
    required this.onAnki,
  });

  @override
  State<_PopupDictionaryBody> createState() => _PopupDictionaryBodyState();
}

class _PopupDictionaryBodyState extends State<_PopupDictionaryBody> {
  @override
  void initState() {
    super.initState();
    // fire-and-forget: auto-anki runs once when the popup is shown
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onAnki());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final entry = result.entry;
    final popupConfig = PopupDictionaryController.instance.config;
    final fontScale = popupConfig.fontScale.clamp(0.5, 2.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.term,
                style: TextStyle(
                  fontSize: fs(context, 20, 'kanji') * fontScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (popupConfig.showReading && entry.reading.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  entry.reading,
                  style: TextStyle(
                    fontSize: fs(context, 12, 'words') * fontScale,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
        if (entry.definitions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Flexible(
            child: SingleChildScrollView(
              child: StructuredDefinition(
                definition: entry.definitions.first,
                fontSize: (12 * fontScale).roundToDouble(),
              ),
            ),
          ),
        ],
        if (popupConfig.showSentence && widget.sentence.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fs(context, 10, 'ui') * fontScale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class LangApp extends StatelessWidget {
  const LangApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF7C3AED);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Map the user's language preference to a locale we have UI
        // translations for (en, es, ja, zh). Falls back to English.
        final uiLocale = switch (appState.language) {
          'ja' => const Locale('ja'),
          'zh' => const Locale('zh'),
          'es' => const Locale('es'),
          _ => const Locale('en'),
        };
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: uiLocale,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF1C1B1F),
                ).copyWith(
                  primary: const Color(0xFF8B5CF6),
                  secondary: const Color(0xFFA78BFA),
                  tertiary: const Color(0xFF06B6D4),
                  surfaceContainerHighest: const Color(0xFF2D2B33),
                ),
            scaffoldBackgroundColor: const Color(0xFF1C1B1F),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              headlineMedium: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              titleLarge: TextStyle(fontWeight: FontWeight.w600),
              titleMedium: TextStyle(fontWeight: FontWeight.w500),
              bodyLarge: TextStyle(height: 1.5),
              bodyMedium: TextStyle(height: 1.4),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              color: const Color(0xFF2D2B33),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Color(0xFF1C1B1F),
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2D2B33),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              labelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              elevation: 2,
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              elevation: 0,
              height: 70,
              backgroundColor: const Color(0xFF1C1B1F),
              indicatorColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B5CF6),
                  );
                }
                return TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                );
              }),
            ),
            dividerTheme: DividerThemeData(
              color: Colors.white.withValues(alpha: 0.08),
              thickness: 1,
              space: 1,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF2D2B33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            listTileTheme: const ListTileThemeData(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minLeadingWidth: 24,
            ),
            iconTheme: const IconThemeData(size: 22, color: Colors.white70),
          ),
          home: const PopupDictionaryScope(child: MainNavigationShell()),
          // When layout mode is 'centered', wrap every route's scaffold in
          // a width/height-capped surface centered on the screen.
          // Other modes: unchanged.
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return ScreenSize.maybeCenter(context, child);
          },
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const AnalyzeScreen(),
    const SearchScreen(),
    const ReaderScreen(),
    const DictionaryScreen(),
    const WriterScreen(),
    const SavedWordsScreen(),
    const HistoryScreen(),
    const SRSScreen(),
    const AiScreen(),
    const StudyScreen(),
  ];

  /// Route names for the popup dictionary screen scope filter.
  static const _routeNames = [
    'analyze',
    'search',
    'reader',
    'dictionary',
    'writer',
    'saved',
    'history',
    'srs',
    'ai',
    'study',
  ];

  @override
  void initState() {
    super.initState();
    // open on the configured default screen
    final saved = context.read<AppState>().defaultScreenIndex;
    if (saved >= 0 && saved < _screens.length) _currentIndex = saved;
    _syncPopupRoute(_currentIndex);
    _setupDesktopIPC();
  }

  void _syncPopupRoute(int index) {
    final controller = PopupDictionaryController.instance;
    // hide popups that belong to the previous screen
    controller.onRouteChanged();
    controller.currentRouteName = (index >= 0 && index < _routeNames.length)
        ? _routeNames[index]
        : '';
  }

  void _setupDesktopIPC() {
    final desktopIPC = DesktopIPCService();
    if (!desktopIPC.isSupported) return;

    desktopIPC.onStudyRequested = () {
      if (mounted) setState(() => _currentIndex = 7);
      _syncPopupRoute(7);
    };
    desktopIPC.onReaderRequested = () {
      if (mounted) setState(() => _currentIndex = 2);
      _syncPopupRoute(2);
    };
    desktopIPC.onQuitRequested = () {
      desktopIPC.dispose();
      exit(0);
    };

    desktopIPC.registerCommonHotkeys(
      onShowStudy: () {
        if (mounted) setState(() => _currentIndex = 7);
        _syncPopupRoute(7);
      },
      onShowReader: () {
        if (mounted) setState(() => _currentIndex = 2);
        _syncPopupRoute(2);
      },
      onToggleWindow: () {
        desktopIPC.toggleWindow();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: const UserBadge(),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              // open settings screen via route if exposed, else push
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _syncPopupRoute(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.analytics),
            label: AppLocalizations.of(context)!.analyze,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: AppLocalizations.of(context)!.search,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book),
            label: AppLocalizations.of(context)!.reader,
          ),
          NavigationDestination(
            icon: const Icon(Icons.sort_by_alpha),
            label: AppLocalizations.of(context)!.dictionaries,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_note),
            label: AppLocalizations.of(context)!.writerTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark),
            label: AppLocalizations.of(context)!.saved,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: AppLocalizations.of(context)!.history,
          ),
          NavigationDestination(icon: const Icon(Icons.school), label: 'SRS'),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome),
            label: AppLocalizations.of(context)!.ai,
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_play),
            label: 'Study',
          ),
        ],
      ),
    );
  }
}
