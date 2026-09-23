import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lang/core/services/audio_service.dart';
import 'ai_exercise_parser.dart';
import 'lesson_widgets.dart';

/// Self-contained lesson experience driven entirely by AI JSON.
class AiLessonPage extends StatefulWidget {
  final AiLessonResult lesson;
  final String? prompt;
  final String title;

  const AiLessonPage({
    super.key,
    required this.lesson,
    this.prompt,
    this.title = 'AI lesson',
  });

  @override
  State<AiLessonPage> createState() => _AiLessonPageState();
}

class _AiLessonPageState extends State<AiLessonPage> {
  int _idx = 0;
  bool _graded = false;
  bool _lastCorrect = false;
  double _strength = 0;
  int _xp = 0;
  final _textCtrl = TextEditingController();
  final _flip = ValueNotifier<bool>(false);
  final _audio = AudioService();
  static const _lessonLang = 'ja';

  AiExercise get _current => widget.lesson.exercises[_idx];

  @override
  void initState() {
    super.initState();
    // Warm the TTS engine once at lesson start so the first listening
    // exercise has no spawn blip (espeak binary page-cache + language set).
    _audio.init().then((_) {
      if (mounted && _current.type == 'listening') _playCurrent();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _playCurrent() {
    final prompt = _current.prompt;
    if (prompt.trim().isEmpty) return;
    _audio.play(prompt, _lessonLang);
  }

  void _grade(bool correct, {double score = 1}) {
    if (_graded) return;
    setState(() {
      _graded = true;
      _lastCorrect = correct;
      if (correct) {
        _strength += 0.25 * score;
        _xp += (10 * score).round().clamp(2, 50);
      } else {
        _strength = math.max(0, _strength - 0.15);
      }
    });
  }

  void _next() {
    setState(() {
      _graded = false;
      _textCtrl.clear();
      _flip.value = false;
      if (_idx < widget.lesson.exercises.length - 1) _idx++;
    });
    // listening steps play their prompt on entry; others stay silent
    if (_current.type == 'listening') _playCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.lesson.exercises.length;
    if (_idx >= total) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                '$_xp XP',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    final ex = _current;
    return LessonScaffold(
      current: _idx + 1,
      total: total,
      onSkip: () => _grade(false),
      onExit: () => Navigator.of(context).pop(),
      strength: _strength,
      child: Stack(
        children: [
          _buildExercise(ex),
          if (_graded)
            GradeBanner(
              correct: _lastCorrect,
              correctAnswer: ex.answer,
              onContinue: _next,
            ),
        ],
      ),
    );
  }

  Widget _buildExercise(AiExercise ex) {
    switch (ex.type) {
      case 'flashcard':
        return ValueListenableBuilder<bool>(
          valueListenable: _flip,
          builder: (_, flipped, _) => _FlashcardStep(
            front: ex.prompt,
            frontSub: ex.promptSub,
            back: ex.answer,
            flipped: flipped,
            onFlip: () => _flip.value = true,
            onGrade: (q) => _grade(q),
          ),
        );
      case 'mc':
      case 'listening':
        return Column(
          children: [
            if (ex.type == 'listening')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: IconButton.filledTonal(
                  iconSize: 40,
                  tooltip: 'Replay',
                  onPressed: _playCurrent,
                  icon: const Icon(Icons.volume_up),
                ),
              ),
            Expanded(
              child: MultipleChoiceView(
                word: ex.type == 'listening' ? '' : ex.prompt,
                subLabel: ex.promptSub,
                meanings: ex.choices ?? const [],
                correctIndex: (ex.choices ?? []).indexOf(ex.answer),
                onPick: (i) =>
                    _grade(i == (ex.choices ?? []).indexOf(ex.answer)),
              ),
            ),
          ],
        );
      case 'written':
      case 'cloze':
        return WrittenEntryField(
          label: ex.prompt,
          controller: _textCtrl,
          onSubmit: () => _grade(
            _textCtrl.text.trim().toLowerCase() == ex.answer.toLowerCase(),
          ),
        );
      case 'match':
        return MatchWordsView(
          pairs: (ex.pairs ?? [])
              .map((p) => MatchPair(p['left'] ?? '', p['right'] ?? ''))
              .toList(),
          onRoundDone: (ok) => _grade(ok, score: ok ? 1 : 0.5),
        );
      case 'spoken':
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ex.prompt, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('I said it'),
                onPressed: () => _grade(true),
              ),
            ],
          ),
        );
      default:
        return Center(child: Text('Unknown exercise type: ${ex.type}'));
    }
  }
}

/// Flashcard step rendered as a flip card.
class _FlashcardStep extends StatelessWidget {
  final String front;
  final String? frontSub;
  final String back;
  final bool flipped;
  final VoidCallback onFlip;
  final void Function(bool correct) onGrade;

  const _FlashcardStep({
    required this.front,
    this.frontSub,
    required this.back,
    required this.flipped,
    required this.onFlip,
    required this.onGrade,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: flipped ? null : onFlip,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: flipped ? Colors.indigo : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flipped ? back : front,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: flipped ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (!flipped && frontSub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            frontSub!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (flipped)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _btn('Again', Colors.red, () => onGrade(false)),
                _btn('Good', Colors.green, () => onGrade(true)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback f) => ElevatedButton(
    onPressed: f,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
    ),
    child: Text(label),
  );
}
