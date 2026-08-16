import 'package:flutter/material.dart';
import 'package:lang/utils/character_breakdown.dart';

class CharacterBreakdownWidget extends StatelessWidget {
  final List<CharacterInfo> characterInfos;
  final String originalWord;
  final VoidCallback? onClose;

  const CharacterBreakdownWidget({
    Key? key,
    required this.characterInfos,
    required this.originalWord,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Character Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (characterInfos.isEmpty)
          Text(
            'No character information available',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: characterInfos.map((info) => _buildCharacterChip(context, theme, info)).toList(),
          ),
      ],
    );
  }

  Widget _buildCharacterChip(BuildContext context, ThemeData theme, CharacterInfo info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.character,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          if (info.pinyin != null) ...[
            Row(
              children: [
                Icon(Icons.record_voice_over, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(info.pinyin!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (info.meaning != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.translate, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    info.meaning!,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (info.strokeCount != null) ...[
            Row(
              children: [
                Icon(Icons.edit, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('${info.strokeCount} strokes', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}