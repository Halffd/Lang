import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';

/// Duolingo-style study tab: XP + streak + skill-tree of decks.
/// Tap a deck node to start a lesson of flashcards.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with TickerProviderStateMixin {
  late AnimationController _flipAnimation;
  bool _showBack = false;
  List<SRSCard>? _lessonCards;
  int _currentCardIndex = 0;
  int _sessionXpEarned = 0;
  int _sessionCardsDone = 0;

  final _storage = _StudyStorage();

  SRSCard? get _currentCard {
    final cards = _lessonCards;
    if (cards == null || _currentCardIndex >= cards.length) return null;
    return cards[_currentCardIndex];
  }

  int get _totalXp => _storage.xp;
  int get _streak => _storage.streak;
  int get _level => (_totalXp ~/ 100) + 1;

  @override
  void initState() {
    super.initState();
    _flipAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _storage.load().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _flipAnimation.dispose();
    super.dispose();
  }

  Future<void> _flipCard() async {
    if (!_showBack) {
      await _flipAnimation.forward();
      setState(() => _showBack = true);
    }
  }

  Future<void> _hideCard() async {
    if (_showBack) {
      await _flipAnimation.reverse();
      setState(() => _showBack = false);
    }
  }

  Future<void> _review(int quality) async {
    final card = _currentCard;
    if (card == null) return;

    await _hideCard();

    final xpPerRating = [10, 5, 20, 40];
    _sessionXpEarned += xpPerRating[quality.clamp(0, 3)];
    _sessionCardsDone++;

    await _storage.addXp(xpPerRating[quality.clamp(0, 3)]);
    if (!mounted) return;
    await context.read<SRSService>().reviewCard(card.id, quality);
    _currentCardIndex++;
    if (mounted) setState(() {});
  }

  void _startLesson(String deckId, List<SRSCard> due) {
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards due in this deck today')),
      );
      return;
    }
    setState(() {
      _lessonCards = List.from(due);
      _currentCardIndex = 0;
      _sessionXpEarned = 0;
      _sessionCardsDone = 0;
      _showBack = false;
    });
  }

  void _finishLesson() {
    setState(() {
      _lessonCards = null;
      _currentCardIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final srs = context.watch<SRSService>();
    final isLesson = _lessonCards != null && _lessonCards!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Study'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.military_tech, color: Colors.orange, size: 22),
                const SizedBox(width: 4),
                Text(
                  '$_totalXp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrange,
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_streak',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isLesson ? _buildLesson(srs) : _buildTree(srs),
    );
  }

  Widget _buildTree(SRSService srs) {
    final decks = srs.decks;

    final items = <Map<String, dynamic>>[];

    for (var i = 0; i < decks.length; i++) {
      items.add({'deck': decks[i], 'isChallenge': false, 'index': i});
      // challenge node between decks
      if (i < decks.length - 1) {
        items.add({'deck': null, 'isChallenge': true, 'index': i});
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.school,
                        color: Colors.purple.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $_level',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${100 - _totalXp % 100} XP to next level',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: (_totalXp % 100) / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amber,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_totalXp % 100} XP',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              if (item['isChallenge'] == true) return _buildChallengeNode(i);
              final deck = item['deck'] as SrsDeck;
              return _buildDeckNode(deck, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeNode(int idx) {
    final dx = math.sin(idx * 1.2) * 16;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Column(
        children: [
          Container(width: 4, height: 32, color: Colors.grey.shade300),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk,
              color: Colors.white,
              size: 18,
            ),
          ),
          Container(width: 4, height: 32, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _buildDeckNode(SrsDeck deck, int index) {
    final dx = math.sin(index * 0.8 + 1) * 20;
    final color = _deckColor(index, deck.color);

    return Transform.translate(
      offset: Offset(dx, 0),
      child: InkWell(
        onTap: () {
          final dueNow = context.read<SRSService>().getDueCardsByDeck(deck.id);
          if (dueNow.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${deck.name} is all caught up')),
            );
            return;
          }
          _startLesson(deck.id, dueNow);
        },
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(deck.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    deck.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                deck.name,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _deckColor(int index, String? colorStr) {
    const palette = [
      Color(0xFF58CC02),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
    ];
    if (colorStr != null) {
      final v = int.tryParse(colorStr);
      if (v != null) return Color(v);
    }
    return palette[index % palette.length];
  }

  Widget _buildLesson(SRSService srs) {
    final cards = _lessonCards!;
    if (_currentCardIndex >= cards.length) return _buildFinished();

    final card = cards[_currentCardIndex];
    final progress = _currentCardIndex / cards.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            minHeight: 6,
          ),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final angle = _flipAnimation.value * math.pi;
                  final showBack = angle > math.pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(showBack ? math.pi - angle : angle),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: showBack ? Colors.indigo[600] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(36.0),
                      constraints: const BoxConstraints(minHeight: 320),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (showBack)
                            Text(
                              card.meaning,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            )
                          else ...[
                            Text(
                              card.word,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (card.reading != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                card.reading!,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '$_currentCardIndex / ${cards.length}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap card to ${showBack ? 'hide' : 'show'} answer',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _answerButton('Again', Colors.red, 1),
                  _answerButton('Hard', Colors.orange, 2),
                  _answerButton('Good', Colors.blue, 3),
                  _answerButton('Easy', Colors.green, 4),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _answerButton(String label, Color color, int quality) {
    return ElevatedButton(
      onPressed: () => _review(quality),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(
        '$label\n${_xpForQuality(quality)} XP',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  int _xpForQuality(int q) => [10, 5, 20, 40][q.clamp(0, 3)];

  bool get showBack => _showBack;

  Widget _buildFinished() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            '$_sessionXpEarned XP earned',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$_sessionCardsDone cards completed',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _finishLesson,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyStorage {
  int xp = 0;
  int streak = 0;
  int _lastSessionMs = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    xp = prefs.getInt('study_xp') ?? 0;
    streak = prefs.getInt('study_streak') ?? 0;
    _lastSessionMs = prefs.getInt('study_last_ms') ?? 0;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('study_xp', xp);
    await prefs.setInt('study_streak', streak);
    await prefs.setInt('study_last_ms', _lastSessionMs);
  }

  Future<void> addXp(int amount) async {
    xp += amount;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = DateTime.fromMillisecondsSinceEpoch(_lastSessionMs);
    final today = DateTime.now();
    final daysBetween = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(last.year, last.month, last.day)).inDays;
    if (daysBetween == 1) streak++;
    if (daysBetween > 1) streak = 1;
    _lastSessionMs = now;
    await _save();
  }
}
