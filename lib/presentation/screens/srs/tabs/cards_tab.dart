import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/data/repositories/anki_package_service.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:lang/presentation/screens/srs/sheets/deck_manager_sheet.dart';
import 'package:lang/presentation/screens/srs/sheets/add_card_sheet.dart';
import 'package:lang/presentation/screens/srs/sheets/card_detail_sheet.dart';
import 'package:lang/presentation/screens/srs/sheets/import_words_sheet.dart';

class CardsTab extends StatefulWidget {
  final SRSService srsService;

  const CardsTab({required this.srsService, super.key});

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  int _filterMode = 0;
  String _sortBy = 'due';
  bool _showGrid = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SRSCard> _filterCards() {
    List<SRSCard> cards;
    switch (_filterMode) {
      case 1:
        cards = widget.srsService.dueCards;
        break;
      case 2:
        cards = widget.srsService.upcomingCards;
        break;
      default:
        cards = widget.srsService.allCards;
    }

    if (_searchQuery.isNotEmpty) {
      cards = cards.where((c) =>
        c.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (c.meaning?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (c.reading?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    switch (_sortBy) {
      case 'alpha':
        cards.sort((a, b) => a.word.compareTo(b.word));
        break;
      case 'priority':
        cards.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'ease':
        cards.sort((a, b) => b.easeFactor.compareTo(a.easeFactor));
        break;
      case 'reviews':
        cards.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case 'created':
        cards.sort((a, b) => (b.lastReviewDate ?? b.nextReview).compareTo(a.lastReviewDate ?? a.nextReview));
        break;
      default:
        cards.sort((a, b) => a.nextReview.compareTo(b.nextReview));
    }

    return cards;
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'alpha': return 'A-Z';
      case 'priority': return 'Priority';
      case 'ease': return 'Ease';
      case 'reviews': return 'Reviews';
      case 'created': return 'Recent';
      default: return 'Due Date';
    }
  }

  void _showAddCardSheet({SRSCard? editCard}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddCardSheet(
        editCard: editCard,
        srsService: widget.srsService,
        onSave: (card) async {
          if (editCard != null) {
            await widget.srsService.updateCard(card);
          } else {
            await widget.srsService.addCard(card);
          }
          setState(() {});
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showImportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ImportWordsSheet(
        onImport: (words) async {
          Navigator.pop(ctx);
          for (final word in words) {
            final card = SRSCard.newCard(
              id: '${word}_${DateTime.now().millisecondsSinceEpoch}',
              word: word,
              reading: '',
              meaning: '',
            );
            await widget.srsService.addCard(card);
          }
          setState(() {});
        },
      ),
    );
  }

  void _confirmDelete(SRSCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card?'),
        content: Text('Remove "${card.word}" from your SRS deck?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.srsService.removeCard(card.id);
              setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _filterCards();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search cards...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  initialValue: _sortBy,
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'due', child: Text('Due Date')),
                    const PopupMenuItem(value: 'alpha', child: Text('A-Z')),
                    const PopupMenuItem(value: 'priority', child: Text('Priority')),
                    const PopupMenuItem(value: 'ease', child: Text('Ease Factor')),
                    const PopupMenuItem(value: 'reviews', child: Text('Reviews')),
                    const PopupMenuItem(value: 'created', child: Text('Created')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 8),
                        Text(_getSortLabel()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_showGrid ? Icons.view_list : Icons.grid_view),
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                  tooltip: _showGrid ? 'List view' : 'Grid view',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(label: Text('All'), value: 0),
                ButtonSegment(label: Text('Due'), value: 1),
                ButtonSegment(label: Text('Upcoming'), value: 2),
              ],
              selected: {_filterMode},
              onSelectionChanged: (s) => setState(() => _filterMode = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('${cards.length} cards', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: _showDeckManager,
                  tooltip: 'Manage Decks',
                ),
                IconButton(
                  icon: const Icon(Icons.upload_outlined),
                  onPressed: _showExportOptions,
                  tooltip: 'Export/Import',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('No cards found'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showAddCardSheet,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Card'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _showImportSheet,
                              icon: const Icon(Icons.download),
                              label: const Text('Import'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : _showGrid
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) => _buildGridCard(cards[index]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: cards.length,
                        itemBuilder: (context, index) => _buildListCard(cards[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCardSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGridCard(SRSCard card) {
    final isSuspended = card.type == CardType.suspended;
    return Card(
      color: isSuspended ? Colors.grey[200] : null,
      child: InkWell(
        onTap: () => _showCardDetailSheet(card),
        onLongPress: () => _showAddCardSheet(editCard: card),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      card.word,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isSuspended ? TextDecoration.lineThrough : null),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSuspended) const Icon(Icons.pause, size: 14, color: Colors.grey),
                ],
              ),
              if (card.reading != null && card.reading!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  card.reading!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                card.meaning ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (card.tags.isNotEmpty) ...[
                const Spacer(),
                Text(
                  card.tags.take(2).join(', '),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(SRSCard card) {
    final isSuspended = card.type == CardType.suspended;
    return Dismissible(
      key: Key(card.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmDelete(card);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        color: isSuspended ? Colors.grey[200] : null,
        child: ListTile(
          title: Row(
            children: [
              Expanded(child: Text(card.word, style: TextStyle(fontWeight: FontWeight.bold, decoration: isSuspended ? TextDecoration.lineThrough : null))),
              if (isSuspended) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(4)), child: const Text('Suspended', style: TextStyle(color: Colors.white, fontSize: 10))),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.meaning?.isNotEmpty == true ? card.meaning! : card.reading ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: card.isDue && !isSuspended ? Colors.orange : Colors.grey),
              ),
              if (card.tags.isNotEmpty) Wrap(
                spacing: 4,
                children: card.tags.take(3).map((t) => Text(t, style: const TextStyle(fontSize: 10, color: Colors.grey))).toList(),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (card.isDue && !isSuspended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Due', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(width: 4),
              Text(
                '${card.interval}d',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          onTap: () => _showCardDetailSheet(card),
          onLongPress: () => _showAddCardSheet(editCard: card),
        ),
      ),
    );
  }

  void _showCardDetailSheet(SRSCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CardDetailSheet(
        card: card,
        srsService: widget.srsService,
        onEdit: () {
          Navigator.pop(ctx);
          _showAddCardSheet(editCard: card);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(card);
        },
        onReset: () async {
          Navigator.pop(ctx);
          await widget.srsService.resetCard(card.id);
          setState(() {});
        },
        onSuspend: () async {
          Navigator.pop(ctx);
          if (card.type == CardType.suspended) {
            await widget.srsService.unsuspendCard(card.id);
          } else {
            await widget.srsService.suspendCard(card.id);
          }
          setState(() {});
        },
      ),
    );
  }

  void _showDeckManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DeckManagerSheet(
        srsService: widget.srsService,
        onDeckSelected: (deckId) {
          Navigator.pop(ctx);
          setState(() {});
        },
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export as JSON'),
              subtitle: const Text('Backup all cards'),
              onTap: () {
                Navigator.pop(ctx);
                _exportCards();
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Export as Anki Deck (.apkg)'),
              subtitle: const Text('Import into Anki'),
              onTap: () {
                Navigator.pop(ctx);
                _exportApkg();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCards() async {
    final cards = _filterCards();
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Cards',
      fileName: 'srs_cards_${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return;

    try {
      final jsonData = cards.map((c) => c.toJson()).toList();
      final file = File(result);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonData));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${cards.length} cards to ${path.basename(result)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportApkg() async {
    final srsService = context.read<SRSService>();
    final cards = _filterCards();
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Anki Deck',
      fileName: 'lang_deck_${DateTime.now().millisecondsSinceEpoch}.apkg',
      type: FileType.custom,
      allowedExtensions: ['apkg'],
    );

    if (result == null) return;

    try {
      final service = AnkiPackageService(srsService: srsService);
      final apkgData = await service.exportDeck(cards: cards);

      final file = File(result);
      await file.writeAsBytes(apkgData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${cards.length} cards to ${path.basename(result)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importApkg() async {
    final srsService = context.read<SRSService>();

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Anki Deck',
      type: FileType.custom,
      allowedExtensions: ['apkg'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final service = AnkiPackageService(srsService: srsService);
      final importedCards = await service.importPackage(bytes);

      int cardsImported = 0;
      int cardsSkipped = 0;

      for (final card in importedCards) {
        final existing = srsService.getCardById(card.id);
        if (existing == null) {
          await srsService.addCard(card);
          cardsImported++;
        } else {
          cardsSkipped++;
        }
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $cardsImported cards${cardsSkipped > 0 ? ', skipped $cardsSkipped duplicates' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importCards() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Cards',
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final ext = path.extension(filePath).toLowerCase();

      List<SRSCard> importedCards = [];
      int imported = 0;
      int skipped = 0;

      if (ext == '.json') {
        final List<dynamic> jsonList = jsonDecode(content);
        for (var item in jsonList) {
          try {
            final card = SRSCard.fromJson(item as Map<String, dynamic>);
            final existing = widget.srsService.getCardById(card.id);
            if (existing == null) {
              importedCards.add(card);
              imported++;
            } else {
              skipped++;
            }
          } catch (e) {
            skipped++;
          }
        }
      } else if (ext == '.csv') {
        final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isEmpty) return;

        for (int i = lines.length > 1 ? 1 : 0; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length >= 2) {
            final word = parts[0].trim().replaceAll('"', '');
            final reading = parts.length > 1 ? parts[1].trim().replaceAll('"', '') : null;
            final meaning = parts.length > 2 ? parts[2].trim().replaceAll('"', '') : '';

            if (word.isNotEmpty) {
              final card = SRSCard.newCard(
                id: '${word}_${DateTime.now().millisecondsSinceEpoch}_$i',
                word: word,
                reading: reading,
                meaning: meaning,
              );
              importedCards.add(card);
              imported++;
            }
          }
        }
      }

      if (importedCards.isNotEmpty) {
        await widget.srsService.bulkAddCards(importedCards);
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $imported cards${skipped > 0 ? ', skipped $skipped duplicates' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import from JSON'),
              subtitle: const Text('Anki-compatible format'),
              onTap: () {
                Navigator.pop(ctx);
                _importCards();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Import from CSV'),
              subtitle: const Text('word,reading,meaning format'),
              onTap: () {
                Navigator.pop(ctx);
                _importCards();
              },
            ),
          ],
        ),
      ),
    );
  }
}