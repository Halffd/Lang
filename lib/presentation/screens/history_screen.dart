import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';

/// Unified activity feed: previous searches, word lookups, kanji views,
/// favorites, anki-added words, documents, browser visits and actions.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryCategory? _filter;

  @override
  void initState() {
    super.initState();
    HistoryService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = HistoryService.instance;
    final items = _filter == null
        ? service.items
        : service.items.where((i) => i.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityTitle),
        actions: [
          if (service.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: _filter == null ? l10n.clearHistory : l10n.clearFilters,
              onPressed: () => _confirmClear(context, _filter),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip(null, l10n.allCategories, Icons.apps),
                _chip(
                  HistoryCategory.search,
                  l10n.categorySearches,
                  Icons.search,
                ),
                _chip(
                  HistoryCategory.word,
                  l10n.categoryWords,
                  Icons.translate,
                ),
                _chip(
                  HistoryCategory.kanji,
                  l10n.categoryKanji,
                  Icons.grid_view,
                ),
                _chip(
                  HistoryCategory.favorite,
                  l10n.categoryFavorites,
                  Icons.star,
                ),
                _chip(HistoryCategory.anki, l10n.categoryAnki, Icons.school),
                _chip(
                  HistoryCategory.document,
                  l10n.categoryDocuments,
                  Icons.book,
                ),
                _chip(
                  HistoryCategory.visit,
                  l10n.categoryVisits,
                  Icons.language,
                ),
                _chip(HistoryCategory.action, l10n.categoryActions, Icons.bolt),
                _chip(
                  HistoryCategory.analysis,
                  l10n.categoryAnalysis,
                  Icons.analytics,
                ),
                _chip(
                  HistoryCategory.clipboard,
                  l10n.categoryClipboard,
                  Icons.content_copy,
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _filter == null
                          ? l10n.noActivityYet
                          : l10n.noActivityInCategory,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _tile(context, items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(HistoryCategory? category, String label, IconData icon) {
    final selected = _filter == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        avatar: Icon(icon, size: 16),
        onSelected: (_) => setState(() => _filter = category),
      ),
    );
  }

  Widget _tile(BuildContext context, HistoryItem item) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color, actionLabel) = switch (item.category) {
      HistoryCategory.search => (
        Icons.search,
        Colors.blue,
        l10n.activitySearch,
      ),
      HistoryCategory.word => (
        Icons.translate,
        Colors.teal,
        l10n.activityWordLookup,
      ),
      HistoryCategory.kanji => (
        Icons.grid_view,
        Colors.pink,
        l10n.activityKanjiLookup,
      ),
      HistoryCategory.favorite => (
        Icons.star,
        Colors.amber,
        (item.subtitle == '-'
            ? l10n.activityUnfavorite
            : l10n.activityFavorite),
      ),
      HistoryCategory.anki => (
        Icons.school,
        Colors.deepPurple,
        (item.subtitle == 'local'
            ? l10n.activityAnkiLocal
            : l10n.activityAnkiAdded),
      ),
      HistoryCategory.document => (
        Icons.book,
        Colors.brown,
        l10n.activityDocument,
      ),
      HistoryCategory.visit => (
        Icons.language,
        Colors.cyan,
        l10n.activityVisit,
      ),
      HistoryCategory.action => (
        Icons.bolt,
        Colors.orange,
        _actionLabel(l10n, item.subtitle),
      ),
      HistoryCategory.analysis => (
        Icons.analytics,
        Colors.indigo,
        l10n.activityAnalysis,
      ),
      HistoryCategory.clipboard => (
        Icons.content_copy,
        Colors.lightGreen,
        l10n.activityClipboard,
      ),
    };

    final time = DateFormat.MMMd().add_Hm().format(item.time);
    // For actions the localized label is the subtitle; other
    // categories keep their stored subtitle (deck, path, url...).
    final subtitle = item.category == HistoryCategory.action
        ? (item.subtitle == null ? null : _actionLabel(l10n, item.subtitle))
        : item.subtitle;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withValues(alpha: 0.3),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => HistoryService.instance.remove(item.id),
      child: ListTile(
        leading: Icon(icon, size: 20, color: color),
        title: Text(item.title),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
        trailing: Text(
          time,
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        onTap: () => _openItem(context, item, actionLabel),
        onLongPress: () => HistoryService.instance.remove(item.id),
      ),
    );
  }

  /// Localized label for action items (stored subtitle is a stable key).
  String _actionLabel(AppLocalizations l10n, String? key) => switch (key) {
    'save_word' => l10n.activitySaveWord,
    'remove_word' => l10n.activityRemoveWord,
    'srs_add' => l10n.activitySrsAdd,
    'srs_remove' => l10n.activitySrsRemove,
    _ => '',
  };

  /// Reopen a history item in its owning screen.
  void _openItem(
    BuildContext context,
    HistoryItem item,
    String actionLabel,
  ) async {
    switch (item.category) {
      case HistoryCategory.search:
      case HistoryCategory.word:
      case HistoryCategory.kanji:
      case HistoryCategory.favorite:
      case HistoryCategory.anki:
      case HistoryCategory.action:
        final provider = context.read<AnalyzerProvider>();
        final result = await provider.lookupHistoryWord(item.title);
        if (result != null && context.mounted) {
          WordDetailSheet.show(context, provider, result);
        }
        break;
      case HistoryCategory.analysis:
        // re-run analysis: full text is stored in subtitle
        if (item.subtitle != null && item.subtitle!.isNotEmpty) {
          final provider = context.read<AnalyzerProvider>();
          await provider.analyzeText(item.subtitle!);
        }
        break;
      case HistoryCategory.clipboard:
        // copy stored text back to the clipboard
        final text = item.subtitle;
        if (text != null && text.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          }
        }
        break;
      case HistoryCategory.document:
        if (item.subtitle != null && item.subtitle!.isNotEmpty) {
          // subtitle holds the file path
          debugPrint('Reopen document: ${item.subtitle}');
        }
        break;
      case HistoryCategory.visit:
        // browser visits: no direct navigation from here
        break;
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryCategory? category,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final scopeLabel = switch (category) {
      null => l10n.allCategories,
      HistoryCategory.search => l10n.categorySearches,
      HistoryCategory.word => l10n.categoryWords,
      HistoryCategory.kanji => l10n.categoryKanji,
      HistoryCategory.favorite => l10n.categoryFavorites,
      HistoryCategory.anki => l10n.categoryAnki,
      HistoryCategory.document => l10n.categoryDocuments,
      HistoryCategory.visit => l10n.categoryVisits,
      HistoryCategory.action => l10n.categoryActions,
      HistoryCategory.analysis => l10n.categoryAnalysis,
      HistoryCategory.clipboard => l10n.categoryClipboard,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(scopeLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HistoryService.instance.clear(category: category);
    }
  }
}
