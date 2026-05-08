import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analyzer_provider.dart';
import '../widgets/word_detail_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sentenceController = TextEditingController();
  bool _isSentenceMode = false;
  int _columnCount = 6;

  @override
  void dispose() {
    _searchController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSentenceMode ? 'Sentence Mode' : 'Search Dictionary'),
        actions: [
          _buildModeToggle(theme),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isSentenceMode) _buildSentenceInput(theme, provider) else _buildSearchInput(theme, provider),
            const SizedBox(height: 16),
            if (_isSentenceMode)
              Expanded(child: _buildSentenceWordGrid(theme, provider))
            else
              Expanded(child: _buildSearchResults(theme, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isSentenceMode ? Icons.view_column : Icons.search,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Switch(
          value: _isSentenceMode,
          onChanged: (val) => setState(() => _isSentenceMode = val),
        ),
        const SizedBox(width: 8),
        if (_isSentenceMode) _buildColumnCountSelector(theme),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildColumnCountSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _columnCount,
          isDense: true,
          items: [3, 4, 5, 6, 7, 8, 9, 10].map((n) => DropdownMenuItem(
            value: n,
            child: Text('$n', style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _columnCount = val);
          },
        ),
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme, AnalyzerProvider provider) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search for a word...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: _searchController,
          builder: (context, value, child) {
            return _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : const SizedBox.shrink();
          },
        ),
      ),
      onSubmitted: (query) => provider.searchWord(query),
    );
  }

  Widget _buildSentenceInput(ThemeData theme, AnalyzerProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _sentenceController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter a sentence to split into words...',
              prefixIcon: const Icon(Icons.text_fields),
              suffixIcon: ValueListenableBuilder(
                valueListenable: _sentenceController,
                builder: (context, value, child) {
                  return _sentenceController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _sentenceController.clear(),
                      )
                    : const SizedBox.shrink();
                },
              ),
            ),
            onSubmitted: (_) => provider.searchWord(_sentenceController.text),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            if (_sentenceController.text.isNotEmpty) {
              provider.searchWord(_sentenceController.text);
            }
          },
          child: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme, AnalyzerProvider provider) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Type something to search' : 'No results found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final word = provider.searchResults[index];
        return Card(
          child: ListTile(
            title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Freq: ${word.frequency ?? "?"}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => WordDetailSheet.show(context, provider, word),
          ),
        );
      },
    );
  }

  Widget _buildSentenceWordGrid(ThemeData theme, AnalyzerProvider provider) {
    if (_sentenceController.text.isEmpty) {
      return Center(
        child: Text(
          'Enter a sentence above to split into words',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    final words = _parseWords(_sentenceController.text);

    if (words.isEmpty) {
      return const Center(child: Text('No words found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${words.length} words in $_columnCount columns',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: _WordGrid(
            words: words,
            columns: _columnCount,
            onWordTap: (word) => _handleWordTap(context, provider, word),
          ),
        ),
      ],
    );
  }

  List<String> _parseWords(String text) {
    return text
        .split(RegExp(r'[\s\n]+', multiLine: true))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !RegExp(r'^[^\w\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]+$').hasMatch(w))
        .toList();
  }

  void _handleWordTap(BuildContext context, AnalyzerProvider provider, String word) {
    provider.searchWord(word);
    _showWordDetail(context, provider, word);
  }

  void _showWordDetail(BuildContext context, AnalyzerProvider provider, String word) {
    final match = provider.searchResults.where((w) => w.word == word).firstOrNull;
    if (match != null) {
      WordDetailSheet.show(context, provider, match);
    } else {
      provider.searchWord(word);
    }
  }
}

class _WordGrid extends StatelessWidget {
  final List<String> words;
  final int columns;
  final void Function(String) onWordTap;

  const _WordGrid({
    required this.words,
    required this.columns,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        final itemHeight = 60.0;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words.map((word) {
            return _WordCard(
              word: word,
              width: itemWidth.clamp(60.0, 150.0),
              height: itemHeight,
              onTap: () => onWordTap(word),
            );
          }).toList(),
        );
      },
    );
  }
}

class _WordCard extends StatelessWidget {
  final String word;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _WordCard({
    required this.word,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                word,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}