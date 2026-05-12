import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/srs_card.dart';
import '../../domain/entities/srs_deck.dart';
import '../../data/repositories/srs_service.dart';
import '../../data/repositories/anki_package_service.dart';
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
              if (card.reading.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.reading,
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
              if (card.reading.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.reading,
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
      builder: (ctx) => _AddCardSheet(
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
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: _sortBy,
                  onSelected: (v) => setState(() => _sortBy = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'due', child: Text('Due Date')),
                    const PopupMenuItem(value: 'alpha', child: Text('A-Z')),
                    const PopupMenuItem(value: 'priority', child: Text('Priority')),
                    const PopupMenuItem(value: 'ease', child: Text('Ease Factor')),
                    const PopupMenuItem(value: 'reviews', child: Text('Review Count')),
                    const PopupMenuItem(value: 'created', child: Text('Recently Reviewed')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 4),
                        Text(_getSortLabel(), style: const TextStyle(fontSize: 13)),
                      ],
                    ),
),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_showGrid ? Icons.view_list : Icons.grid_view),
                    onPressed: () => setState(() => _showGrid = !_showGrid),
                    style: IconButton.styleFrom(
                      backgroundColor: _showGrid ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_outlined),
                    onPressed: () => _showDeckManager(),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'export_json') {
                        _exportCards();
                      } else if (v == 'export_apkg') {
                        _exportApkg();
                      } else if (v == 'import') {
                        _showImportOptions();
                      } else if (v == 'import_apkg') {
                        _importApkg();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'export_json', child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Export JSON'),
                        contentPadding: EdgeInsets.zero,
                      )),
                      const PopupMenuItem(value: 'export_apkg', child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Export Anki (.apkg)'),
                        contentPadding: EdgeInsets.zero,
                      )),
                      const PopupMenuItem(value: 'import', child: ListTile(
                        leading: Icon(Icons.upload),
                        title: Text('Import JSON/CSV'),
                        contentPadding: EdgeInsets.zero,
                      )),
                      const PopupMenuItem(value: 'import_apkg', child: ListTile(
                        leading: Icon(Icons.upload),
                        title: Text('Import Anki (.apkg)'),
                        contentPadding: EdgeInsets.zero,
                      )),
                    ],
                  ),
                ],
              ),
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
      builder: (ctx) => _CardDetailSheet(
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
      builder: (ctx) => _DeckManagerSheet(
        srsService: widget.srsService,
        onDeckSelected: (deckId) {
          Navigator.pop(ctx);
          setState(() {});
        },
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

class _DeckManagerSheet extends StatefulWidget {
  final SRSService srsService;
  final Function(String?) onDeckSelected;

  const _DeckManagerSheet({required this.srsService, required this.onDeckSelected});

  @override
  State<_DeckManagerSheet> createState() => _DeckManagerSheetState();
}

class _DeckManagerSheetState extends State<_DeckManagerSheet> {
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
                const Text('Decks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                          backgroundColor: deckColor.withOpacity(0.2),
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
                                if (v == 'edit') _showAddDeckDialog(editDeck: deck);
                                else if (v == 'delete') _confirmDeleteDeck(deck);
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

class _AddCardSheet extends StatefulWidget {
  final SRSCard? editCard;
  final Future<void> Function(SRSCard) onSave;
  final SRSService srsService;

  const _AddCardSheet({this.editCard, required this.onSave, required this.srsService});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  late TextEditingController _wordController;
  late TextEditingController _readingController;
  late TextEditingController _meaningController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  int _priority = 3;
  int _languageLevel = 3;
  bool _saving = false;
  String? _selectedDeck;
  String? _imageBase64;
  String? _audioBase64;
  String? _videoBase64;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  String? _recordedAudioPath;
  final screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.editCard?.word ?? '');
    _readingController = TextEditingController(text: widget.editCard?.reading ?? '');
    _meaningController = TextEditingController(text: widget.editCard?.meaning ?? '');
    _notesController = TextEditingController(text: widget.editCard?.notes ?? '');
    _tagsController = TextEditingController(text: widget.editCard?.tags.join(', ') ?? '');
    _priority = widget.editCard?.priority ?? 3;
    _languageLevel = widget.editCard?.languageLevel ?? 3;
    _selectedDeck = widget.editCard?.deck;
    _imageBase64 = widget.editCard?.imageBase64;
    _audioBase64 = widget.editCard?.audioBase64;
    _videoBase64 = widget.editCard?.videoBase64;

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _readingController.dispose();
    _meaningController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<String> _parseTags(String text) {
    return text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  Future<void> _pickImage() async {
    final picker = await _showMediaPickerDialog();
    if (picker == null) return;

    final bytes = await picker.readAsBytes();
    final ext = picker.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
    setState(() => _imageBase64 = base64);
  }

  Future<void> _takeScreenshot() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final base64 = 'data:image/png;base64,${base64Encode(image)}';
        setState(() => _imageBase64 = base64);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot captured!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot failed: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final picker = await _showMediaPickerDialog(allowVideo: true);
    if (picker == null) return;

    final bytes = await picker.readAsBytes();
    final ext = picker.path.split('.').last.toLowerCase();
    String mimeType = 'video/mp4';
    if (ext == 'mov') mimeType = 'video/quicktime';
    else if (ext == 'webm') mimeType = 'video/webm';
    final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
    setState(() => _videoBase64 = base64);
  }

  Future<void> _recordVideo() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
        return;
      }

      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 2));
      if (video != null) {
        final file = File(video.path);
        final bytes = await file.readAsBytes();
        final base64 = 'data:video/mp4;base64,${base64Encode(bytes)}';
        setState(() => _videoBase64 = base64);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video recording failed: $e')),
        );
      }
    }
  }

  Future<File?> _showMediaPickerDialog({bool allowVideo = false}) async {
    return showDialog<File>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(allowVideo ? 'Select Media' : 'Select Image'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final picker = await _createImagePicker();
              if (picker != null) Navigator.pop(ctx, picker);
            },
            child: const ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final picker = await _createImagePicker(source: ImageSource.camera);
              if (picker != null) {
                Navigator.pop(ctx, picker);
              }
            },
            child: const ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
            ),
          ),
          if (allowVideo)
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await _recordVideo();
              },
              child: const ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Record Video'),
              ),
            ),
        ],
      ),
    );
  }

  Future<File?> _createImagePicker({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (image != null) return File(image.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
    return null;
  }

  Future<void> _showAudioRecordingDialog() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AudioRecordingDialog(
        audioRecorder: _audioRecorder,
        onRecordingComplete: (path, base64) {
          setState(() {
            _recordedAudioPath = path;
            _audioBase64 = base64;
          });
        },
      ),
    );
  }

  Future<void> _playRecording() async {
    if (_recordedAudioPath == null && _audioBase64 == null) return;

    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
    } else {
      if (_recordedAudioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
      } else if (_audioBase64 != null) {
        final bytes = base64Decode(_audioBase64!.split(',').last);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_audio.mp3');
        await tempFile.writeAsBytes(bytes);
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
      }
      setState(() => _isPlayingAudio = true);
    }
  }

  Future<void> _recordAudio() async {
    await _showAudioRecordingDialog();
  }

  void _removeMedia(String type) {
    setState(() {
      if (type == 'image') _imageBase64 = null;
      else if (type == 'audio') {
        _audioBase64 = null;
        _recordedAudioPath = null;
      }
      else if (type == 'video') _videoBase64 = null;
    });
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
            deck: _selectedDeck,
            tags: _parseTags(_tagsController.text),
            notes: _notesController.text.trim(),
            imageBase64: _imageBase64,
            audioBase64: _audioBase64,
            videoBase64: _videoBase64,
          )
        : SRSCard.newCard(
            id: '${_wordController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
            word: _wordController.text.trim(),
            reading: _readingController.text.trim(),
            meaning: _meaningController.text.trim(),
            deck: _selectedDeck,
            tags: _parseTags(_tagsController.text),
            notes: _notesController.text.trim(),
            imageBase64: _imageBase64,
            audioBase64: _audioBase64,
            videoBase64: _videoBase64,
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
      child: Screenshot(
        controller: screenshotController,
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
            DropdownButtonFormField<String?>(
              value: _selectedDeck,
              decoration: const InputDecoration(
                labelText: 'Deck',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No Deck')),
                ...widget.srsService.decks.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
              ],
              onChanged: (v) => setState(() => _selectedDeck = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(),
                hintText: 'e.g., jlpt-n5, vocabulary, verbs',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Media', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MediaButton(
                          icon: Icons.image,
                          label: 'Image',
                          hasMedia: _imageBase64 != null,
                          onTap: _pickImage,
                          onRemove: _imageBase64 != null ? () => _removeMedia('image') : null,
                        ),
                        _MediaButton(
                          icon: Icons.screenshot,
                          label: 'Screenshot',
                          hasMedia: false,
                          onTap: _takeScreenshot,
                        ),
                        _MediaButton(
                          icon: Icons.mic,
                          label: 'Audio',
                          hasMedia: _audioBase64 != null,
                          onTap: _recordAudio,
                          onRemove: _audioBase64 != null ? () => _removeMedia('audio') : null,
                        ),
                        _MediaButton(
                          icon: Icons.videocam,
                          label: 'Video',
                          hasMedia: _videoBase64 != null,
                          onTap: _pickVideo,
                          onRemove: _videoBase64 != null ? () => _removeMedia('video') : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Priority: $_priority'),
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
                      Text('Level: $_languageLevel'),
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

class _AudioRecordingDialog extends StatefulWidget {
  final AudioRecorder audioRecorder;
  final Function(String path, String base64) onRecordingComplete;

  const _AudioRecordingDialog({
    required this.audioRecorder,
    required this.onRecordingComplete,
  });

  @override
  State<_AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<_AudioRecordingDialog> {
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordedPath;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    if (_isRecording) {
      widget.audioRecorder.stop();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final path = '${(await getTemporaryDirectory()).path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await widget.audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
      _updateDuration();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
      }
    }
  }

  void _updateDuration() {
    if (!_isRecording || !mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isRecording) {
        setState(() => _recordingDuration++);
        _updateDuration();
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await widget.audioRecorder.stop();
      if (path != null && mounted) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final base64 = 'data:audio/mp4;base64,${base64Encode(bytes)}';
        widget.onRecordingComplete(path, base64);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save recording: $e')));
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await widget.audioRecorder.stop();
      if (_recordedPath != null) {
        final file = File(_recordedPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Audio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isRecording ? Icons.mic : Icons.mic_off,
            size: 64,
            color: _isRecording ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_recordingDuration),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? 'Recording...' : 'Paused',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Cancel'),
        ),
        if (_isRecording)
          FilledButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
      ],
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasMedia;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.hasMedia,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasMedia && onRemove != null ? onRemove : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasMedia ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          border: Border.all(color: hasMedia ? Colors.green : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: hasMedia ? Colors.green : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: hasMedia ? Colors.green : Colors.grey)),
            if (hasMedia) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: Colors.green),
            ],
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
  final VoidCallback? onSuspend;
  final SRSService srsService;

  const _CardDetailSheet({
    required this.card,
    required this.onEdit,
    required this.onDelete,
    required this.onReset,
    this.onSuspend,
    required this.srsService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuspended = card.type == CardType.suspended;
    final deck = card.deck != null ? srsService.getDeckById(card.deck!) : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(card.word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                if (isSuspended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Suspended', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            if (card.reading != null && card.reading!.isNotEmpty) Text(card.reading!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (card.hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(card.imageBase64!.split(',').last),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
            if (card.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: card.tags.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            if (card.hasAudio || card.hasVideo) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (card.hasAudio) Chip(avatar: const Icon(Icons.mic, size: 16), label: const Text('Audio'), backgroundColor: Colors.blue.withOpacity(0.1)),
                  if (card.hasVideo) Chip(avatar: const Icon(Icons.videocam, size: 16), label: const Text('Video'), backgroundColor: Colors.purple.withOpacity(0.1)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _detailRow('Type', card.type.name),
            if (deck != null) _detailRow('Deck', deck.name),
            _detailRow('Interval', '${card.interval} days'),
            _detailRow('Ease', card.easeFactor.toStringAsFixed(2)),
            _detailRow('Repetitions', '${card.reviewCount}'),
            _detailRow('Next Review', _formatDate(card.nextReview)),
            if (card.notes != null && card.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Notes', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(card.notes!),
            ],
            const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('Edit')),
              OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.refresh), label: const Text('Reset')),
              OutlinedButton.icon(
                onPressed: onSuspend,
                icon: Icon(isSuspended ? Icons.play_arrow : Icons.pause),
                label: Text(isSuspended ? 'Unsuspend' : 'Suspend'),
              ),
              OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red), label: const Text('Delete', style: TextStyle(color: Colors.red))),
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
    final newCards = stats['new'] ?? 0;
    final learning = stats['learning'] ?? 0;
    final review = stats['review'] ?? 0;

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
              _StatCard(label: 'New', value: '$newCards', color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _CardStatusPieChart(newCards: newCards, learning: learning, review: review)),
              const SizedBox(width: 8),
              Expanded(child: _IntervalBarChart(cards: srsService.allCards)),
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
                  _ProgressRow('New', newCards, total, Colors.green),
                  const SizedBox(height: 8),
                  _ProgressRow('Learning', learning, total, Colors.orange),
                  const SizedBox(height: 8),
                  _ProgressRow('Reviewed', review, total, Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EaseFactorChart(cards: srsService.allCards),
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

class _CardStatusPieChart extends StatelessWidget {
  final int newCards;
  final int learning;
  final int review;

  const _CardStatusPieChart({required this.newCards, required this.learning, required this.review});

  @override
  Widget build(BuildContext context) {
    final total = newCards + learning + review;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Card Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('No cards yet', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Card Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 25,
                  sections: [
                    if (newCards > 0) PieChartSectionData(value: newCards.toDouble(), color: Colors.green, title: '$newCards', radius: 30, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                    if (learning > 0) PieChartSectionData(value: learning.toDouble(), color: Colors.orange, title: '$learning', radius: 30, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                    if (review > 0) PieChartSectionData(value: review.toDouble(), color: Colors.blue, title: '$review', radius: 30, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(color: Colors.green, label: 'New', count: newCards),
                _LegendItem(color: Colors.orange, label: 'Learning', count: learning),
                _LegendItem(color: Colors.blue, label: 'Review', count: review),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _IntervalBarChart extends StatelessWidget {
  final List<SRSCard> cards;

  const _IntervalBarChart({required this.cards});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<String, int> intervals = {'Today': 0, 'Tomorrow': 0, '2-7 days': 0, '1-2 weeks': 0, '2-4 weeks': 0, '1+ month': 0};

    for (final card in cards) {
      final diff = card.nextReview.difference(today).inDays;
      if (diff <= 0) intervals['Today'] = intervals['Today']! + 1;
      else if (diff == 1) intervals['Tomorrow'] = intervals['Tomorrow']! + 1;
      else if (diff <= 7) intervals['2-7 days'] = intervals['2-7 days']! + 1;
      else if (diff <= 14) intervals['1-2 weeks'] = intervals['1-2 weeks']! + 1;
      else if (diff <= 28) intervals['2-4 weeks'] = intervals['2-4 weeks']! + 1;
      else intervals['1+ month'] = intervals['1+ month']! + 1;
    }

    final maxVal = intervals.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Due Interval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal.toDouble() + 1 : 5,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
                      final labels = ['Today', 'Tomorrow', '2-7', '1-2w', '2-4w', '1+m'];
                      return Text(val.toInt() < labels.length ? labels[val.toInt()] : '', style: const TextStyle(fontSize: 8));
                    }, reservedSize: 28)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 25, getTitlesWidget: (val, _) => Text(val.toInt() > 0 ? '${val.toInt()}' : '', style: const TextStyle(fontSize: 8)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: intervals.entries.toList().asMap().entries.map((e) {
                    Color color;
                    switch (e.value.key) {
                      case 'Today': color = Colors.red; break;
                      case 'Tomorrow': color = Colors.orange; break;
                      case '2-7 days': color = Colors.yellow.shade700; break;
                      case '1-2 weeks': color = Colors.lightGreen; break;
                      case '2-4 weeks': color = Colors.green; break;
                      default: color = Colors.teal; break;
                    }
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: color, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EaseFactorChart extends StatelessWidget {
  final List<SRSCard> cards;

  const _EaseFactorChart({required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, int> easeBuckets = {'Hard (<2.0)': 0, 'Normal (2.0-2.5)': 0, 'Easy (2.5-3.0)': 0, 'Very Easy (>3.0)': 0};

    for (final card in cards) {
      if (card.easeFactor < 2.0) easeBuckets['Hard (<2.0)'] = easeBuckets['Hard (<2.0)']! + 1;
      else if (card.easeFactor < 2.5) easeBuckets['Normal (2.0-2.5)'] = easeBuckets['Normal (2.0-2.5)']! + 1;
      else if (card.easeFactor < 3.0) easeBuckets['Easy (2.5-3.0)'] = easeBuckets['Easy (2.5-3.0)']! + 1;
      else easeBuckets['Very Easy (>3.0)'] = easeBuckets['Very Easy (>3.0)']! + 1;
    }

    final maxVal = easeBuckets.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ease Factor Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal.toDouble() + 1 : 5,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
                      final labels = ['Hard', 'Normal', 'Easy', 'Very Easy'];
                      return Text(val.toInt() < labels.length ? labels[val.toInt()] : '', style: const TextStyle(fontSize: 9));
                    }, reservedSize: 32)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, _) => Text(val.toInt() > 0 ? '${val.toInt()}' : '', style: const TextStyle(fontSize: 10)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: easeBuckets.entries.toList().asMap().entries.map((e) {
                    Color color;
                    switch (e.value.key) {
                      case 'Hard (<2.0)': color = Colors.red; break;
                      case 'Normal (2.0-2.5)': color = Colors.orange; break;
                      case 'Easy (2.5-3.0)': color = Colors.lightGreen; break;
                      default: color = Colors.green; break;
                    }
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: color, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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