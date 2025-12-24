import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/dictionary.dart';
import '../utils/json_html_renderer.dart';
import 'tag_renderer.dart';

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

  Future<void> _launchExternalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch url: $e')),
      );
    }
  }

  /// Helper method to render definition content that might be plain text or structured JSON
  Widget _renderDefinitionContent(String definition, ThemeData theme) {
    try {
      // Try to decode the definition as JSON
      final dynamic jsonContent = jsonDecode(definition);
      // If successful, render it using our JSON HTML renderer
      return JsonHtmlRenderer.render(jsonContent);
    } on FormatException {
      // If it's not valid JSON, render as plain text
      return Text(
        definition,
        style: theme.textTheme.bodyLarge,
      );
    } catch (e) {
      // If there's any other error, render as plain text
      return Text(
        definition,
        style: theme.textTheme.bodyLarge,
      );
    }
  }

  Widget _buildExternalLinkButton(BuildContext context, IconData icon, String label, String url) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _launchExternalLink(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            
            // Definitions with tags
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Render tags if available
                          if (entry.definitionTags != null && entry.definitionTags!.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: TagRenderer.renderTags(entry.definitionTags!),
                            ),
                          // Render the definition content
                          _renderDefinitionContent(definition, theme),
                        ],
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
                leading: const Icon(Icons.image),
                title: const Text('Google Images'),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalLink(context, 'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(entry.term)}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Wikipedia'),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalLink(context, 'https://ja.wikipedia.org/wiki/${Uri.encodeComponent(entry.term)}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Wiktionary'),
                onTap: () {
                  Navigator.pop(context);
                  _launchExternalLink(context, 'https://ja.wiktionary.org/wiki/${Uri.encodeComponent(entry.term)}');
                },
              ),
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
