import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'lesson_widgets.dart';

/// One generated exercise element.
class AiExercise {
  final String type; // flashcard, mc, written, cloze, match, spoken, listening
  final String prompt;
  final String? promptSub; // subtitle (reading, translation prompt, etc.)
  final String answer;
  final List<String>? choices;
  final List<Map<String, String>>?
  pairs; // for 'match': [{left: .., right: ..}, ...]
  final List<AiBreakdownPart>? breakdown;

  const AiExercise({
    required this.type,
    required this.prompt,
    this.promptSub,
    required this.answer,
    this.choices,
    this.pairs,
    this.breakdown,
  });

  static AiExercise parse(Map<String, dynamic> m) {
    List<AiBreakdownPart>? bd;
    if (m['breakdown'] is List) {
      bd = (m['breakdown'] as List)
          .whereType<Map<String, dynamic>>()
          .map((b) => AiBreakdownPart.fromJson(b))
          .toList();
    }
    return AiExercise(
      type: m['type']?.toString() ?? 'flashcard',
      prompt: m['prompt']?.toString() ?? '',
      promptSub: m['prompt_sub']?.toString() ?? m['promptSub']?.toString(),
      answer: m['answer']?.toString() ?? '',
      choices: (m['choices'] as List?)?.map((e) => e.toString()).toList(),
      pairs: (m['pairs'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(
            (p) => {
              'left': p['left'].toString(),
              'right': p['right'].toString(),
            },
          )
          .toList(),
      breakdown: bd,
    );
  }
}

class AiBreakdownPart {
  final String char;
  final String? reading;
  final String meaning;

  const AiBreakdownPart({
    required this.char,
    this.reading,
    required this.meaning,
  });

  factory AiBreakdownPart.fromJson(Map<String, dynamic> m) => AiBreakdownPart(
    char: m['char']?.toString() ?? '',
    reading: m['reading']?.toString(),
    meaning: m['meaning']?.toString() ?? '',
  );
}

/// Generic AI lesson prompt (used when no template chosen).
const kAiLessonScratchPrompt =
    '''Generate a language lesson as a JSON array. Each element is an exercise:
{"type":"flashcard","prompt":"word or sentence","prompt_sub":"reading","answer":"meaning or translation"}
{"type":"mc","prompt":"word","prompt_sub":"reading","choices":["a","b","c","d"],"answer":"<one of choices>"}
{"type":"written","prompt":"meaning or translation","answer":"<the original language text>"}
{"type":"cloze","prompt":"sentence with ____ blank","answer":"<missing word>","choices":["opt1","opt2","opt3","opt4"]}
{"type":"match","pairs":[{"left":"word1","right":"meaning1"},{"left":"word2","right":"meaning2"}],"answer":""}
{"type":"listening","prompt":"word to hear via TTS","choices":["a","b","c","d"],"answer":"<one of choices>"}
{"type":"spoken","prompt":"word to repeat","answer":"word"}
Each exercise also gets an optional "breakdown": [{"char":"漢","reading":"かん","meaning":"kanji"}] entry with per-character or per-word breakdown when the prompt contains multiple CJK characters.
Return ONLY the JSON array, no prose, no code fences.''';

class AiLessonResult {
  final List<AiExercise> exercises;

  const AiLessonResult(this.exercises);

  static AiLessonResult parse(String raw) {
    // Strip code fences
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '');
      s = s.replaceAll(RegExp(r'```$'), '');
    }
    final list = jsonDecode(s) as List<dynamic>;
    return AiLessonResult(
      list.whereType<Map<String, dynamic>>().map(AiExercise.parse).toList(),
    );
  }
}

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

  AiExercise get _current => widget.lesson.exercises[_idx];

  @override
  void dispose() {
    _textCtrl.dispose();
    _flip.dispose();
    super.dispose();
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
        return MultipleChoiceView(
          word: ex.type == 'listening' ? '🎧 ${ex.prompt}' : ex.prompt,
          subLabel: ex.promptSub,
          meanings: ex.choices ?? const [],
          correctIndex: (ex.choices ?? []).indexOf(ex.answer),
          onPick: (i) => _grade(i == (ex.choices ?? []).indexOf(ex.answer)),
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
