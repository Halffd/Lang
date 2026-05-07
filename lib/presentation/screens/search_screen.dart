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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Dictionary'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
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
            ),
            const SizedBox(height: 16),
            if (provider.isSearching)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: provider.searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty ? 'Type something to search' : 'No results found',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
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
                    ),
              ),
          ],
        ),
      ),
    );
  }
}