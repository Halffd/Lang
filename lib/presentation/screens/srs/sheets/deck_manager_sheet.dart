import 'package:flutter/material.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/utils/font_scale.dart';

class DeckManagerSheet extends StatefulWidget {
  final SRSService srsService;
  final Function(String?) onDeckSelected;

  const DeckManagerSheet({required this.srsService, required this.onDeckSelected, super.key});

  @override
  State<DeckManagerSheet> createState() => _DeckManagerSheetState();
}

class _DeckManagerSheetState extends State<DeckManagerSheet> {
  void _showAddDeckDialog({SrsDeck? editDeck}) {
    final nameController = TextEditingController(text: editDeck?.name ?? '');
    final descController = TextEditingController(text: editDeck?.description ?? '');
    String selectedIcon = editDeck?.icon ?? '📚';
    String selectedColor = editDeck?.color ?? '#3B82F6';

    final icons = ['📚', '📖', '📝', '🎯', '💡', '🔥', '⚡', '🌟', '🎓', '🏆', '📊', '🎮', '🎨', '🎵'];
    final colors = ['#3B82F6', '#8B5CF6', '#EF4444', '#F97316', '#EAB308', '#22C55E', '#06B6D4', '#EC4899'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editDeck != null ? 'Edit Deck' : 'New Deck'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: icons.map((icon) => GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedIcon == icon ? Theme.of(context).primaryColor : Colors.grey[300]!, width: selectedIcon == icon ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 20)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        border: Border.all(color: selectedColor == color ? Colors.black : Colors.grey[300]!, width: selectedColor == color ? 2 : 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final now = DateTime.now();
                if (editDeck != null) {
                  final updated = editDeck.copyWith(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    icon: selectedIcon,
                    color: selectedColor,
                    updatedAt: now,
                  );
                  await widget.srsService.updateDeck(updated);
                } else {
                  final newDeck = SrsDeck(
                    id: '${nameController.text.trim().toLowerCase().replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    icon: selectedIcon,
                    color: selectedColor,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await widget.srsService.addDeck(newDeck);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: Text(editDeck != null ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDeck(SrsDeck deck) {
    final cardCount = widget.srsService.getDeckCardCount(deck.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deck?'),
        content: Text('Delete "${deck.name}"? ${cardCount > 0 ? '$cardCount cards will be moved to No Deck.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.srsService.deleteDeck(deck.id);
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
    final decks = widget.srsService.decks;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Decks', style: TextStyle(fontSize: fs(context, 20, 'words'), fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDeckDialog()),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: decks.isEmpty
                ? const Center(child: Text('No decks yet'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: decks.length,
                    itemBuilder: (ctx, idx) {
                      final deck = decks[idx];
                      final cardCount = widget.srsService.getDeckCardCount(deck.id);
                      final dueCount = widget.srsService.getDeckDueCount(deck.id);
                      final deckColor = Color(int.parse(deck.color.replaceFirst('#', '0xFF')));

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: deckColor.withValues(alpha: 0.2),
                          child: Text(deck.icon, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(deck.name),
                        subtitle: Text('${deck.description ?? ''} • $cardCount cards${dueCount > 0 ? ' • $dueCount due' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (dueCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                                child: Text('$dueCount', style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _showAddDeckDialog(editDeck: deck);
                                } else if (v == 'delete') _confirmDeleteDeck(deck);
                                else if (v == 'select') widget.onDeckSelected(deck.id);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'select', child: Text('Select')),
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => widget.onDeckSelected(deck.id),
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }
}