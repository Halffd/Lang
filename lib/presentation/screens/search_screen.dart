import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
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
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.search),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.clearSearch();
                      },
                    )
                  : null,
              ),
              onSubmitted: (query) => provider.searchWord(query),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (provider.isSearching)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: provider.searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty ? AppLocalizations.of(context)!.noResultsYet : AppLocalizations.of(context)!.noResultsYet,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.searchResults.length,
                      itemBuilder: (context, index) {
                        final word = provider.searchResults[index];
                        return Card(
                          child: ListTile(
                            title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(AppLocalizations.of(context)!.frequency(int.tryParse(word.frequency?.toString() ?? '') ?? 0)),
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
