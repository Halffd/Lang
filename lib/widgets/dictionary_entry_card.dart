import 'package:flutter/material.dart';
import '../models/dictionary_entry.dart';

class DictionaryEntryCard extends StatelessWidget {
  final DictionaryEntry entry;
  final bool isSaved;
  final bool isFavorite;
  final bool isInAnki;
  final VoidCallback onSaveToggle;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onAnkiToggle;

  const DictionaryEntryCard({
    super.key,
    required this.entry,
    required this.isSaved,
    required this.isFavorite,
    required this.isInAnki,
    required this.onSaveToggle,
    required this.onFavoriteToggle,
    required this.onAnkiToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Term and reading
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.term,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (entry.reading.isNotEmpty && entry.reading != entry.term)
                        Text(
                          entry.reading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                        size: 20,
                      ),
                      onPressed: onFavoriteToggle,
                      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    ),
                    IconButton(
                      icon: Icon(
                        isInAnki ? Icons.book : Icons.book_outlined,
                        color: isInAnki ? Colors.blue : null,
                        size: 20,
                      ),
                      onPressed: onAnkiToggle,
                      tooltip: isInAnki ? 'Remove from Anki' : 'Add to Anki',
                    ),
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? theme.colorScheme.primary : null,
                        size: 20,
                      ),
                      onPressed: onSaveToggle,
                      tooltip: isSaved ? 'Remove from saved' : 'Save word',
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Tags
            if (entry.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.tags.map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 12),
            
            // Definitions
            ...entry.definitions.asMap().entries.map((defEntry) {
              final index = defEntry.key;
              final definition = defEntry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        definition,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            // Frequency indicator
            if (entry.frequency > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bar_chart,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Frequency rank: ${entry.frequency}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            
            // Examples
            if (entry.examples.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examples',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entry.examples.map((example) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          example,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: const Text('Listen'),
                    onPressed: () {
                      // Implement audio playback
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () {
                      // Implement copy functionality
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.more_horiz, size: 18),
                    label: const Text('More'),
                    onPressed: () {
                      _showMoreOptions(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Translate'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement translation functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search in other dictionaries'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement search in other dictionaries
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement share functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Add to Anki'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement Anki integration
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
