import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/app_state.dart';
import '../../core/utils/word_list_mixins.dart';
import '../../../domain/entities/dictionary.dart';
import '../../data/repositories/dictionary_service.dart';
import '../../core/services/storage_service.dart';
import '../widgets/dictionary_entry_card.dart';
import '../providers/analyzer_provider.dart';

class WordListsScreen extends StatefulWidget {
  const WordListsScreen({super.key});

  @override
  State<WordListsScreen> createState() => _WordListsScreenState();
}

class _WordListsScreenState extends State<WordListsScreen>
    with SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin, SRSWordsMixin
    implements SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin, SRSWordsMixin {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  List<DictionaryEntry> _searchResults = [];
  bool _isSearching = false;
  bool? _isFlexMode;
  bool _isSentenceMode = false;
  int _sentenceColumns = 6;
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
    // Get the storage service from the app state instead of creating our own
    final appState = Provider.of<AppState>(context, listen: false);
    setStorageService(appState.storageService);
    await loadSavedWords();
    await loadDeletedWords();
    await loadAnkiWords();
    await loadFavoriteWords();
    await loadSRSWords();
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

  Widget _buildWordList(Set<String> words, {required String emptyMessage, bool showMoveButtons = false}) {
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
              avatar: isFav ? Icon(Icons.favorite, size: 16, color: Colors.red) : null,
              onPressed: () {
                 // Show details or actions
                 _showWordActions(word);
              },
            );
          }).toList(),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: recentWords.length,
      onReorder: (oldIndex, newIndex) {
        _onReorderWordList(recentWords, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final word = recentWords[index];
        return _buildWordTile(word, index, recentWords.length, showMoveButtons: showMoveButtons);
      },
    );
  }

  Widget _buildWordTile(String word, int index, int totalCount, {bool showMoveButtons = false}) {
    final isFav = isWordFavorite(word);
    final isSaved = isWordSaved(word);

    return Card(
      key: ValueKey(word),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(word),
        subtitle: Row(
          children: [
            if (isFav) Icon(Icons.favorite, size: 14, color: Colors.red[300]),
            if (isSaved) Icon(Icons.bookmark, size: 14, color: Colors.blue[300]),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 20),
              tooltip: isSaved ? 'Remove from saved' : 'Save word',
              onPressed: () => toggleSavedWord(word, isSaved: !isSaved),
            ),
            IconButton(
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 20),
              tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () => toggleFavoriteWord(word, isFavorite: !isFav),
            ),
            IconButton(
              icon: const Icon(Icons.content_copy, size: 20),
              tooltip: 'Copy word',
              onPressed: () => _copyWord(word),
            ),
            if (showMoveButtons) ...[
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'Move to first',
                onPressed: index > 0 ? () => _moveWordToPosition(word, 0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                tooltip: 'Move up',
                onPressed: index > 0 ? () => _moveWordUp(word) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                tooltip: 'Move down',
                onPressed: index < totalCount - 1 ? () => _moveWordDown(word) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Move to last',
                onPressed: index < totalCount - 1 ? () => _moveWordToPosition(word, totalCount - 1) : null,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              tooltip: 'Delete word',
              onPressed: () => _showDeleteConfirmation(word),
            ),
          ],
        ),
        onTap: () => _showWordActions(word),
      ),
    );
  }

  void _copyWord(String word) {
    // Implementation would use clipboard - placeholder for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "$word"'), duration: const Duration(seconds: 1)),
    );
  }

  void _onReorderWordList(List<String> words, int oldIndex, int newIndex) {
    // Handle reordering - implement persistence if needed
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = words.removeAt(oldIndex);
      words.insert(newIndex, item);
    });
  }

  void _moveWordUp(String word) {
    // Implement move up logic
    setState(() {});
  }

  void _moveWordDown(String word) {
    // Implement move down logic
    setState(() {});
  }

  void _moveWordToPosition(String word, int position) {
    // Implement move to position logic
    setState(() {});
  }

  Widget _buildHistoryList() {
    final history = context.read<AnalyzerProvider>().history;

    if (history.isEmpty) {
      return Center(
        child: Text(
          'No history yet. Look up words to see them here!',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final recentWords = history.toList().reversed.toList();

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
              avatar: isFav ? Icon(Icons.favorite, size: 16, color: Colors.red) : null,
              onPressed: () {
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
          leading: const Icon(Icons.history, size: 20, color: Colors.orange),
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

  Widget _buildSentenceWordGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth / _sentenceColumns) - 8;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchResults.map((entry) {
              return SizedBox(
                width: itemWidth,
                child: Card(
                  child: InkWell(
                    onTap: () => _showWordActions(entry.word),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.word,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entry.reading.isNotEmpty)
                            Text(
                              entry.reading,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
              leading: Icon(Icons.search),
              title: Text('Search Definition'),
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
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete'),
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
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$word"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
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
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
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
            tabs: [
              Tab(text: 'Search'),
              Tab(text: 'Saved'),
              Tab(text: 'Favorites'),
              Tab(text: 'History'),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a word...',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search),
                              onPressed: () => _searchWord(_searchController.text),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: _searchWord,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isSentenceMode ? Icons.view_week : Icons.notes,
                              color: _isSentenceMode ? Colors.blue : null,
                            ),
                            tooltip: _isSentenceMode ? 'Word Mode' : 'Sentence Mode',
                            onPressed: () {
                              setState(() {
                                _isSentenceMode = !_isSentenceMode;
                              });
                            },
                          ),
                          if (_isSentenceMode)
                            DropdownButton<int>(
                              value: _sentenceColumns,
                              items: [3, 4, 5, 6, 7, 8].map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n'),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _sentenceColumns = val;
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                  const Center(child: Text('No results found'))
                else if (_searchResults.isNotEmpty && _isSentenceMode)
                  Expanded(
                    child: _buildSentenceWordGrid(),
                  )
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
                          isInSRS: isWordInSRS(entry.word),
                          onSaveToggle: () => toggleSavedWord(entry.word, isSaved: !isWordSaved(entry.word)),
                          onFavoriteToggle: () => toggleFavoriteWord(entry.word, isFavorite: !isWordFavorite(entry.word)),
                          onAnkiToggle: () => toggleAnkiWord(entry.word, isAnki: !isWordInAnki(entry.word)),
                          onSRSToggle: () => toggleSRSWord(entry.word, isInSRS: !isWordInSRS(entry.word)),
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

            // History Tab
            _buildHistoryList(),

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
