import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'domain/entities/app_state.dart';
import 'domain/entities/srs_card.dart';
import 'core/services/storage_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/clipboard_monitor_service.dart';
import 'data/repositories/srs_service.dart';
import 'data/repositories/analyzer_repository_impl.dart';
import 'data/datasources/analysis_remote_data_source.dart';
import 'data/datasources/dictionary_local_data_source.dart';
import 'data/datasources/dictionary_remote_data_source.dart';
import 'data/datasources/kanji_remote_data_source.dart';
import 'data/datasources/note_local_data_source.dart';
import 'presentation/providers/analyzer_provider.dart';
import 'presentation/screens/dictionary_list_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/reader_screen.dart';
import 'presentation/screens/word_lists_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/sentence_translator_screen.dart';
import 'presentation/screens/srs_screen.dart';
import 'presentation/screens/radical_search_screen.dart';
import 'l10n/app_localizations.dart';
import 'presentation/widgets/gesture_zoom_wrapper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    databaseFactory = databaseFactoryFfi;
  }

  final storageService = StorageService();
  await storageService.init();
  final srsService = SRSService(storageService);
  await srsService.initialize();

  final analyzerRepository = AnalyzerRepositoryImpl(
    analysisRemoteDataSource: AnalysisRemoteDataSource(),
    dictionaryLocalDataSource: DictionaryLocalDataSource(),
    dictionaryRemoteDataSource: DictionaryRemoteDataSource(),
    kanjiRemoteDataSource: KanjiRemoteDataSource(),
    noteLocalDataSource: NoteLocalDataSource(),
    audioService: AudioService(),
  );
  final analyzerProvider = AnalyzerProvider(analyzerRepository);
  await analyzerProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(storageService)),
        ChangeNotifierProvider.value(value: srsService),
        ChangeNotifierProvider.value(value: analyzerProvider),
      ],
      child: const LangApp(),
    ),
  );
}

class LangApp extends StatelessWidget {
  const LangApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Lang',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('ja'),
            Locale('zh'),
          ],
          locale: null,
          themeMode: appState.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          builder: (context, child) {
            // Apply zoom and font size multiplier to the entire app
            Widget appContent = Transform.scale(
              scale: appState.zoomLevel,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: appState.fontSizeMultiplier,
                ),
                child: child ?? const SizedBox(), // Handle nullable child
              ),
            );

            // Add gesture detection for pinch-to-zoom and keyboard shortcuts on mobile only
            return Platform.isIOS || Platform.isAndroid
                ? GestureZoomWrapper(
                    child: appContent,
                  )
                : appContent;
          },
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isNavBarVisible = true;
  final ClipboardMonitorService _clipboardMonitorService = ClipboardMonitorService();

  final List<Widget> _screens = const [
    SearchScreen(),
    ReaderScreen(),
    WordListsScreen(),
    DictionaryListScreen(),
    SentenceTranslatorScreen(),
    RadicalSearchScreen(),
    SRSScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Set up clipboard change callback
    _clipboardMonitorService.onClipboardChanged = (String content) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setCurrentQuery(content);
    };

    // Set initial index based on app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _currentIndex = appState.defaultScreenIndex.clamp(0, _screens.length - 1);
      });

      if (appState.clipboardMonitor) {
        _clipboardMonitorService.startMonitoring(appState);
      }
    });
  }

  @override
  void dispose() {
    _clipboardMonitorService.stopMonitoring();
    super.dispose();
  }

  void _handleShortcut(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (_clipboardMonitorService.isMonitoring != appState.clipboardMonitor) {
      if (appState.clipboardMonitor) {
        _clipboardMonitorService.startMonitoring(appState);
      } else {
        _clipboardMonitorService.stopMonitoring();
      }
    }

    final shouldShowNavBar = !appState.autoHideNavigation || _isNavBarVisible;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _handleShortcut(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _handleShortcut(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _handleShortcut(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _handleShortcut(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => _handleShortcut(4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => _handleShortcut(5),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true): () => _handleShortcut(6),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true): () => _handleShortcut(7),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: shouldShowNavBar ? 1.0 : 0.0,
              child: MouseRegion(
                onHover: (event) {
                  if (!appState.autoHideNavigation) return;
                  final screenHeight = MediaQuery.of(context).size.height;
                  final isNearTop = event.position.dy < 60;
                  if (isNearTop != _isNavBarVisible) {
                    setState(() => _isNavBarVisible = isNearTop);
                  }
                },
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.article),
                      label: 'Reader',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list),
                      label: 'Lists',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.book),
                      label: 'Dictionaries',
                    ),
        NavigationDestination(
          icon: Icon(Icons.translate),
          label: 'Translator',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view),
          label: 'Radicals',
        ),
        NavigationDestination(
          icon: Icon(Icons.school),
          label: 'SRS',
        ),
                    NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _screens[_currentIndex],
        ),
      ),
    );
  }
}
