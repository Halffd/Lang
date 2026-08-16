import 'package:flutter/material.dart';
import 'package:lang/domain/entities/etymology_model.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Etymology',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...etymologyEntries.map((entry) => _buildEntry(context, entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, EtymologyEntry entry) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.language != null) ...[
            Text(
              entry.language!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            entry.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (entry.cognates != null && entry.cognates!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: entry.cognates!.map((cognate) => Chip(
                label: Text(cognate, style: const TextStyle(fontSize: 11)),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                labelPadding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}