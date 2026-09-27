import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/utils/srs_conversion_utils.dart';

/// Icon size for the compact word actions.
///
/// The user asked for these buttons at 60% of the previous 20px, so 12px.
/// The tap target stays comfortably larger than the glyph via
/// [VisualDensity] + explicit constraints, so the shrink does not cost
/// accessibility.
const double kWordActionIconSize = 12.0;
const Size kWordActionTapTarget = Size(32, 32);

/// Copy / Anki / favorites / learned actions for a single word.
///
/// Self-wiring: reads [AppState] and [SRSService] from the context so every
/// screen shows the same behaviour and the same sizing instead of each
/// screen re-implementing the toggles.
class WordActionBar extends StatelessWidget {
  final AnalyzedWord word;
  final bool showSave;
  final bool showCopy;

  const WordActionBar({
    super.key,
    required this.word,
    this.showSave = true,
    this.showCopy = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final srs = context.watch<SRSService>();

    final term = word.word;
    final reading = word.reading ?? '';
    final isFavorite = appState.favoriteWords.contains(term);
    final isInAnki = appState.ankiWords.contains(term);
    final isInSrs = srs.allCards.any((c) => c.id == term + reading);

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showCopy)
          _Action(
            icon: Icons.copy,
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: reading.isEmpty ? term : '$term ($reading)',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        _Action(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.red : null,
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () {
            isFavorite
                ? appState.removeFavoriteWord(term)
                : appState.addFavoriteWord(term);
            _record('favorite', term);
          },
        ),
        _Action(
          icon: isInAnki ? Icons.book : Icons.book_outlined,
          color: isInAnki ? Colors.blue : null,
          tooltip: isInAnki ? 'Remove from Anki' : 'Add to Anki',
          onPressed: () {
            isInAnki
                ? appState.removeAnkiWord(term)
                : appState.addAnkiWord(term);
            _record('anki', term);
          },
        ),
        _Action(
          icon: isInSrs ? Icons.school : Icons.school_outlined,
          color: isInSrs ? Colors.green : null,
          tooltip: isInSrs ? 'Remove from learned' : 'Add to learned',
          onPressed: () {
            if (isInSrs) {
              srs.removeCard(term + reading);
              _record('srs_remove', term);
            } else {
              srs.addCard(SRSConversionUtils.analyzedWordToSRSCard(word));
              _record('srs_add', term);
            }
          },
        ),
        if (showSave)
          _Action(
            icon: Icons.bookmark_border,
            color: theme.colorScheme.primary,
            tooltip: 'Save word',
            onPressed: () => _record('save', term),
          ),
      ],
    );
  }

  void _record(String action, String term) {
    HistoryService.instance.record(
      HistoryCategory.action,
      term,
      subtitle: action,
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  const _Action({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: kWordActionTapTarget.width / 2,
        containedInkWell: true,
        child: SizedBox(
          width: kWordActionTapTarget.width,
          height: kWordActionTapTarget.height,
          child: Icon(icon, size: kWordActionIconSize, color: color),
        ),
      ),
    );
  }
}
