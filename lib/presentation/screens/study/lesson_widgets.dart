import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/screen_size.dart';
import 'ai_exercise_parser.dart';

/// Bottom sheet listing per-character/word breakdown parts.
class BreakdownSheet extends StatelessWidget {
  final List<AiBreakdownPart> parts;
  final String title;

  const BreakdownSheet({
    super.key,
    required this.parts,
    this.title = 'Breakdown',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final p in parts)
                    ListTile(
                      dense: true,
                      leading: Text(
                        p.char,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(p.reading ?? ''),
                      subtitle: Text(p.meaning),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cache for breakdown lookups so repeated words don't refire AI calls.
class BreakdownCache {
  final Future<List<Map<String, String>>> Function(
    String word, {
    String? apiKey,
  })
  _fetch;
  final Map<String, List<AiBreakdownPart>> _cache = {};

  BreakdownCache(this._fetch);

  Future<List<AiBreakdownPart>> get(String word, {String? apiKey}) async {
    final key = word.trim();
    if (key.isEmpty) return const [];
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final raw = await _fetch(key, apiKey: apiKey);
      final parts = raw
          .map(AiBreakdownPart.fromJson)
          .where((p) => p.char.isNotEmpty)
          .toList();
      _cache[key] = parts;
      return parts;
    } catch (_) {
      _cache[key] = const [];
      return const [];
    }
  }
}

/// Shape of a single study-session step produced by any lesson type.
/// The lesson page shows [prompt] to the user and calls [onAnswer]
/// when pressed; [isInput] indicates the user types instead of taps.
class LessonStep {
  final Widget prompt;
  final String correctAnswer;
  final List<String>? choices;
  final String promptLabel;

  const LessonStep({
    required this.prompt,
    required this.correctAnswer,
    this.choices,
    this.promptLabel = '',
  });

  /// True if this is a write-it-yourself step (no choices rendered).
  bool get isWritten => choices == null;
}

/// One of the question shapes we support.
enum LessonType {
  flashcard,
  multipleChoice,
  written,
  kanji,
  drawing,
  listening,
  spoken,
  character,

  /// Duolingo "match the pairs": two columns of tiles; tap one per side.
  matchWords,

  /// Clozemaster-style: sentence with the target word removed; pick one of
  /// 4 options or type it (same word + meaning space as flashcard, but the
  /// prompt is a sentence with "____").
  cloze,
}

/// Data for a match-pairs round: word-meaning pairs shuffled.
class MatchPair {
  final String left; // word
  final String right; // meaning
  const MatchPair(this.left, this.right);
}

/// Interactive match-pairs view: tap one from left, then one from right.
class MatchWordsView extends StatefulWidget {
  final List<MatchPair> pairs;
  final ValueChanged<bool> onRoundDone; // true if all correct

  const MatchWordsView({
    super.key,
    required this.pairs,
    required this.onRoundDone,
  });

  @override
  State<MatchWordsView> createState() => _MatchWordsViewState();
}

class _MatchWordsViewState extends State<MatchWordsView> {
  late final List<MatchPair> _shuffledLeft;
  late final List<MatchPair> _shuffledRight;
  int? _leftSelected;
  int? _rightSelected;
  final Set<int> _matchedLeft = {};
  final Set<int> _matchedRight = {};
  int _incorrectGuesses = 0;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _shuffledLeft = List.of(widget.pairs)..shuffle(rng);
    _shuffledRight = List.of(widget.pairs)..shuffle(rng);
  }

  void _tapLeft(int i) {
    setState(() => _leftSelected = i);
  }

  void _tapRight(int i) {
    setState(() {
      _rightSelected = i;
    });
    if (_leftSelected != null) _check();
  }

  void _check() {
    final l = _leftSelected;
    final r = _rightSelected;
    if (l == null || r == null) return;
    final left = _shuffledLeft[l];
    final right = _shuffledRight[r];
    if (left == right) {
      _matchedLeft.add(l);
      _matchedRight.add(r);
      _leftSelected = null;
      _rightSelected = null;
      if (_matchedLeft.length == widget.pairs.length) {
        final correct = _incorrectGuesses == 0;
        widget.onRoundDone(correct);
      }
    } else {
      _incorrectGuesses++;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ScreenSize.adaptivePadding(context),
      child: Column(
        children: [
          Text(
            'Match the pairs',
            style: TextStyle(
              fontSize: fs(context, 20, 'headers'),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _tileColumn(_shuffledLeft, true)),
                const SizedBox(width: 16),
                Expanded(child: _tileColumn(_shuffledRight, false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileColumn(List<MatchPair> list, bool isLeft) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final selected = isLeft ? _leftSelected == i : _rightSelected == i;
        final matched = isLeft
            ? _matchedLeft.contains(i)
            : _matchedRight.contains(i);
        final label = isLeft ? list[i].left : list[i].right;
        return Opacity(
          opacity: matched ? 0.3 : 1,
          child: InkWell(
            onTap: matched ? null : () => isLeft ? _tapLeft(i) : _tapRight(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: matched
                      ? Colors.green
                      : (selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.3)
                            : Colors.grey.shade300),
                  width: matched ? 2 : 1.5,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fs(context, 16, 'words'),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Common chrome around every lesson page: progress bar + close button.
class LessonScaffold extends StatelessWidget {
  final int current;
  final int total;
  final Widget child;
  final VoidCallback onSkip;
  final VoidCallback onExit;
  final double strength; // 0..1, glowing bar shown next to progress

  const LessonScaffold({
    super.key,
    required this.current,
    required this.total,
    required this.child,
    required this.onSkip,
    required this.onExit,
    this.strength = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1B1F) : const Color(0xFFF7F7FB);
    final barBg = isDark ? theme.colorScheme.surface : Colors.white;
    final progressTrack = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    final barColor = strength >= 0.8
        ? Colors.green
        : (strength >= 0.4 ? Colors.amber : Colors.red.shade400);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: barBg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onExit),
        title: Text('$current / $total'),
      ),
      body: Column(
        children: [
          // step progress
          LinearProgressIndicator(
            value: progress,
            backgroundColor: progressTrack,
            minHeight: 4,
          ),
          // strength bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: strength.clamp(0.0, 1.0),
                backgroundColor: progressTrack,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 8,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 4-option multiple choice grid (Duolingo "Match" style).
///
/// [meanings] are localized strings, with `correctIndex` the right one.
class MultipleChoiceView extends StatelessWidget {
  final String word;
  final String? subLabel;
  final List<String> meanings;
  final int correctIndex;
  final void Function(int picked) onPick;

  const MultipleChoiceView({
    super.key,
    required this.word,
    this.subLabel,
    required this.meanings,
    required this.correctIndex,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // theme-aware surfaces: the app is dark by default, so hardcoding
    // white cards rendered white-on-white text (invisible)
    final promptBg = isDark ? theme.colorScheme.surface : Colors.white;
    final optionBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : Colors.white;
    final optionBorder = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.3)
        : Colors.grey.shade300;
    final correctBg = isDark
        ? Colors.lightGreen.withValues(alpha: 0.15)
        : Colors.lightGreen.shade50;

    return Padding(
      padding: ScreenSize.adaptivePadding(context),
      child: Column(
        children: [
          // prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: promptBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subLabel!,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: meanings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: i == correctIndex ? correctBg : optionBg,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: optionBorder),
                  ),
                ),
                onPressed: () => onPick(i),
                child: Text(
                  meanings[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-form text input for written answers.
class WrittenEntryField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const WrittenEntryField({
    super.key,
    required this.label,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;
    final fieldBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : Colors.white;
    final fieldBorder = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.3)
        : Colors.grey.shade300;
    return Padding(
      padding: ScreenSize.adaptivePadding(context),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Type the answer…',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF58CC02)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.check),
              label: const Text('Check'),
            ),
          ),
        ],
      ),
    );
  }
}

/// True/False overlay banner after answering one step.
class GradeBanner extends StatelessWidget {
  final bool correct;
  final String correctAnswer;
  final VoidCallback onContinue;

  const GradeBanner({
    super.key,
    required this.correct,
    required this.correctAnswer,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF58CC02) : Colors.red.shade400;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  correct ? 'Correct!' : 'Not quite…',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (!correct) ...[
              const SizedBox(height: 8),
              Text(
                'Answer: $correctAnswer',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(backgroundColor: color),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
