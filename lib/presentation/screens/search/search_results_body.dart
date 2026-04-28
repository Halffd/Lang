import 'package:flutter/material.dart';

import '../../../domain/entities/dictionary.dart';
import 'search_result_cards.dart';

class SearchResultsList extends StatelessWidget {
  final SearchResult result;
  final DictionaryEntry? selectedEntry;
  final String currentSearchTerm;
  final ValueChanged<DictionaryEntry> onEntryTap;
  final ValueChanged<DictionaryEntry> onEntryDoubleTap;
  final ValueChanged<String> onKanjiDoubleTap;
  final ValueChanged<String> onExternalSearchTypeSelected;

  const SearchResultsList({
    super.key,
    required this.result,
    required this.selectedEntry,
    required this.currentSearchTerm,
    required this.onEntryTap,
    required this.onEntryDoubleTap,
    required this.onKanjiDoubleTap,
    required this.onExternalSearchTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (result.kanji.isNotEmpty) ...[
          _SectionHeader(title: 'Kanji', count: result.kanji.length),
          ...result.kanji.map(
            (kanji) => SearchKanjiCard(kanji: kanji, result: result, onDoubleTap: onKanjiDoubleTap),
          ),
          const Divider(height: 32, thickness: 2),
        ],
        if (result.entries.isNotEmpty) ...[
          _SectionHeader(title: 'Entries', count: result.entries.length),
          ...result.entries.map(
            (entry) => SearchEntryCard(
              entry: entry,
              result: result,
              isSelected: selectedEntry == entry,
              onTap: onEntryTap,
              onDoubleTap: onEntryDoubleTap,
            ),
          ),
        ],
        if (result.entries.isNotEmpty || result.kanji.isNotEmpty) ...[
          _ExternalSearchSection(
            onExternalSearchTypeSelected: onExternalSearchTypeSelected,
            isEnabled: currentSearchTerm.trim().isNotEmpty,
          ),
        ],
      ],
    );
  }
}

class _ExternalSearchSection extends StatelessWidget {
  final ValueChanged<String> onExternalSearchTypeSelected;
  final bool isEnabled;

  const _ExternalSearchSection({
    required this.onExternalSearchTypeSelected,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
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
                  _ExternalSearchButton(
                    label: 'Wiktionary',
                    icon: Icons.book_outlined,
                    searchType: 'wiktionary',
                    onPressed: isEnabled ? onExternalSearchTypeSelected : null,
                  ),
                  _ExternalSearchButton(
                    label: 'Wikipedia',
                    icon: Icons.public,
                    searchType: 'wikipedia',
                    onPressed: isEnabled ? onExternalSearchTypeSelected : null,
                  ),
                  _ExternalSearchButton(
                    label: 'Images',
                    icon: Icons.image,
                    searchType: 'google_images',
                    onPressed: isEnabled ? onExternalSearchTypeSelected : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalSearchButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String searchType;
  final ValueChanged<String>? onPressed;

  const _ExternalSearchButton({
    required this.label,
    required this.icon,
    required this.searchType,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed == null ? null : () => onPressed!(searchType),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
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
}



