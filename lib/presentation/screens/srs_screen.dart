import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/srs_card.dart';
import '../../data/repositories/srs_service.dart';
import '../providers/analyzer_provider.dart';
import '../../utils/screen_size.dart';

class SRSScreen extends StatefulWidget {
  const SRSScreen({super.key});

  @override
  State<SRSScreen> createState() => _SRSScreenState();
}

class _SRSScreenState extends State<SRSScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final srsService = context.watch<SRSService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SRS'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: srsService.dueCount > 0,
                label: Text('${srsService.dueCount}'),
                child: const Icon(Icons.school),
              ),
              text: 'Study',
            ),
            Tab(icon: const Icon(Icons.list), text: 'Cards'),
            Tab(icon: const Icon(Icons.bar_chart), text: 'Stats'),
            Tab(icon: const Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StudyTab(srsService: srsService),
          _CardsTab(srsService: srsService),
          _StatsTab(srsService: srsService),
          _SettingsTab(srsService: srsService),
        ],
      ),
    );
  }
}

class _StudyTab extends StatefulWidget {
  final SRSService srsService;

  const _StudyTab({required this.srsService});

  @override
  State<_StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<_StudyTab> with SingleTickerProviderStateMixin {
  List<SRSCard> _sessionCards = [];
  int _sessionIndex = 0;
  bool _showAnswer = false;
  int _reviewed = 0;
  int _correct = 0;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadSession();
  }

  void _loadSession() {
    final due = widget.srsService.dueCards;
    final shuffled = List<SRSCard>.from(due)..shuffle(math.Random());
    setState(() {
      _sessionCards = shuffled.take(20).toList();
      _sessionIndex = 0;
      _showAnswer = false;
      _reviewed = 0;
      _correct = 0;
    });
  }

  void _flipCard() {
    if (!_showAnswer) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  void _rateCard(int quality) async {
    final card = _sessionCards[_sessionIndex];
    await widget.srsService.reviewCard(card.id, quality);

    setState(() {
      _reviewed++;
      if (quality >= 3) _correct++;
    });

    _flipController.reset();
    setState(() => _showAnswer = false);

    if (_sessionIndex < _sessionCards.length - 1) {
      setState(() => _sessionIndex++);
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _showSessionComplete();
    }
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reviewed: $_reviewed'),
            Text('Correct: $_correct'),
            Text('Accuracy: ${_reviewed > 0 ? ((_correct / _reviewed) * 100).round() : 0}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadSession();
            },
            child: const Text('Study More'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (!_showAnswer) {
      if (event.logicalKey == LogicalKeyboardKey.space) _flipCard();
    } else {
      if (event.logicalKey == LogicalKeyboardKey.digit1) _rateCard(1);
      if (event.logicalKey == LogicalKeyboardKey.digit2) _rateCard(2);
      if (event.logicalKey == LogicalKeyboardKey.digit3) _rateCard(3);
      if (event.logicalKey == LogicalKeyboardKey.digit4) _rateCard(4);
      if (event.logicalKey == LogicalKeyboardKey.digit5) _rateCard(5);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'No cards due!',
              style: TextStyle(fontSize: ScreenSize.adaptiveFontSize(context, 24)),
            ),
            const SizedBox(height: 8),
            const Text('Add cards or come back later', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSession,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      );
    }

    final card = _sessionCards[_sessionIndex];

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProgressBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildFlashcard(card)),
            const SizedBox(height: 16),
            _buildRatingButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _sessionCards.isNotEmpty ? (_sessionIndex + 1) / _sessionCards.length : 0,
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_sessionIndex + 1} / ${_sessionCards.length}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Reviewed: $_reviewed  Accuracy: ${_reviewed > 0 ? ((_correct / _reviewed) * 100).round() : 0}%',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildFlashcard(SRSCard card) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isBack = _flipAnimation.value >= 0.5;
          final angle = isBack ? math.pi : 0.0;

