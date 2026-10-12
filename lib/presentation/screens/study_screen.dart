import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/utils/font_scale.dart';

import 'study/lesson_page.dart';
import 'study/lesson_widgets.dart';
import 'study/ai_lesson_generator.dart';
import 'study/study_exercise.dart';

/// Duolingo-style study tab: deck map with XP/streak, tap to choose lesson type.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _xp = 0;
  int _gems = 0;
  int _streak = 0;
  int _dailyGoal = 50;
  List<StudyExercise> _customExercises = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final list = await ExerciseStore.loadCustom();
    if (!mounted) return;
    setState(() => _customExercises = list);
  }

  Future<void> _loadStats() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _xp = p.getInt('study_xp') ?? 0;
      _gems = p.getInt('study_gems') ?? 0;
      _streak = p.getInt('study_streak') ?? 0;
      _dailyGoal = p.getInt('study_daily_goal') ?? 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    final srs = context.watch<SRSService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFF7F7FB);
    final cardColor = isDark ? const Color(0xFF2A2A32) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Study', style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.military_tech, color: Colors.orange, size: 22),
                const SizedBox(width: 4),
                Text(
                  '$_xp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.diamond, color: Colors.cyan, size: 20),
                const SizedBox(width: 2),
                Text(
                  '$_gems',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

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
                    color: textColor,
                  ),
                ),
              ), // Duolingo: dedicated review button uses weakest-first ordering
              TextButton.icon(
                icon: const Icon(Icons.timelapse, size: 18),
                label: const Text('Review'),
                onPressed: () {
                  final srs = context.read<SRSService>();
                  final weak = srs.dueCards.whereType<SRSCard>().toList()
                    ..sort((a, b) => a.easeFactor.compareTo(b.easeFactor));
                  if (weak.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No cards due.')),
                    );
                    return;
                  }
                  _showTypePickerForList(weak, 'Review had a target');
                },
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
        // ---- exercises section (issue 7): always-playable defaults plus
        // manually created custom exercises
        _buildExercisesSection(theme, isDark, subTextColor),
      ],
    );
  }

  int get dueCount => context.read<SRSService>().dueCount;

  /// Exercises section: default starters + custom exercises, each
  /// playable through the lesson page's type picker. Nothing here needs
  /// SRS decks to exist, so the screen is never a dead end.
  Widget _buildExercisesSection(
    ThemeData theme,
    bool isDark,
    Color subTextColor,
  ) {
    final exercises = [...ExerciseStore.defaults, ..._customExercises];
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: fs(context, 18, 'headers'),
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
                onPressed: _createExercise,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap an exercise, pick a mode and play. Works without any deck.',
            style: TextStyle(fontSize: fs(context, 12), color: subTextColor),
          ),
          const SizedBox(height: 12),
          for (final exercise in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 0,
                color: isDark
                    ? const Color(0xFF2A2A32)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    exercise.id.startsWith('starter_')
                        ? Icons.school_outlined
                        : Icons.edit_note_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    exercise.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${exercise.pairs.length} pairs',
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: subTextColor,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!exercise.id.startsWith('starter_'))
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete exercise',
                          onPressed: () => _deleteExercise(exercise),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: exercise.isPlayable
                      ? () => _playExercise(exercise)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Exercise pairs → throwaway SRSCards so the shared lesson page can
  /// run every mode. Grading calls srs.reviewCard with an id the SRS
  /// store does not hold, which is a no-op there — exercise progress
  /// stays inside the lesson.
  void _playExercise(StudyExercise exercise) {
    final cards = [
      for (var i = 0; i < exercise.pairs.length; i++)
        SRSCard.newCard(
          id: 'ex_${exercise.id}_$i',
          word: exercise.pairs[i].front,
          meaning: exercise.pairs[i].back,
        ),
    ];
    _showTypePickerForList(cards, exercise.title);
  }

  /// Manual exercise creation: title + front/back pair rows.
  Future<void> _createExercise() async {
    final titleCtrl = TextEditingController();
    final fronts = <TextEditingController>[];
    final backs = <TextEditingController>[];
    void addRow() {
      fronts.add(TextEditingController());
      backs.add(TextEditingController());
    }

    addRow();
    addRow();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New exercise',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SizedBox(
                  height: 280,
                  child: ListView.builder(
                    itemCount: fronts.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fronts[i],
                              decoration: const InputDecoration(
                                hintText: 'Front (word)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: backs[i],
                              decoration: const InputDecoration(
                                hintText: 'Back (meaning)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: fronts.length <= 2
                                ? null
                                : () => setSheet(() {
                                    fronts.removeAt(i);
                                    backs.removeAt(i);
                                  }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add row'),
                    onPressed: () => setSheet(addRow),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final pairs = <ExercisePair>[
                        for (var i = 0; i < fronts.length; i++)
                          if (fronts[i].text.trim().isNotEmpty)
                            ExercisePair(
                              front: fronts[i].text.trim(),
                              back: backs[i].text.trim(),
                            ),
                      ];
                      if (title.isEmpty || pairs.length < 2) return;
                      final exercise = StudyExercise(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        pairs: pairs,
                      );
                      final next = [..._customExercises, exercise];
                      await ExerciseStore.saveCustom(next);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() => _customExercises = next);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExercise(StudyExercise exercise) async {
    final next = _customExercises.where((e) => e.id != exercise.id).toList();
    await ExerciseStore.saveCustom(next);
    if (mounted) setState(() => _customExercises = next);
  }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckNode(SrsDeck deck, Color color, bool hasDue) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
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
            color: subTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showTypePicker(SrsDeck deck) {
    final cards = context.read<SRSService>().getDueCardsByDeck(deck.id);
    _showTypePickerForList(cards, deck.name);
  }

  /// Show the same picker but over an arbitrary card list (cross-deck).
  void _showTypePickerForList(List<SRSCard> cards, String title) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _LessonTypeSheet(
        deck: null,
        titleOverride: title,
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
          // Record the lesson start
          final p = await SharedPreferences.getInstance();
          final dayStart =
              DateTime.now().millisecondsSinceEpoch -
              (DateTime.now().millisecondsSinceEpoch % (24 * 3600 * 1000));
          final k = 'study_daily_done_$dayStart';
          await p.setInt(k, (p.getInt(k) ?? 0) + 1);
          if (mounted) await _loadStats();
        },
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily goal',
                style: TextStyle(
                  fontSize: fs(ctx, 18, 'headers'),
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...[25, 50, 100, 200].map(
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
                  title: Text(
                    '$g XP',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LessonTypeSheet extends StatelessWidget {
  final SrsDeck? deck;
  final String? titleOverride;
  final int cardCount;
  final void Function(LessonType) onPick;

  const _LessonTypeSheet({
    this.deck,
    this.titleOverride,
    required this.cardCount,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final title = titleOverride ?? deck?.name ?? 'Lesson';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '$cardCount cards',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
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
                  _modeChip(
                    context,
                    LessonType.cloze,
                    'Fill blank',
                    Icons.short_text,
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
