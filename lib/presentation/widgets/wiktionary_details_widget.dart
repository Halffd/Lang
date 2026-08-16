import 'package:flutter/material.dart';
import 'package:lang/data/datasources/remote/wiktionary_etymology_service.dart';
import 'package:lang/utils/html_renderer.dart';

class WiktionaryDetailsWidget extends StatelessWidget {
  final List<WiktionaryEntry> wiktionaryEntries;
  final String word;

  const WiktionaryDetailsWidget({
    Key? key,
    required this.wiktionaryEntries,
    required this.word,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (wiktionaryEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Wiktionary Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...wiktionaryEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final wiktionaryEntry = entry.value;
              return _buildWiktionaryEntry(context, wiktionaryEntry, index);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWiktionaryEntry(BuildContext context, WiktionaryEntry entry, int index) {
    List<Widget> children = [];

    // Part of speech
    if (entry.partOfSpeech.isNotEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            entry.partOfSpeech,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
    }

    // Definition
    if (entry.definition.isNotEmpty) {
      children.add(
        HtmlRenderer.renderHtmlSafe(entry.definition),
      );
      children.add(const SizedBox(height: 8));
    }

    // Examples
    if (entry.examples.isNotEmpty) {
      children.add(
        Text(
          'Examples:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue[700],
          ),
        ),
      );
      children.add(const SizedBox(height: 4));
      
      for (final example in entry.examples) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: HtmlRenderer.renderHtmlSafe(example),
                ),
              ],
            ),
          ),
        );
        children.add(const SizedBox(height: 4));
      }
      children.add(const SizedBox(height: 8));
    }

    // Synonyms and Antonyms
    List<Widget> relatedWordsWidgets = [];
    
    if (entry.synonyms.isNotEmpty) {
      relatedWordsWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Synonyms: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: entry.synonyms.map((synonym) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        synonym,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (entry.antonyms.isNotEmpty) {
      relatedWordsWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antonyms: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: entry.antonyms.map((antonym) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        antonym,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[800],
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (relatedWordsWidgets.isNotEmpty) {
      children.addAll(relatedWordsWidgets);
      children.add(const SizedBox(height: 8));
    }

    // Add a divider if this isn't the last entry
    if (index < wiktionaryEntries.length - 1) {
      children.add(Divider(height: 16, color: Colors.blue[100]));
      children.add(const SizedBox(height: 8));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}