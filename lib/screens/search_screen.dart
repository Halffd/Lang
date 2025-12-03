import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/dictionary_entry.dart';
import '../services/dictionary_service.dart';
import '../widgets/dictionary_entry_card.dart';
import '../widgets/search_bar_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = false;
  List<DictionaryEntry> _searchResults = [];
  String _currentQuery = '';
  
  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.currentQuery;
    
    // Perform initial search if there's a query
    if (appState.currentQuery.isNotEmpty) {
      _performSearch(appState.currentQuery);
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });
    
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setCurrentQuery(query);
    appState.addToSearchHistory(query);
    
    try {
      final dictionaryService = Provider.of<DictionaryService>(context, listen: false);
      final result = await dictionaryService.search(query, language: appState.language);
      
      setState(() {
        _searchResults = result.entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }
  
  void _handleClearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _currentQuery = '';
    });
    Provider.of<AppState>(context, listen: false).setCurrentQuery('');
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yomitan Search'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              _showSearchHistory(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBarWidget(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSearch: _performSearch,
              onClear: _handleClearSearch,
              automaticKanaConversion: appState.automaticKanaConversion,
            ),
          ),
          
          // Search options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Profile selector
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Profile',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: appState.currentProfile,
                    items: ['Default', 'Japanese', 'Study', 'Advanced']
                        .map((profile) => DropdownMenuItem(
                              value: profile,
                              child: Text(profile),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        appState.setCurrentProfile(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Clipboard monitor toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clipboard Monitor'),
                    Switch(
                      value: appState.clipboardMonitor,
                      onChanged: (value) {
                        appState.setClipboardMonitor(value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Automatic kana conversion toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Automatic Kana Conversion'),
                const Spacer(),
                Switch(
                  value: appState.automaticKanaConversion,
                  onChanged: (value) {
                    appState.setAutomaticKanaConversion(value);
                  },
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Search results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: _currentQuery.isEmpty
                            ? const Text('Enter a term to search')
                            : const Text('No results found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final entry = _searchResults[index];
                          return DictionaryEntryCard(
                            entry: entry,
                            isSaved: appState.savedWords.contains(entry.term),
                            isFavorite: appState.favoriteWords.contains(entry.term),
                            isInAnki: appState.ankiWords.contains(entry.term),
                            onSaveToggle: () {
                              if (appState.savedWords.contains(entry.term)) {
                                appState.removeSavedWord(entry.term);
                              } else {
                                appState.addSavedWord(
                                  entry.term,
                                  details: entry.toJson(),
                                );
                              }
                            },
                            onFavoriteToggle: () {
                              if (appState.favoriteWords.contains(entry.term)) {
                                appState.removeFavoriteWord(entry.term);
                              } else {
                                appState.addFavoriteWord(entry.term);
                              }
                            },
                            onAnkiToggle: () {
                              if (appState.ankiWords.contains(entry.term)) {
                                appState.removeAnkiWord(entry.term);
                              } else {
                                appState.addAnkiWord(entry.term);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  void _showSearchHistory(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Search History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Clear history functionality would be implemented here
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: appState.searchHistory.length,
                  itemBuilder: (context, index) {
                    final query = appState.searchHistory[index];
                    return ListTile(
                      title: Text(query),
                      leading: const Icon(Icons.history),
                      onTap: () {
                        _searchController.text = query;
                        _performSearch(query);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
