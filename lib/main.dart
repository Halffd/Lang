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
import 'presentation/providers/analyzer_provider.dart';
import 'presentation/providers/ai_provider.dart';
import 'presentation/providers/supabase_provider.dart';
import 'presentation/providers/srs_provider.dart';
import 'presentation/screens/analyze_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/saved_words_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/ai_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  final supabaseService = SupabaseService();
  final syncService = RealtimeSyncService();
  final storageService = StorageService();
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

  final analyzerProvider = AnalyzerProvider(repository);
  await analyzerProvider.init();

  final aiProvider = AiProvider(aiRepository);
  await aiProvider.init();

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
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1B1F),
        ),
        scaffoldBackgroundColor: const Color(0xFF1C1B1F),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1C1B1F),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
    const AiScreen(),
  ];

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
          NavigationDestination(icon: const Icon(Icons.auto_awesome), label: AppLocalizations.of(context)!.ai),
        ],
      ),
    );
  }
}