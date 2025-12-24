import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kana_kit/kana_kit.dart';
import '../models/app_state.dart';
import '../models/dictionary.dart';
import '../models/etymology_model.dart';
import '../services/dictionary_service.dart';
import '../services/wiktionary_etymology_service.dart';
import '../utils/chinese_util.dart';
import '../utils/character_breakdown.dart';
import '../utils/json_html_renderer.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/character_breakdown_widget.dart';
import '../widgets/etymology_widget.dart';
import '../widgets/wiktionary_details_widget.dart';

// Define custom intent classes at top level
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);
  
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final TextEditingController _searchController = TextEditingController();
  final KanaKit _kanaKit = KanaKit();
  late FocusNode _searchFocusNode;

  SearchResult? _searchResult;
  bool _isSearching = false;
  String _lastQuery = '';
  DictionaryEntry? _selectedEntry;

  /// Check if text is mainly Latin characters (not Japanese)
  bool _isMainlyLatinText(String text) {
    if (text.isEmpty) return false;

    // Check if the text contains mostly Latin characters
    // Count Latin characters vs Japanese characters
    int latinCount = 0;
    int japaneseCount = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      if ((char >= 65 && char <= 122) || // A-Z, a-z
          (char >= 48 && char <= 57) || // 0-9
          char == 32 || // space
          char == 95 || // underscore
          (char >= 40 && char <= 47) || // punctuation
          (char >= 58 && char <= 64) ||
          (char >= 91 && char <= 96) ||
          (char >= 123 && char <= 126)) {
        latinCount++;
      } else if ((char >= 12353 && char <= 12438) || // Hiragana
          (char >= 12449 && char <= 12542) || // Katakana
          (char >= 19968 && char <= 40959)) { // Common Kanji range
        japaneseCount++;
      }
    }

    // If more than 50% are Latin characters, try conversion
    return latinCount > japaneseCount;
  }

  // For character breakdown functionality
  String? _breakdownWord;
  List<CharacterInfo>? _characterBreakdown;
  bool _showBreakdown = false;
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _lastQuery = '';
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });
    
    try {
      final result = await _dictionaryService.searchTerm(
        query,
        options: const SearchOptions(
          limit: 50,
          exactMatch: false,
          searchReadings: true,
        ),
      );
      
      setState(() {
        _searchResult = result;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  /// Launch external search in browser
  Future<void> _launchExtendedSearch(String query, String searchType) async {
    String encodedQuery = Uri.encodeComponent(query);
    String url = '';

    switch(searchType) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch search: $e')),
        );
      }
    }
  }

  /// Get the current search term for external search
  String get _currentSearchTerm {
    return _searchController.text;
  }

  Future<void> _launchExternalLink(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch url: $e')),
        );
      }
    }
  }

  Widget _buildExternalLinkButton(IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchExternalLink(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  void _showCharacterBreakdown(String word) {
    if (ChineseUtil.containsIdeographic(word)) {
      final breakdown = CharacterBreakdown.breakdownWithDetails(
        word,
        _searchResult?.entries ?? [],
        _searchResult?.kanji ?? [],
      );

      setState(() {
        _breakdownWord = word;
        _characterBreakdown = breakdown;
        _showBreakdown = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.space &&
            event is KeyDownEvent &&
            _selectedEntry != null) {
          _showCharacterBreakdown(_selectedEntry!.term);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout();
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Left Pane: Search and List
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Desktop Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search Japanese/Chinese...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResult = null;
                                  _lastQuery = '';
                                  _selectedEntry = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                // Results List
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
          // Vertical Divider
          const VerticalDivider(width: 1, thickness: 1),
          // Right Pane: Details
          Expanded(
            flex: 3,
            child: _selectedEntry != null
                ? _buildDetailPanel(_selectedEntry!)
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
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search Japanese/Chinese...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResult = null;
                  _lastQuery = '';
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final appState = Provider.of<AppState>(context, listen: false);
              String query = _searchController.text;

              // Auto-convert to Japanese if enabled and the text is mainly Latin
              if (appState.autoConvertJapanese && _isMainlyLatinText(query)) {
                try {
                  query = _kanaKit.toKana(query);
                } catch (e) {
                  // If conversion fails, use original text
                }
              }
              await _performSearch(query);
            },
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: {
          // Copy word to clipboard (Ctrl+C)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const _CopyIntent(),
          // Add to known words (Enter)
          LogicalKeySet(LogicalKeyboardKey.enter): const _AddToKnownWordsIntent(),
          // Add to favorites (\ key)
          LogicalKeySet(LogicalKeyboardKey.backslash): const _AddToFavoritesIntent(),
          // Delete word (Delete key)
          LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteIntent(),
          // Focus on search textbox (Space)
          LogicalKeySet(LogicalKeyboardKey.space): const _FocusSearchIntent(),
          // Toggle hide navigation bar (Ctrl+H)
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH): const _ToggleNavIntent(),
        },
        child: Actions(
          actions: {
            _CopyIntent: CallbackAction<_CopyIntent>(
              onInvoke: (intent) => _copySelectedEntry(),
            ),
            _AddToKnownWordsIntent: CallbackAction<_AddToKnownWordsIntent>(
              onInvoke: (intent) => _addSelectedEntryToKnownWords(),
            ),
            _AddToFavoritesIntent: CallbackAction<_AddToFavoritesIntent>(
              onInvoke: (intent) => _toggleSelectedEntryFavorite(),
            ),
            _DeleteIntent: CallbackAction<_DeleteIntent>(
              onInvoke: (intent) => _deleteSelectedEntry(),
            ),
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
              onInvoke: (intent) => _focusOnSearchBox(),
            ),
            _ToggleNavIntent: CallbackAction<_ToggleNavIntent>(
              onInvoke: (intent) => _toggleNavigationVisibility(),
            ),
          },
          child: _buildBody(),
        ),
      ),
    );
  }
  
  // Keyboard shortcut action methods
  void _copySelectedEntry() {
    if (_selectedEntry != null) {
      Clipboard.setData(ClipboardData(text: _selectedEntry!.term));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied: ${_selectedEntry!.term}')),
        );
      }
    }
  }

  void _addSelectedEntryToKnownWords() {
    if (_selectedEntry != null) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addSavedWord(_selectedEntry!.term, details: {
        'reading': _selectedEntry!.reading,
        'definitions': _selectedEntry!.definitions,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to known words: ${_selectedEntry!.term}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => appState.removeSavedWord(_selectedEntry!.term),
            ),
          ),
        );
      }
    }
  }

  void _toggleSelectedEntryFavorite() {
    if (_selectedEntry != null) {
      final appState = Provider.of<AppState>(context, listen: false);
      final isFavorite = appState.isWordFavorite(_selectedEntry!.term);
      appState.toggleFavoriteWord(_selectedEntry!.term, isFavorite: !isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFavorite ? 'Removed from' : 'Added to'} favorites: ${_selectedEntry!.term}'),
          ),
        );
      }
    }
  }

  void _deleteSelectedEntry() {
    if (_selectedEntry != null) {
      final appState = Provider.of<AppState>(context, listen: false);
      final deletedWord = _selectedEntry!.term;
      appState.deleteWord(deletedWord);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted word: $deletedWord'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Undo by removing from the deleted words list
                appState.undeleteWord(deletedWord);
              },
            ),
          ),
        );
      }
    }
  }

  void _focusOnSearchBox() {
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  void _toggleNavigationVisibility() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setAutoHideNavigation(!appState.autoHideNavigation);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation bar ${appState.autoHideNavigation ? 'will auto-hide' : 'will stay visible'}'),
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResult == null) {
      return _buildEmptyState();
    }

    if (_searchResult!.entries.isEmpty && _searchResult!.kanji.isEmpty) {
      return _buildNoResults();
    }

    // Show character breakdown if available
    if (_showBreakdown && _characterBreakdown != null && _breakdownWord != null) {
      return Column(
        children: [
          Expanded(
            child: _buildSearchResults(),
          ),
          CharacterBreakdownWidget(
            characterInfos: _characterBreakdown!,
            originalWord: _breakdownWord!,
            onClose: () {
              setState(() {
                _showBreakdown = false;
                _characterBreakdown = null;
                _breakdownWord = null;
              });
            },
          ),
        ],
      );
    }

    return _buildSearchResults();
  }
  
  Widget _buildEmptyState() {
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
  
  Widget _buildNoResults() {
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
            'No results for "$_lastQuery"',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults() {
    final result = _searchResult!;
    
    return ListView(
      children: [
        // Kanji results
        if (result.kanji.isNotEmpty) ...[
          _buildSectionHeader('Kanji', result.kanji.length),
          ...result.kanji.map((kanji) => _buildKanjiCard(kanji)),
          const Divider(height: 32, thickness: 2),
        ],
        
        // Entry results
        if (result.entries.isNotEmpty) ...[
          _buildSectionHeader('Entries', result.entries.length),
          ...result.entries.map((entry) => _buildEntryCard(entry)),
        ],

        // External search options
        if (result.entries.isNotEmpty || result.kanji.isNotEmpty) ...[
          _buildExternalSearchSection(),
        ],
      ],
    );
  }
  
  Widget _buildExternalSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'External Search',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildExternalSearchButton('Wiktionary', Icons.book_outlined, 'wiktionary'),
                  _buildExternalSearchButton('Wikipedia', Icons.public, 'wikipedia'),
                  _buildExternalSearchButton('Images', Icons.image, 'google_images'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalSearchButton(String label, IconData icon, String searchType) {
    return ElevatedButton.icon(
      onPressed: () {
        if (_currentSearchTerm.isNotEmpty) {
          _launchExtendedSearch(_currentSearchTerm, searchType);
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildKanjiCard(KanjiEntry kanji) {
    final dict = _searchResult!.dictionaries[kanji.dictionaryId];

    return GestureDetector(
      onDoubleTap: () {
        // For single kanji characters, provide breakdown too (though it will just be the same character)
        _showCharacterBreakdown(kanji.character);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    kanji.character,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (dict != null)
                    Chip(
                      label: Text(
                        dict.title,
                        style: const TextStyle(fontSize: 10),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (kanji.onyomi != null && kanji.onyomi!.isNotEmpty) ...[
                const Text(
                  '音読み (On\'yomi)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: kanji.onyomi!.map((reading) =>
                    Chip(
                      label: Text(reading),
                      backgroundColor: Colors.blue[50],
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 12),
              ],

              if (kanji.kunyomi != null && kanji.kunyomi!.isNotEmpty) ...[
                const Text(
                  '訓読み (Kun\'yomi)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: kanji.kunyomi!.map((reading) =>
                    Chip(
                      label: Text(reading),
                      backgroundColor: Colors.green[50],
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Tone information for Chinese characters
              if (ChineseUtil.containsChinese(kanji.character)) ...[
                // Find tone information for this character
                if (_searchResult!.toneInfo['${kanji.character}_'] != null ||
                    // Try with the character name in the search result
                    _searchResult!.toneInfo.entries.any((entry) =>
                        entry.key.startsWith('${kanji.character}_'))) ...[
                  const Text(
                    'Tones',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final entry in _searchResult!.toneInfo.entries)
                    if (entry.key.startsWith('${kanji.character}_'))
                      for (final toneInfo in entry.value)
                        for (final pattern in toneInfo.tones)
                          Row(
                            children: [
                              Icon(Icons.hearing, size: 14, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                '${toneInfo.language.toUpperCase()} ${pattern.getToneName(toneInfo.language)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                  const SizedBox(height: 8),
                ],
              ],

              const Text(
                'Meanings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...kanji.meanings.asMap().entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${entry.key + 1}. ${entry.value}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEntryCard(DictionaryEntry entry) {
    final appState = Provider.of<AppState>(context);
    final dict = _searchResult!.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = _searchResult!.pitchAccents[pitchKey];
    final frequencies = _searchResult!.frequencies[pitchKey];
    final isSelected = _selectedEntry == entry;

    return GestureDetector(
      onDoubleTap: () {
        _showCharacterBreakdown(entry.term);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: isSelected ? 4 : 1,
        shape: isSelected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              )
            : null,
        child: InkWell(
          onTap: () => _showEntryDetails(entry),
          borderRadius: isSelected ? BorderRadius.circular(12) : BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.term,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (entry.reading.isNotEmpty && entry.reading != entry.term)
                            Text(
                              entry.reading,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (dict != null)
                      Chip(
                        label: Text(
                          dict.title,
                          style: const TextStyle(fontSize: 10),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (appState.ankiWords.contains(entry.term))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.star, color: Colors.orange, size: 20),
                      ),
                    if (appState.favoriteWords.contains(entry.term))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.favorite, color: Colors.red, size: 20),
                      ),
                    if (appState.savedWords.contains(entry.term))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.bookmark, color: Theme.of(context).primaryColor, size: 20),
                      ),
                  ],
                ),

                // Tags
                if (entry.termTags != null && entry.termTags!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.termTags!.map((tagName) {
                      final tag = _searchResult!.tags['${entry.dictionaryId}_$tagName'];
                      return Chip(
                        label: Text(
                          tag?.notes ?? tagName,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: _getTagColor(tag?.category),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],

                // Pitch accent
                if (pitches != null && pitches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Pitch: ${pitches.map((p) => p.pitches.map((pp) => pp.position).join(", ")).join(" / ")}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],

                // Tone information for Chinese characters
                if (_searchResult!.toneInfo[pitchKey] != null &&
                    _searchResult!.toneInfo[pitchKey]!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.hearing, size: 16),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final toneInfo in _searchResult!.toneInfo[pitchKey]!)
                            for (final tonePattern in toneInfo.tones)
                              Text(
                                '${toneInfo.language.toUpperCase()} ${tonePattern.getToneName(toneInfo.language)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ],

                // Frequency
                if (frequencies != null && frequencies.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Frequency: ${frequencies.first.displayValue}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],

                // Etymology preview in main card
                if (_searchResult!.etymology[pitchKey]?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  for (final etymologyEntry in _searchResult!.etymology[pitchKey]!.take(1)) // Show only the first etymology entry in card
                    Row(
                      children: [
                        Icon(Icons.history, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Etymology: ${etymologyEntry.originalLanguage}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],

                // Wiktionary preview in main card
                if (_searchResult!.wiktionaryDetails[pitchKey]?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  for (final wiktionaryEntry in _searchResult!.wiktionaryDetails[pitchKey]!.take(1)) // Show only the first entry in card
                    Row(
                      children: [
                        Icon(Icons.menu_book, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${wiktionaryEntry.partOfSpeech.isNotEmpty ? '${wiktionaryEntry.partOfSpeech}: ' : ''}${wiktionaryEntry.definition.length > 60 ? '${wiktionaryEntry.definition.substring(0, 60)}...' : wiktionaryEntry.definition}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Definitions (first 2)
                ...List.generate(entry.definitions.take(2).length, (index) {
                  final definition = entry.definitions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${index + 1}. ${_formatDefinition(definition)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),

                if (entry.definitions.length > 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+ ${entry.definitions.length - 2} more definitions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailPanel(DictionaryEntry entry) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _buildDetailContent(entry),
    );
  }

  void _showEntryDetails(DictionaryEntry entry) {
    if (MediaQuery.of(context).size.width > 900) {
      setState(() {
        _selectedEntry = entry;
      });
    } else {
      _showMobileEntryDetails(entry);
    }
  }

  void _showMobileEntryDetails(DictionaryEntry entry) {
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
          child: _buildDetailContent(entry, controller: scrollController, showCloseButton: true),
        ),
      ),
    );
  }

  Widget _buildDetailContent(DictionaryEntry entry, {ScrollController? controller, bool showCloseButton = false}) {
    final dict = _searchResult!.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = _searchResult!.pitchAccents[pitchKey];
    final frequencies = _searchResult!.frequencies[pitchKey];

    final appState = Provider.of<AppState>(context, listen: false);
    final isSaved = appState.savedWords.contains(entry.term);
    final isFavorite = appState.favoriteWords.contains(entry.term);
    final isAnki = appState.ankiWords.contains(entry.term);

    return ListView(
      controller: controller,
      padding: showCloseButton ? EdgeInsets.zero : const EdgeInsets.all(24),
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.term,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entry.reading.isNotEmpty && entry.reading != entry.term)
                    Text(
                      entry.reading,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                  color: isSaved ? Theme.of(context).primaryColor : null,
                  tooltip: isSaved ? 'Remove from Saved' : 'Save',
                  onPressed: () => isSaved 
                      ? appState.removeSavedWord(entry.term) 
                      : appState.addSavedWord(entry.term, details: entry.toJson()),
                ),
                IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                  color: isFavorite ? Colors.red : null,
                  tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  onPressed: () => isFavorite 
                      ? appState.removeFavoriteWord(entry.term) 
                      : appState.addFavoriteWord(entry.term),
                ),
                IconButton(
                  icon: Icon(isAnki ? Icons.star : Icons.star_border),
                  color: isAnki ? Colors.orange : null,
                  tooltip: isAnki ? 'Remove from Anki' : 'Add to Anki',
                  onPressed: () => isAnki 
                      ? appState.removeAnkiWord(entry.term) 
                      : appState.addAnkiWord(entry.term),
                ),
              ],
            ),
            if (showCloseButton)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Dictionary source
        if (dict != null)
          Chip(
            label: Text('Source: ${dict.title}'),
            avatar: const Icon(Icons.book, size: 16),
          ),
        
        const SizedBox(height: 16),

        // External Links
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildExternalLinkButton(
              Icons.image,
              'Images',
              'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(entry.term)}',
            ),
            _buildExternalLinkButton(
              Icons.language,
              'Wikipedia',
              'https://ja.wikipedia.org/wiki/${Uri.encodeComponent(entry.term)}',
            ),
            _buildExternalLinkButton(
              Icons.menu_book,
              'Wiktionary',
              'https://ja.wiktionary.org/wiki/${Uri.encodeComponent(entry.term)}',
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Tags
        if (entry.termTags != null && entry.termTags!.isNotEmpty) ...[
          const Text(
            'Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.termTags!.map((tagName) {
              final tag = _searchResult!.tags['${entry.dictionaryId}_$tagName'];
              return Chip(
                label: Text(tag?.notes ?? tagName),
                backgroundColor: _getTagColor(tag?.category),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // Pitch accent
        if (pitches != null && pitches.isNotEmpty) ...[
          const Text(
            'Pitch Accent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...pitches.expand((pitch) =>
            pitch.pitches.map((pattern) =>
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq),
                      const SizedBox(width: 12),
                      Text(
                        'Downstep: ${pattern.position}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (pattern.tags != null) ...[
                        const Spacer(),
                        Text(
                          pattern.tags!.join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Tone information for Chinese characters
        if (_searchResult!.toneInfo[pitchKey] != null &&
            _searchResult!.toneInfo[pitchKey]!.isNotEmpty) ...[
          const Text(
            'Tones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._searchResult!.toneInfo[pitchKey]!.expand((toneInfo) =>
            toneInfo.tones.map((pattern) =>
              Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.hearing, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${toneInfo.language.toUpperCase()} Tone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pattern.position + 1}. ${pattern.getToneName(toneInfo.language)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (pattern.romanization != null)
                              Text(
                                'Reading: ${pattern.romanization}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Frequency
        if (frequencies != null && frequencies.isNotEmpty) ...[
          const Text(
            'Frequency',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...frequencies.map((freq) {
            final freqDict = _searchResult!.dictionaries[freq.dictionaryId];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up),
                    const SizedBox(width: 12),
                    Text(
                      '${freqDict?.title ?? "Unknown"}: ${freq.displayValue ?? freq.value}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Etymology
        if (_searchResult!.etymology[pitchKey]?.isNotEmpty == true) ...[
          EtymologyWidget(
            etymologyEntries: _searchResult!.etymology[pitchKey]!,
            word: entry.term,
          ),
        ],

        // Wiktionary details (meanings, examples, synonyms, etc.)
        if (_searchResult!.wiktionaryDetails[pitchKey]?.isNotEmpty == true) ...[
          WiktionaryDetailsWidget(
            wiktionaryEntries: _searchResult!.wiktionaryDetails[pitchKey]!,
            word: entry.term,
          ),
        ],

        // Definitions
        const Text(
          'Definitions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...entry.definitions.asMap().entries.map((defEntry) {
          final index = defEntry.key;
          final definition = defEntry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDefinition(definition),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Color? _getTagColor(String? category) {
    switch (category) {
      case 'partOfSpeech':
        return Colors.blue[50];
      case 'name':
        return Colors.green[50];
      case 'expression':
        return Colors.orange[50];
      case 'popular':
        return Colors.purple[50];
      default:
        return Colors.grey[200];
    }
  }
  
  String _extractPlainTextFromStructuredContent(String definition) {
    // Check if it's JSON (structured content)
    if (definition.startsWith('{') || definition.startsWith('[')) {
      try {
        final dynamic jsonContent = jsonDecode(definition);
        // Extract plain text from the structured content
        return _extractTextFromJson(jsonContent);
      } catch (e) {
        // If it's not valid JSON, return as is
        return definition;
      }
    }
    return definition;
  }

  String _extractTextFromJson(dynamic content) {
    if (content == null) {
      return '';
    }

    if (content is String) {
      return content;
    }

    if (content is List) {
      return content.map(_extractTextFromJson).join(' ');
    }

    if (content is Map<String, dynamic>) {
      final result = <String>[];

      // Add content field if it exists
      if (content['content'] != null) {
        result.add(_extractTextFromJson(content['content']));
      }

      // Add text field if it exists
      if (content['text'] != null) {
        result.add(_extractTextFromJson(content['text']));
      }

      // Add title field if it exists
      if (content['title'] != null) {
        result.add(_extractTextFromJson(content['title']));
      }

      return result.where((s) => s.isNotEmpty).join(' ');
    }

    return content.toString();
  }

  String _formatDefinition(String definition) {
    // Check if it's JSON (structured content)
    if (definition.startsWith('{') || definition.startsWith('[')) {
      try {
        // For structured content, extract plain text for display in simple Text widgets
        return _extractPlainTextFromStructuredContent(definition);
      } catch (e) {
        return definition;
      }
    }
    return definition;
  }
}