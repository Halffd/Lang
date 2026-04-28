import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/dictionary.dart';
import '../../widgets/character_breakdown_widget.dart';
import '../../widgets/search/search_bar_widget.dart';
import '../../widgets/search/search_responsive_layout.dart';
import 'search_entry_details.dart';
import 'search_results_body.dart';

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _AddToKnownWordsIntent extends Intent {
  const _AddToKnownWordsIntent();
}

class _AddToFavoritesIntent extends Intent {
  const _AddToFavoritesIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ToggleNavIntent extends Intent {
  const _ToggleNavIntent();
}

class SearchScreenView extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final SearchResult? searchResult;
  final bool isSearching;
  final String lastQuery;
  final DictionaryEntry? selectedEntry;

  final bool showBreakdown;
  final List<CharacterInfo>? characterBreakdown;
  final String? breakdownWord;

  final Future<void> Function(String) onSubmitted;
  final Future<void> Function() onSearchPressed;
  final VoidCallback onClear;
  final VoidCallback onFocusSearch;

  final ValueChanged<DictionaryEntry> onEntrySelected;
  final ValueChanged<String> onShowCharacterBreakdown;
  final VoidCallback onCloseBreakdown;

  final VoidCallback onCopySelectedEntry;
  final VoidCallback onAddSelectedToKnownWords;
  final VoidCallback onToggleSelectedFavorite;
  final VoidCallback onDeleteSelectedEntry;
  final VoidCallback onToggleNavigationVisibility;

  const SearchScreenView({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResult,
    required this.isSearching,
    required this.lastQuery,
    required this.selectedEntry,
    required this.showBreakdown,
    required this.characterBreakdown,
    required this.breakdownWord,
    required this.onSubmitted,
    required this.onSearchPressed,
    required this.onClear,
    required this.onFocusSearch,
    required this.onEntrySelected,
    required this.onShowCharacterBreakdown,
    required this.onCloseBreakdown,
    required this.onCopySelectedEntry,
    required this.onAddSelectedToKnownWords,
    required this.onToggleSelectedFavorite,
    required this.onDeleteSelectedEntry,
    required this.onToggleNavigationVisibility,
  });

  Future<void> _launchExtendedSearch(BuildContext context, String query, String searchType) async {
    final encodedQuery = Uri.encodeComponent(query);
    String url;

    switch (searchType) {
      case 'wiktionary':
        url = 'https://ja.wiktionary.org/wiki/$encodedQuery';
        break;
      case 'wikipedia':
        url = 'https://ja.wikipedia.org/wiki/$encodedQuery';
        break;
      case 'wikimedia_images':
        url = 'https://commons.wikimedia.org/wiki/Special:Search?search=$encodedQuery';
        break;
      case 'google_images':
        url = 'https://www.google.com/search?q=$encodedQuery&tbm=isch';
        break;
      default:
        url = 'https://www.google.com/search?q=$encodedQuery';
    }

    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch search: $e')),
        );
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    final result = searchResult;
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (result == null) {
      return const _EmptyState();
    }

    if (result.entries.isEmpty && result.kanji.isEmpty) {
      return _NoResults(query: lastQuery);
    }

    final resultsList = SearchResultsList(
      result: result,
      selectedEntry: selectedEntry,
      currentSearchTerm: searchController.text,
      onEntryTap: (entry) => _showEntryDetails(context, entry),
      onEntryDoubleTap: (entry) => onShowCharacterBreakdown(entry.term),
      onKanjiDoubleTap: (kanjiChar) => onShowCharacterBreakdown(kanjiChar),
      onExternalSearchTypeSelected: (type) {
        final term = searchController.text.trim();
        if (term.isNotEmpty) {
          _launchExtendedSearch(context, term, type);
        }
      },
    );

    if (showBreakdown && characterBreakdown != null && breakdownWord != null) {
      return Column(
        children: [
          Expanded(child: resultsList),
          CharacterBreakdownWidget(
            characterInfos: characterBreakdown!,
            originalWord: breakdownWord!,
            onClose: onCloseBreakdown,
          ),
        ],
      );
    }

    return resultsList;
  }

  void _showEntryDetails(BuildContext context, DictionaryEntry entry) {
    onEntrySelected(entry);
    if (MediaQuery.of(context).size.width > 900) {
      return;
    }

    final result = searchResult;
    if (result == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SearchEntryDetailsContent(
            result: result,
            entry: entry,
            controller: scrollController,
            showCloseButton: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 900) {
          return Scaffold(
            appBar: AppBar(
              title: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search Japanese/Chinese/European languages...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onSubmitted: onSubmitted,
              ),
              actions: [
                if (searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async => onSearchPressed(),
                ),
              ],
            ),
            body: Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const _CopyIntent(),
                LogicalKeySet(LogicalKeyboardKey.enter): const _AddToKnownWordsIntent(),
                LogicalKeySet(LogicalKeyboardKey.backslash): const _AddToFavoritesIntent(),
                LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteIntent(),
                LogicalKeySet(LogicalKeyboardKey.space): const _FocusSearchIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH): const _ToggleNavIntent(),
              },
              child: Actions(
                actions: {
                  _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (intent) => onCopySelectedEntry()),
                  _AddToKnownWordsIntent:
                      CallbackAction<_AddToKnownWordsIntent>(onInvoke: (intent) => onAddSelectedToKnownWords()),
                  _AddToFavoritesIntent:
                      CallbackAction<_AddToFavoritesIntent>(onInvoke: (intent) => onToggleSelectedFavorite()),
                  _DeleteIntent: CallbackAction<_DeleteIntent>(onInvoke: (intent) => onDeleteSelectedEntry()),
                  _ToggleNavIntent:
                      CallbackAction<_ToggleNavIntent>(onInvoke: (intent) => onToggleNavigationVisibility()),
                  _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (intent) {
                    onFocusSearch();
                    return null;
                  }),
                },
                child: _buildBody(context),
              ),
            ),
          );
        }

        return KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (KeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent && selectedEntry != null) {
              onShowCharacterBreakdown(selectedEntry!.term);
            }
          },
          child: SearchResponsiveLayout(
            searchBar: SearchBarWidget(
              controller: searchController,
              onSubmitted: onSubmitted,
              hintText: 'Search Japanese/Chinese/European languages...',
              onClear: onClear,
              focusNode: searchFocusNode,
            ),
            resultsList: _buildBody(context),
            detailsPanel: (selectedEntry != null && searchResult != null)
                ? SearchEntryDetailsPanel(result: searchResult!, entry: selectedEntry!)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Select an entry to view details',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for Japanese/Chinese words',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;

  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results for \"$query\"',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
