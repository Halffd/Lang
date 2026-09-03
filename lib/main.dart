import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/services/audio_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/srs_service.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/desktop_ipc_service.dart';
import 'data/datasources/ai_local_data_source.dart';
import 'data/datasources/ai_remote_data_source.dart';
import 'data/datasources/analysis_remote_data_source.dart';
import 'data/datasources/dictionary_local_data_source.dart';
import 'data/datasources/dictionary_remote_data_source.dart';
import 'data/datasources/kanji_remote_data_source.dart';
import 'data/datasources/note_local_data_source.dart';
import 'data/datasources/supabase_data_source.dart';
import 'data/repositories/ai_repository_impl.dart';
import 'data/repositories/analyzer_repository_impl.dart';
import 'data/repositories/srs_service.dart';
import 'domain/entities/app_state.dart';
import 'presentation/providers/analyzer_provider.dart';
import 'presentation/providers/ai_provider.dart';
import 'presentation/providers/supabase_provider.dart';
import 'presentation/providers/srs_provider.dart';
import 'presentation/screens/analyze_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/saved_words_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/ai_screen.dart';
import 'presentation/screens/browser_screen.dart';
import 'presentation/screens/srs_screen.dart';

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
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  final supabaseService = SupabaseService();
  final syncService = RealtimeSyncService();
  final storageService = StorageService();
  await storageService.init();
  SupabaseDataSource? supabaseDataSource;
  SrsService? srsServiceCore;
  SRSService? srsServiceLegacy;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await supabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);
      await supabaseService.signInAnonymously();
      supabaseDataSource = SupabaseDataSource(Supabase.instance.client);
      srsServiceCore = SrsService();
      syncService.connect();
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  final analysisRemoteDataSource = AnalysisRemoteDataSource();
  final dictionaryLocalDataSource = DictionaryLocalDataSource();
  final dictionaryRemoteDataSource = DictionaryRemoteDataSource();
  final kanjiRemoteDataSource = KanjiRemoteDataSource();
  final noteLocalDataSource = NoteLocalDataSource();
  final audioService = AudioService();
  final aiRemoteDataSource = AiRemoteDataSource();
  final aiLocalDataSource = AiLocalDataSource();

  final repository = AnalyzerRepositoryImpl(
    analysisRemoteDataSource: analysisRemoteDataSource,
    dictionaryLocalDataSource: dictionaryLocalDataSource,
    dictionaryRemoteDataSource: dictionaryRemoteDataSource,
    kanjiRemoteDataSource: kanjiRemoteDataSource,
    noteLocalDataSource: noteLocalDataSource,
    audioService: audioService,
  );

  final aiRepository = AiRepositoryImpl(
    remoteDataSource: aiRemoteDataSource,
    localDataSource: aiLocalDataSource,
  );

  final analyzerProvider = AnalyzerProvider();
  await analyzerProvider.init();

  final aiProvider = AiProvider(aiRepository);
  await aiProvider.init();

  final appState = AppState(storageService);

  srsServiceLegacy = SRSService(storageService);
  await srsServiceLegacy.initialize();

  SupabaseProvider? supabaseProvider;
  SrsProvider? srsProvider;

  if (supabaseDataSource != null && srsServiceCore != null) {
    supabaseProvider = SupabaseProvider(
      supabaseService: supabaseService,
      syncService: syncService,
      dataSource: supabaseDataSource,
    );
    srsProvider = SrsProvider(
      srsService: srsServiceCore,
      supabaseDataSource: supabaseDataSource,
      syncService: syncService,
    );
    await srsProvider.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: analyzerProvider),
        ChangeNotifierProvider.value(value: aiProvider),
        ChangeNotifierProvider.value(value: srsServiceLegacy),
        if (supabaseProvider != null) ChangeNotifierProvider.value(value: supabaseProvider),
        if (srsProvider != null) ChangeNotifierProvider.value(value: srsProvider),
      ],
      child: const LangApp(),
    ),
  );
}

class LangApp extends StatelessWidget {
  const LangApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF7C3AED);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(appState.language),
          debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
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
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(height: 1.5),
          bodyMedium: TextStyle(height: 1.4),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
          ),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2D2B33),
          selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          labelStyle: const TextStyle(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          height: 70,
          backgroundColor: const Color(0xFF1C1B1F),
          indicatorColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6));
            }
            return TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6));
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF2D2B33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF2D2B33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minLeadingWidth: 24,
        ),
        iconTheme: const IconThemeData(
          size: 22,
          color: Colors.white70,
        ),
      ),
      home: const MainNavigationShell(),
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
    const SavedWordsScreen(),
    const HistoryScreen(),
    const BrowserScreen(),
    const SRSScreen(),
    const AiScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupDesktopIPC();
  }

  void _setupDesktopIPC() {
    final desktopIPC = DesktopIPCService();
    if (!desktopIPC.isSupported) return;

    desktopIPC.onStudyRequested = () {
      if (mounted) setState(() => _currentIndex = 5);
    };
    desktopIPC.onBrowserRequested = () {
      if (mounted) setState(() => _currentIndex = 4);
    };
    desktopIPC.onQuitRequested = () {
      desktopIPC.dispose();
      exit(0);
    };

    desktopIPC.registerCommonHotkeys(
      onShowStudy: () { if (mounted) setState(() => _currentIndex = 5); },
      onShowBrowser: () { if (mounted) setState(() => _currentIndex = 4); },
      onToggleWindow: () { desktopIPC.toggleWindow(); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.analytics), label: AppLocalizations.of(context)!.analyze),
          NavigationDestination(icon: const Icon(Icons.search), label: AppLocalizations.of(context)!.search),
          NavigationDestination(icon: const Icon(Icons.bookmark), label: AppLocalizations.of(context)!.saved),
          NavigationDestination(icon: const Icon(Icons.history), label: AppLocalizations.of(context)!.history),
          NavigationDestination(icon: const Icon(Icons.language), label: 'Browser'),
          NavigationDestination(icon: const Icon(Icons.school), label: 'SRS'),
          NavigationDestination(icon: const Icon(Icons.auto_awesome), label: AppLocalizations.of(context)!.ai),
        ],
      ),
    );
  }
}