import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_state.dart';
import '../models/dictionary.dart';
import '../services/dictionary_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);
  
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final TextEditingController _searchController = TextEditingController();
  
  SearchResult? _searchResult;
  bool _isSearching = false;
  String _lastQuery = '';
  DictionaryEntry? _selectedEntry;
  
  @override
  void dispose() {
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
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
                      hintText: 'Search Japanese...',
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
            hintText: 'Search Japanese...',
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
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
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
            'Search for Japanese words',
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
      ],
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
    
    return Card(
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
    );
  }
  
  Widget _buildEntryCard(DictionaryEntry entry) {
    final appState = Provider.of<AppState>(context);
    final dict = _searchResult!.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = _searchResult!.pitchAccents[pitchKey];
    final frequencies = _searchResult!.frequencies[pitchKey];
    final isSelected = _selectedEntry == entry;
    
    return Card(
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
  
  String _formatDefinition(String definition) {
    // Check if it's JSON (structured content)
    if (definition.startsWith('{') || definition.startsWith('[')) {
      try {
        // For now, just return plain text
        // In production, you'd render HTML from structured content
        return definition;
      } catch (e) {
        return definition;
      }
    }
    return definition;
  }
}