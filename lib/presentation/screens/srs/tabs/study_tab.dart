import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:lang/utils/font_scale.dart';

class StudyTab extends StatefulWidget {
  final SRSService srsService;

  const StudyTab({required this.srsService, super.key});

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> with SingleTickerProviderStateMixin {
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
              style: TextStyle(fontSize: fs(context, 24, 'ui')),
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
                  fontSize: fs(context, 36, 'kanji'),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (card.reading != null && card.reading!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.reading!,
                  style: TextStyle(fontSize: fs(context, 20, 'words'), color: theme.colorScheme.onSurfaceVariant),
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
                  fontSize: fs(context, 28, 'words'),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (card.reading != null && card.reading!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.reading!,
                  style: TextStyle(fontSize: fs(context, 16, 'words'), color: theme.colorScheme.onSurfaceVariant),
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
                  style: TextStyle(fontSize: fs(context, 18, 'words'), color: theme.colorScheme.onPrimaryContainer),
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