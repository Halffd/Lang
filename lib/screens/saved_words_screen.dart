import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/dictionary_entry.dart';
import '../widgets/dictionary_entry_card.dart';

class SavedWordsScreen extends StatefulWidget {
  const SavedWordsScreen({super.key});

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filterSavedWords(List<String> words) {
    if (_searchQuery.isEmpty) {
      return words;
    }
    return words.where((word) => word.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final filteredWords = _filterSavedWords(appState.savedWords);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Words'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortOptions(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search saved words',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${filteredWords.length} words',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_searchQuery.isNotEmpty)
                  Text(
                    'Filtered from ${appState.savedWords.length} total',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Saved words list
          Expanded(
            child: appState.savedWords.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No saved words yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Words you save will appear here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : filteredWords.isEmpty
                    ? Center(
                        child: Text('No words matching "$_searchQuery"'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = filteredWords[index];
                          final details = appState.savedWordsDetails[word];

                          // Create a dictionary entry from saved details
                          final entry = details != null
                              ? DictionaryEntry.fromJson(details)
                              : DictionaryEntry(
                                  term: word,
                                  reading: '',
                                  definitions: ['No details available'],
                                );

                          return DictionaryEntryCard(
                            entry: entry,
                            isSaved: true,
                            isFavorite: appState.favoriteWords.contains(word),
                            isInAnki: appState.ankiWords.contains(word),
                            onSaveToggle: () {
                              appState.removeSavedWord(word);
                            },
                            onFavoriteToggle: () {
                              if (appState.favoriteWords.contains(word)) {
                                appState.removeFavoriteWord(word);
                              } else {
                                appState.addFavoriteWord(word);
                              }
                            },
                            onAnkiToggle: () {
                              if (appState.ankiWords.contains(word)) {
                                appState.removeAnkiWord(word);
                              } else {
                                appState.addAnkiWord(word);
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

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Date Added (Newest First)'),
                onTap: () {
                  // Implement sorting logic
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_filled),
                title: const Text('Date Added (Oldest First)'),
                onTap: () {
                  // Implement sorting logic
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Alphabetical (A-Z)'),
                onTap: () {
                  // Implement sorting logic
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Alphabetical (Z-A)'),
                onTap: () {
                  // Implement sorting logic
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Frequency'),
                onTap: () {
                  // Implement sorting logic
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
