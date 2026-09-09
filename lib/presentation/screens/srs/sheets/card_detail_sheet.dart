import 'package:flutter/material.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/utils/font_scale.dart';

class CardDetailSheet extends StatefulWidget {
  final SRSCard card;
  final SRSService srsService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReset;
  final VoidCallback onSuspend;

  const CardDetailSheet({
    required this.card,
    required this.srsService,
    required this.onEdit,
    required this.onDelete,
    required this.onReset,
    required this.onSuspend,
    super.key,
  });

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  late SRSCard _card;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
  }

  void _refreshCard() {
    final updated = widget.srsService.getCardById(_card.id);
    if (updated != null) {
      setState(() => _card = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuspended = _card.type == CardType.suspended;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _card.word,
                        style: TextStyle(fontSize: fs(context, 24, 'kanji'), fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_card.reading != null && _card.reading!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _card.reading!,
                          style: TextStyle(fontSize: fs(context, 16, 'words'), color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSuspended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(12)),
                    child: Text('SUSPENDED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fs(context, 12))),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meaning', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_card.meaning, style: TextStyle(fontSize: fs(context, 16, 'words'))),
                    if (_card.notes != null && _card.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Notes', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_card.notes!, style: TextStyle(fontSize: fs(context, 14, 'translations'))),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card Info', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _detailRow('ID', _card.id),
                    _detailRow('Type', _card.type.toString().split('.').last),
                    _detailRow('Ease Factor', _card.easeFactor.toStringAsFixed(2)),
                    _detailRow('Interval', '${_card.interval} days'),
                    _detailRow('Reviews', '${_card.reviewCount}'),
                    _detailRow('Priority', '${_card.priority}'),
                    _detailRow('Language Level', '${_card.languageLevel}'),
                    if (_card.lastReviewDate != null)
                      _detailRow('Last Review', _formatDateTime(_card.lastReviewDate!)),
                    _detailRow('Next Review', _formatDateTime(_card.nextReview)),
                    if (_card.deck != null) ...[
                      (() {
                        final deck = widget.srsService.getDeckById(_card.deck!);
                        if (deck != null) return _detailRow('Deck', deck.name);
                        return const SizedBox.shrink();
                      })(),
                    ],
                    if (_card.tags.isNotEmpty)
                      _detailRow('Tags', _card.tags.join(', ')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: widget.onEdit, icon: const Icon(Icons.edit), label: const Text('Edit')),
                OutlinedButton.icon(onPressed: widget.onReset, icon: const Icon(Icons.refresh), label: const Text('Reset')),
                OutlinedButton.icon(
                  onPressed: widget.onSuspend,
                  icon: Icon(isSuspended ? Icons.play_arrow : Icons.pause),
                  label: Text(isSuspended ? 'Unsuspend' : 'Suspend'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}