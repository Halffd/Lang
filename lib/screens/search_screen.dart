import 'package:flutter/material.dart';
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
  
  @override
  Widget build(BuildContext context) {
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
    final dict = _searchResult!.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = _searchResult!.pitchAccents[pitchKey];
    final frequencies = _searchResult!.frequencies[pitchKey];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showEntryDetails(entry),
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
  
  void _showEntryDetails(DictionaryEntry entry) {
    final dict = _searchResult!.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = _searchResult!.pitchAccents[pitchKey];
    final frequencies = _searchResult!.frequencies[pitchKey];
    
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
          child: ListView(
            controller: scrollController,
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
                ...frequencies.map((freq) => 
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up),
                          const SizedBox(width: 12),
                          Text(
                            freq.displayValue ?? freq.value.toString(),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            freq.frequencyType,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
              const SizedBox(height: 12),
              ...entry.definitions.asMap().entries.map((defEntry) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${defEntry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatDefinition(defEntry.value),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Additional info
              if (entry.sequence != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Sequence: ${entry.sequence}',
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