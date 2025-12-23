import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'services/storage_service.dart';
import 'screens/dictionary_list_screen.dart';
import 'screens/search_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/word_lists_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sentence_translator_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(storageService)),
      ],
      child: const LangApp(),
    ),
  );
}

class LangApp extends StatelessWidget {
  const LangApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lang',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('ja'), // Japanese
        Locale('zh'), // Chinese
      ],
      locale: null, // Use system locale by default
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // Default to 0, but will be set based on app state
  bool _isNavBarVisible = true;

  final List<Widget> _screens = const [
    SearchScreen(),
    ReaderScreen(),
    WordListsScreen(),
    DictionaryListScreen(),
    SentenceTranslatorScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial index based on app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _currentIndex = appState.defaultScreenIndex; // 0-5 for the screens
      });
    });
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

    // Always show nav bar if auto-hide is disabled
    final shouldShowNavBar = !appState.autoHideNavigation || _isNavBarVisible;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _handleShortcut(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _handleShortcut(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _handleShortcut(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _handleShortcut(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => _handleShortcut(4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => _handleShortcut(5),
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
                  // Auto-show nav bar when mouse is near the top
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
