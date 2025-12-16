import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'services/storage_service.dart';
import 'screens/dictionary_list_screen.dart';
import 'screens/search_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/word_lists_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(storageService)),
      ],
      child: const YomichanApp(),
    ),
  );
}

class YomichanApp extends StatelessWidget {
  const YomichanApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yomichan Dictionary',
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
  int _currentIndex = 0;
  bool _isNavBarVisible = true;
  
  final List<Widget> _screens = const [
    SearchScreen(),
    ReaderScreen(),
    WordListsScreen(),
    DictionaryListScreen(),
    SettingsScreen(),
  ];

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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: MouseRegion(
            onHover: (event) {
              if (!appState.autoHideNavigation) return;
              final screenHeight = MediaQuery.of(context).size.height;
              final isNearBottom = event.position.dy > screenHeight - 80;
              if (isNearBottom != _isNavBarVisible) {
                setState(() => _isNavBarVisible = isNearBottom);
              }
            },
            child: _screens[_currentIndex],
          ),
          bottomNavigationBar: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: shouldShowNavBar ? Offset.zero : const Offset(0, 1),
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
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
