import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../mixins/word_list_mixins.dart';
import '../models/dictionary.dart';
import '../services/dictionary_service.dart';
import '../services/storage_service.dart';
import '../widgets/dictionary_entry_card.dart';

class WordListsScreen extends StatefulWidget {
  const WordListsScreen({super.key});

  @override
  State<WordListsScreen> createState() => _WordListsScreenState();
}

class _WordListsScreenState extends State<WordListsScreen>
    with SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin
    implements SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final StorageService _storageService = StorageService();
  List<DictionaryEntry> _searchResults = [];
  bool _isSearching = false;
  bool? _isFlexMode;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize storage service and load data
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFlexMode == null) {
      final appState = Provider.of<AppState>(context, listen: false);
      _isFlexMode = appState.defaultFlexMode;
    }
  }

  Future<void> _initializeData() async {
    await _storageService.init();
    await loadSavedWords();
    await loadDeletedWords();
    await loadAnkiWords();
    await loadFavoriteWords();
  }

  Future<void> _searchWord(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _dictionaryService.searchDictionary(query);
      // Filter out deleted words from results
      final filteredResults = results
          .where((entry) => !isWordDeleted(entry.word))
          .toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching for word')),
        );
      }
    }
  }

  Widget _buildWordList(Set<String> words, {required String emptyMessage}) {
    if (words.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final recentWords = words.toList().reversed.toList();

    if (_isFlexMode == true) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recentWords.map((word) {
            final isFav = isWordFavorite(word);
            return ActionChip(
              label: Text(word),
              avatar: isFav ? const Icon(Icons.favorite, size: 16, color: Colors.red) : null,
              onPressed: () {
                 // Show details or actions
                 _showWordActions(word);
              },
            );
          }).toList(),
        ),
      );
    }

    return ListView.builder(
      itemCount: recentWords.length,
      itemBuilder: (context, index) {
        final word = recentWords[index];
        return ListTile(
          title: Text(word),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isWordFavorite(word) ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
                onPressed: () => toggleFavoriteWord(word, isFavorite: !isWordFavorite(word)),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteConfirmation(word),
              ),
            ],
          ),
          onTap: () => _showWordActions(word),
        );
      },
    );
  }

  void _showWordActions(String word) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Definition'),
              onTap: () {
                Navigator.pop(context);
                _searchWord(word);
                DefaultTabController.of(context).animateTo(0); // Switch to Search tab
                _searchController.text = word;
              },
            ),
             ListTile(
              leading: Icon(isWordInAnki(word) ? Icons.remove_circle_outline : Icons.add_circle_outline),
              title: Text(isWordInAnki(word) ? 'Remove from Anki' : 'Add to Anki'),
              onTap: () {
                Navigator.pop(context);
                toggleAnkiWord(word, isAnki: !isWordInAnki(word));
              },
            ),
             ListTile(
              leading: Icon(isWordFavorite(word) ? Icons.favorite : Icons.favorite_border, color: Colors.red),
              title: Text(isWordFavorite(word) ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                toggleFavoriteWord(word, isFavorite: !isWordFavorite(word));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(word);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$word"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await deleteWord(word);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$word" has been deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Word Lists'),
          actions: [
            IconButton(
              icon: Icon((_isFlexMode ?? false) ? Icons.list : Icons.grid_view),
              tooltip: (_isFlexMode ?? false) ? 'Switch to List View' : 'Switch to Grid View',
              onPressed: () {
                setState(() {
                  _isFlexMode = !(_isFlexMode ?? false);
                });
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'Search'),
              Tab(text: 'Saved'),
              Tab(text: 'Favorites'),
              Tab(text: 'Anki'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Search Tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a word...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchWord(_searchController.text),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _searchWord,
                  ),
                ),
                if (_isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                  const Center(child: Text('No results found'))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final entry = _searchResults[index];
                        return DictionaryEntryCard(
                          entry: entry,
                          isSaved: isWordSaved(entry.word),
                          isFavorite: isWordFavorite(entry.word),
                          isInAnki: isWordInAnki(entry.word),
                          onSaveToggle: () => toggleSavedWord(entry.word, isSaved: !isWordSaved(entry.word)),
                          onFavoriteToggle: () => toggleFavoriteWord(entry.word, isFavorite: !isWordFavorite(entry.word)),
                          onAnkiToggle: () => toggleAnkiWord(entry.word, isAnki: !isWordInAnki(entry.word)),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // Saved Words Tab
            _buildWordList(
              savedWords,
              emptyMessage: 'No saved words yet. Search and save words to see them here!',
            ),

            // Favorites Tab
            _buildWordList(
              favoriteWords,
              emptyMessage: 'No favorite words yet. Mark words as favorite to see them here!',
            ),

            // Anki Words Tab
            _buildWordList(
              ankiWords,
              emptyMessage: 'No Anki words yet. Add words to Anki to see them here!',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
