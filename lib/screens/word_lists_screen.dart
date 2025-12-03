import 'package:flutter/material.dart';
import '../mixins/word_list_mixins.dart';
import '../models/dictionary_entry.dart';
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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize storage service and load data
    _initializeData();
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

    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words.elementAt(index);
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
        );
      },
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
