import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/utils/font_scale.dart';

import 'study/lesson_page.dart';
import 'study/lesson_widgets.dart';
import 'study/ai_lesson_generator.dart';

/// Duolingo-style study tab: deck map with XP/streak, tap to choose lesson type.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _xp = 0;
  int _streak = 0;
  int _dailyGoal = 50;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _xp = p.getInt('study_xp') ?? 0;
      _streak = p.getInt('study_streak') ?? 0;
      _dailyGoal = p.getInt('study_daily_goal') ?? 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    final srs = context.watch<SRSService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Study'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.military_tech, color: Colors.orange, size: 22),
                const SizedBox(width: 4),
                Text(
                  '$_xp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.local_fire_department,
                  color: _streak > 0 ? Colors.orange : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 2),
                Text(
                  '$_streak',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildTree(srs),
    );
  }

  Widget _buildTree(SRSService srs) {
    final items = <Widget>[];

    srs.decks.forEachIndexed((i, deck) {
      final dueCount = srs.getDueCardsByDeck(deck.id).length;
      final color = _deckColor(deck, i);
      final xOff = math.sin(i * 1.3 + 0.5) * 60;
      items.add(
        Center(
          child: Transform.translate(
            offset: Offset(xOff, 0),
            child: _buildDeckNode(deck, color, dueCount > 0),
          ),
        ),
      );
      if (i < srs.decks.length - 1) {
        items.add(_buildSpacer());
      }
    });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Due today: $dueCount',
                  style: TextStyle(
                    fontSize: fs(context, 18, 'headers'),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'AI-generated lesson',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AiDeckGeneratorSheet(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune),
                onPressed: _showSettingsSheet,
              ),
            ],
          ),
        ),
        ...items,
      ],
    );
  }

  int get dueCount => context.read<SRSService>().dueCount;

  Color _deckColor(SrsDeck deck, int i) {
    const palette = [
      Color(0xFF58CC02), // green
      Color(0xFF1CB0F6), // blue
      Color(0xFFCE82FF), // purple
      Color(0xFFFF4B4B), // red
      Color(0xFFFFB000), // amber
      Color(0xFF00CD9C), // teal
    ];
    if (deck.color.isNotEmpty) {
      final v = int.tryParse(deck.color.replaceFirst('#', ''), radix: 16);
      if (v != null) return Color(v);
    }
    return palette[i % palette.length];
  }

  Widget _buildSpacer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckNode(SrsDeck deck, Color color, bool hasDue) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: hasDue ? 1.0 : 0.6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasDue ? () => _showTypePicker(deck) : null,
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (hasDue)
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      deck.icon,
                      style: TextStyle(fontSize: fs(context, 28, 'kanji')),
                    ),
                    if (hasDue)
                      Positioned(
                        top: 2,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '!',
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${deck.name}${hasDue ? ' · $dueCount' : ''}',
          style: TextStyle(
            fontSize: fs(context, 12),
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showTypePicker(SrsDeck deck) {
    final cards = context.read<SRSService>().getDueCardsByDeck(deck.id);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _LessonTypeSheet(
        deck: deck,
        cardCount: cards.length,
        onPick: (type) async {
          Navigator.of(ctx).pop();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LessonPage(
                cards: cards,
                type: type,
                srs: context.read<SRSService>(),
              ),
            ),
          );
          // Refresh xp/streak after returning from a lesson
          if (mounted) await _loadStats();
        },
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily goal',
              style: TextStyle(
                fontSize: fs(context, 18, 'headers'),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...([25, 50, 100, 200].map(
              (g) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<int>(
                  value: g,
                  groupValue: _dailyGoal,
                  onChanged: (v) async {
                    if (v == null) return;
                    final nav = Navigator.of(ctx);
                    setState(() => _dailyGoal = v);
                    final p = await SharedPreferences.getInstance();
                    await p.setInt('study_daily_goal', v);
                    if (nav.canPop()) nav.pop();
                  },
                ),
                title: Text('$g XP'),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _LessonTypeSheet extends StatelessWidget {
  final SrsDeck deck;
  final int cardCount;
  final void Function(LessonType) onPick;

  const _LessonTypeSheet({
    required this.deck,
    required this.cardCount,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose mode', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('$cardCount cards', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _modeChip(
                  context,
                  LessonType.flashcard,
                  'Flashcards',
                  Icons.content_paste_search,
                ),
                const SizedBox(width: 8),
                ...[
                  _modeChip(
                    context,
                    LessonType.multipleChoice,
                    'Meaning',
                    Icons.select_all,
                  ),
                  _modeChip(context, LessonType.written, 'Write', Icons.edit),
                  _modeChip(
                    context,
                    LessonType.kanji,
                    'Choose Kanji',
                    Icons.translate,
                  ),
                  _modeChip(
                    context,
                    LessonType.character,
                    'Write char',
                    Icons.construction,
                  ),
                  _modeChip(
                    context,
                    LessonType.drawing,
                    'Kanji stroke',
                    Icons.gesture,
                  ),
                  _modeChip(
                    context,
                    LessonType.listening,
                    'Listening',
                    Icons.volume_up,
                  ),
                  _modeChip(context, LessonType.spoken, 'Speak', Icons.mic),
                  _modeChip(
                    context,
                    LessonType.matchWords,
                    'Match pairs',
                    Icons.grid_view,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    BuildContext context,
    LessonType type,
    String label,
    IconData icon,
  ) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: false,
      onSelected: (_) => onPick(type),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

extension<T> on Iterable<T> {
  void forEachIndexed(void Function(int, T) f) {
    var i = 0;
    for (final e in this) {
      f(i++, e);
    }
  }
}
