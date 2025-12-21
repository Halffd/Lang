import 'package:flutter/material.dart';
import '../models/etymology_model.dart';

class EtymologyWidget extends StatelessWidget {
  final List<EtymologyEntry> etymologyEntries;
  final String word;

  const EtymologyWidget({
    Key? key,
    required this.etymologyEntries,
    required this.word,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (etymologyEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Etymology',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...etymologyEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final etymology = entry.value;
              return _buildEtymologyEntry(context, etymology, index);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEtymologyEntry(BuildContext context, EtymologyEntry entry, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.originalLanguage.isEmpty ? 'Origin' : entry.originalLanguage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange[800],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (entry.additionalLanguages.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...entry.additionalLanguages.entries.map((langEntry) {
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${langEntry.key}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        langEntry.value,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}