          return Transform(
            transform: Matrix4.identity()..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildCardFace(card, showAnswer: true),
                  )
                : _buildCardFace(card, showAnswer: false),
          );
        },
      ),
    );
  }

  Widget _buildCardFace(SRSCard card, {required bool showAnswer}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!showAnswer) ...[
              Text(
                card.word,
                style: TextStyle(
                  fontSize: ScreenSize.adaptiveFontSize(context, 36),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (card.reading != null && card.reading!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.reading!,
                  style: TextStyle(fontSize: 20, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.tonal(
                onPressed: _flipCard,
                child: const Text('Show Answer  (Space)'),
              ),
            ] else ...[
              Text(
                card.word,
                style: TextStyle(
                  fontSize: ScreenSize.adaptiveFontSize(context, 28),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (card.reading != null && card.reading!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.reading!,
                  style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  card.meaning,
                  style: TextStyle(fontSize: 18, color: theme.colorScheme.onPrimaryContainer),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButtons() {
    if (!_showAnswer) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ratingChip(1, 'Again', Colors.red, '1'),
        _ratingChip(2, 'Hard', Colors.orange, '2'),
        _ratingChip(3, 'Good', Colors.green, '3'),
        _ratingChip(4, 'Easy', Colors.lightBlue, '4'),
        _ratingChip(5, 'Perfect', Colors.blue, '5'),
      ],
    );
  }

  Widget _ratingChip(int rating, String label, Color color, String key) {
    return ElevatedButton(
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      child: Text('$label ($key)'),
    );
  }
}

class _CardsTab extends StatefulWidget {
  final SRSService srsService;

  const _CardsTab({required this.srsService});

  @override
  State<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<_CardsTab> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  int _viewMode = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SRSCard> _filterCards() {
    List<SRSCard> cards;
    switch (_viewMode) {
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
        c.meaning.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return cards;
  }

  void _showAddCardSheet({SRSCard? editCard}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddCardSheet(
        editCard: editCard,
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
      builder: (ctx) => _ImportWordsSheet(
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
              selected: {_viewMode},
              onSelectionChanged: (s) => setState(() => _viewMode = s.first),
            ),
          ),
          const SizedBox(height: 8),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
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
                          child: ListTile(
                            title: Text(card.word, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              card.meaning.isNotEmpty ? card.meaning : (card.reading ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: card.isDue ? Colors.orange : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (card.isDue)
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
                    },
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

  void _showCardDetailSheet(SRSCard card) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _CardDetailSheet(
        card: card,
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
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  final SRSCard? editCard;
  final Future<void> Function(SRSCard) onSave;

  const _AddCardSheet({this.editCard, required this.onSave});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  late TextEditingController _wordController;
  late TextEditingController _readingController;
  late TextEditingController _meaningController;
  int _priority = 3;
  int _languageLevel = 3;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.editCard?.word ?? '');
    _readingController = TextEditingController(text: widget.editCard?.reading ?? '');
    _meaningController = TextEditingController(text: widget.editCard?.meaning ?? '');
    _priority = widget.editCard?.priority ?? 3;
    _languageLevel = widget.editCard?.languageLevel ?? 3;
  }

  @override
  void dispose() {
    _wordController.dispose();
    _readingController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_wordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final card = widget.editCard != null
        ? widget.editCard!.copyWith(
            word: _wordController.text.trim(),
            reading: _readingController.text.trim(),
            meaning: _meaningController.text.trim(),
            priority: _priority,
            languageLevel: _languageLevel,
          )
        : SRSCard.newCard(
            id: '${_wordController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
            word: _wordController.text.trim(),
            reading: _readingController.text.trim(),
            meaning: _meaningController.text.trim(),
          );
    await widget.onSave(card);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editCard != null ? 'Edit Card' : 'Add Card',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: 'Word *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _readingController,
              decoration: const InputDecoration(
                labelText: 'Reading (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meaningController,
              decoration: const InputDecoration(
                labelText: 'Meaning',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Priority'),
                      Slider(
                        value: _priority.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_priority',
                        onChanged: (v) => setState(() => _priority = v.round()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Level'),
                      Slider(
                        value: _languageLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_languageLevel',
                        onChanged: (v) => setState(() => _languageLevel = v.round()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.editCard != null ? 'Update' : 'Add Card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportWordsSheet extends StatefulWidget {
  final Future<void> Function(List<String> words) onImport;

  const _ImportWordsSheet({required this.onImport});

  @override
  State<_ImportWordsSheet> createState() => _ImportWordsSheetState();
}

class _ImportWordsSheetState extends State<_ImportWordsSheet> {
  final Set<String> _selected = {};
  late List<String> _savedWords;

  @override
  void initState() {
    super.initState();
    final analyzer = context.read<AnalyzerProvider>();
    _savedWords = analyzer.savedWords.map((e) => e['word']?.toString() ?? e['expression']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Import from Saved (${_selected.length} selected)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              if (_savedWords.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No saved words. Save words from the Reader or Search screens.'),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _savedWords.length,
                    itemBuilder: (context, index) {
                      final word = _savedWords[index];
                      return CheckboxListTile(
                        title: Text(word),
                        value: _selected.contains(word),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(word);
                            } else {
                              _selected.remove(word);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _selected.isEmpty ? null : () => widget.onImport(_selected.toList()),
                  child: Text('Import ${_selected.length} card${_selected.length == 1 ? '' : 's'}'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CardDetailSheet extends StatelessWidget {
  final SRSCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReset;

  const _CardDetailSheet({
    required this.card,
    required this.onEdit,
    required this.onDelete,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(card.word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          if (card.reading != null && card.reading!.isNotEmpty) Text(card.reading!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (card.meaning.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(card.meaning, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          const SizedBox(height: 16),
          _detailRow('Interval', '${card.interval} days'),
          _detailRow('Ease', card.easeFactor.toStringAsFixed(2)),
          _detailRow('Repetitions', '${card.reviewCount}'),
          _detailRow('Next Review', _formatDate(card.nextReview)),
          _detailRow('Priority', '${card.priority}/5'),
          _detailRow('Level', '${card.languageLevel}/5'),
          _detailRow('Reviews', '${card.reviewCount}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(now).inDays;
    if (diff <= 0) return 'Due now';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}

class _StatsTab extends StatelessWidget {
  final SRSService srsService;

  const _StatsTab({required this.srsService});

  @override
  Widget build(BuildContext context) {
    final stats = srsService.getReviewStats();
    final dueCards = srsService.dueCards;
    final total = stats['total'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatCard(label: 'Due', value: '${stats['due']}', color: Colors.red),
              const SizedBox(width: 8),
              _StatCard(label: 'Total', value: '$total', color: Colors.blue),
              const SizedBox(width: 8),
              _StatCard(label: 'New', value: '${stats['new']}', color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Learning Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _ProgressRow('New', stats['new'] ?? 0, total, Colors.green),
                  const SizedBox(height: 8),
                  _ProgressRow('Learning', stats['learning'] ?? 0, total, Colors.orange),
                  const SizedBox(height: 8),
                  _ProgressRow('Reviewed', stats['review'] ?? 0, total, Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (dueCards.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Due Today (${dueCards.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...dueCards.take(8).map((card) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${card.word}', style: const TextStyle(fontSize: 15)),
                    )),
                    if (dueCards.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('+${dueCards.length - 8} more', style: const TextStyle(color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...srsService.upcomingCards.take(5).map((card) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${card.word}'),
                        Text(_formatDate(card.nextReview), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(now).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressRow(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$pct% ($value)'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          minHeight: 8,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatefulWidget {
  final SRSService srsService;

  const _SettingsTab({required this.srsService});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  int _maxReviews = 50;
  int _newCards = 10;
  bool _autoAudio = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Max Reviews per Session'),
            subtitle: Text('$_maxReviews cards'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _maxReviews.toDouble(),
                min: 10,
                max: 100,
                divisions: 9,
                label: '$_maxReviews',
                onChanged: (v) => setState(() => _maxReviews = v.round()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fiber_new),
            title: const Text('New Cards per Session'),
            subtitle: Text('$_newCards cards'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _newCards.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                label: '$_newCards',
                onChanged: (v) => setState(() => _newCards = v.round()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Auto-play Audio'),
            subtitle: const Text('Play reading when card is shown'),
            value: _autoAudio,
            onChanged: (v) => setState(() => _autoAudio = v),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Keyboard Shortcuts (Study tab)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _ShortcutRow('Space', 'Show/Hide answer'),
        const _ShortcutRow('1-5', 'Rate card (Again to Perfect)'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Export Cards?'),
                content: const Text('This would export all cards as JSON. Coming soon.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                ],
              ),
            );
          },
          icon: const Icon(Icons.upload),
          label: const Text('Export Cards (JSON)'),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcutKey;
  final String action;

  const _ShortcutRow(this.shortcutKey, this.action);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(shortcutKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(action, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}