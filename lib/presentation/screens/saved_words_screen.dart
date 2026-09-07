import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/utils/srs_conversion_utils.dart';
import 'package:lang/presentation/widgets/dictionary_entry_card.dart';
import 'package:lang/utils/screen_size.dart';

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
        // Search bar and actions
        Padding(
          padding: ScreenSize.adaptivePadding(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (String action) {
                        if (action == 'add_all_to_srs') {
                          _addAllToSRS(context, appState);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'add_all_to_srs',
                          child: Row(
                            children: [
                              Icon(Icons.school, size: 18),
                              SizedBox(width: 8),
                              Text('Add all to SRS'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats summary
        Padding(
          padding: ScreenSize.adaptivePadding(context),
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
          padding: ScreenSize.adaptivePadding(context),
                        itemCount: filteredWords.length,
                        itemBuilder: (context, index) {
                          final word = filteredWords[index];
                          final details = appState.savedWordsDetails[word];

                          // Create a dictionary entry from saved details
                          final entry = details != null
                              ? DictionaryEntry.fromJson(details)
                              : DictionaryEntry.fromData(
                                  term: word,
                                  reading: '',
                                  definitions: ['No details available'],
                                );

                          return DictionaryEntryCard(
                            entry: entry,
                            isSaved: true,
                            isFavorite: appState.favoriteWords.contains(word),
                            isInAnki: appState.ankiWords.contains(word),
                            isInSRS: context.watch<SRSService>().allCards.any((card) => card.id == (word + (entry.reading))),
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
                            onSRSToggle: () {
                              final srsService = context.read<SRSService>();
                              if (context.read<SRSService>().allCards.any((card) => card.id == (word + (entry.reading)))) {
                                // Remove from SRS
                                srsService.removeCard(word + (entry.reading));
                              } else {
                                // Add to SRS
                                final srsCard = SRSConversionUtils.dictionaryEntryToSRSCard(entry);
                                srsService.addCard(srsCard);
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
          padding: ScreenSize.adaptivePadding(context),
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

  void _addAllToSRS(BuildContext context, AppState appState) async {
    final srsService = Provider.of<SRSService>(context, listen: false);
    final List<SRSCard> cardsToAdd = [];

    for (final word in appState.savedWords) {
      final details = appState.savedWordsDetails[word];
      if (details != null) {
        // Check if the card doesn't already exist in SRS
        final cardId = word + (details['reading'] ?? '');
        if (!srsService.allCards.any((card) => card.id == cardId)) {
          final entry = DictionaryEntry.fromJson(details);
          final srsCard = SRSConversionUtils.dictionaryEntryToSRSCard(entry);
          cardsToAdd.add(srsCard);
        }
      } else {
        // Create a basic card if no details are available
        final cardId = word;
        if (!srsService.allCards.any((card) => card.id == cardId)) {
          final srsCard = SRSCard.newCard(
            id: cardId,
            word: word,
            reading: '',
            meaning: 'No definition available',
          );
          cardsToAdd.add(srsCard);
        }
      }
    }

    if (cardsToAdd.isNotEmpty) {
      await srsService.bulkAddCards(cardsToAdd);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cardsToAdd.length} words added to SRS'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Implement undo functionality if needed
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new words to add to SRS')),
      );
    }
  }
}
