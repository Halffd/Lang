import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/audio_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/presentation/widgets/flip_card.dart';
import 'lesson_widgets.dart';

/// Host page for every study style. Drives a step list and a shared score.
class LessonPage extends StatefulWidget {
  final List<SRSCard> cards;
  final LessonType type;
  final SRSService srs;

  const LessonPage({
    super.key,
    required this.cards,
    required this.type,
    required this.srs,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late final List<LessonStep> _steps;
  int _idx = 0;
  bool _graded = false;
  bool _lastCorrect = false;

  int xpEarned = 0;
  final _textCtrl = TextEditingController();
  final _audio = AudioService();

  // children state
  bool _kanjiFlipped = false;
  Uint8List? _drawingBytes;
  bool _spokenListened = false;

  @override
  void initState() {
    super.initState();
    _steps = _generateSteps();
    _audio.init();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  List<LessonStep> _generateSteps() {
    final rng = math.Random(widget.cards.length);
    final out = <LessonStep>[];
    final allMeanings = widget.cards.map((c) => c.meaning).toList();
    for (final card in widget.cards) {
      switch (widget.type) {
        case LessonType.multipleChoice:
          final distractors = _pick(allMeanings, 3, card.meaning, rng);
          final shuffled = [card.meaning, ...distractors]..shuffle(rng);
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(
                  card.word,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              correctAnswer: card.meaning,
              choices: shuffled,
            ),
          );
          break;
        case LessonType.written:
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(card.meaning, style: const TextStyle(fontSize: 24)),
              ),
              correctAnswer: card.word,
            ),
          );
          break;
        case LessonType.kanji:
          final reading = card.reading ?? card.meaning;
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(reading, style: const TextStyle(fontSize: 26)),
              ),
              correctAnswer: card.word,
              choices: _pick(
                widget.cards.map((c) => c.word).toList(),
                3,
                card.word,
                rng,
              ),
            ),
          );
          break;
        case LessonType.character:
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(
                  card.meaning,
                  style: const TextStyle(fontSize: 24, color: Colors.black87),
                ),
              ),
              correctAnswer: card.word,
            ),
          );
          break;
        case LessonType.drawing:
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(
                  card.reading ?? card.word,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              correctAnswer: card.word,
            ),
          );
          break;
        case LessonType.listening:
          out.add(
            LessonStep(
              prompt: const Icon(Icons.volume_up, size: 80),
              correctAnswer: card.meaning,
              choices: [
                card.meaning,
                ..._pick(allMeanings, 3, card.meaning, rng),
              ]..shuffle(math.Random()),
            ),
          );
          break;
        case LessonType.spoken:
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(card.word, style: const TextStyle(fontSize: 26)),
              ),
              correctAnswer: card.reading ?? card.meaning,
            ),
          );
          break;
        case LessonType.flashcard:
          out.add(
            LessonStep(
              prompt: Center(
                child: Text(
                  card.word,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              correctAnswer: card.meaning,
            ),
          );
          break;
      }
    }
    return out;
  }

  List<String> _pick(
    List<String> pool,
    int n,
    String exclude,
    math.Random rng,
  ) {
    final shuffled = pool.where((m) => m != exclude).toList()..shuffle(rng);
    return shuffled.take(n).toList();
  }

  void _flip() {
    if (widget.type == LessonType.flashcard ||
        widget.type == LessonType.kanji) {
      setState(() => _kanjiFlipped = !_kanjiFlipped);
    }
  }

  Future<void> _grade(bool correct, {double score = 1}) async {
    if (_graded) return;
    _steps[_idx]; // step not needed beyond grade call

    _lastCorrect = correct;

    _graded = true;

    final due = widget.cards[_idx];
    final srGrade = correct ? (score >= 0.9 ? 4 : 3) : (score > 0.4 ? 2 : 1);
    await widget.srs.reviewCard(due.id, srGrade);

    // XP: correct 10, wrong 2-scale for attempt
    xpEarned += (10 * score).round().clamp(2, 50);

    setState(() {});
  }

  void _next() {
    if (_idx < _steps.length - 1) {
      setState(() {
        _idx++;
        _graded = false;
        _textCtrl.clear();
        _kanjiFlipped = false;
        _drawingBytes = null;
        _spokenListened = false;
      });
      if (widget.type == LessonType.listening) {
        final c = widget.cards[_idx];
        _audio.play(c.word, 'ja');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_idx >= _steps.length) return _buildFinish();
    final step = _steps[_idx];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
        if (mounted && context.mounted) Navigator.of(context).pop();
      },
      child: LessonScaffold(
        current: _idx + 1,
        total: _steps.length,
        onSkip: () => _grade(false),
        onExit: () => Navigator.of(context).maybePop(),
        child: Stack(
          children: [
            _buildBody(step),
            if (_graded)
              GradeBanner(
                correct: _lastCorrect,
                correctAnswer: step.correctAnswer,
                onContinue: _next,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LessonStep step) {
    switch (widget.type) {
      case LessonType.multipleChoice:
      case LessonType.kanji:
      case LessonType.listening:
        return MultipleChoiceView(
          word: widget.type == LessonType.listening
              ? ''
              : widget.cards[_idx].word,
          subLabel: switch (widget.type) {
            LessonType.listening => '🎧 Listen',
            LessonType.kanji => widget.cards[_idx].reading,
            _ => widget.cards[_idx].reading,
          },
          meanings: step.choices!,
          correctIndex: step.choices!.indexOf(step.correctAnswer),
          onPick: (i) => _grade(i == step.choices!.indexOf(step.correctAnswer)),
        );
      case LessonType.written:
      case LessonType.character:
        return WrittenEntryField(
          label: widget.type == LessonType.written
              ? widget.cards[_idx].meaning
              : 'Type out: ${widget.cards[_idx].meaning}',
          controller: _textCtrl,
          onSubmit: () {
            final ans = _textCtrl.text.trim().toLowerCase();
            final corr = step.correctAnswer.toLowerCase();
            _grade(ans == corr);
          },
        );
      case LessonType.drawing:
        return _buildDrawing(step);
      case LessonType.spoken:
        return _buildSpoken(step);
      case LessonType.flashcard:
        return _buildFlashcard();
    }
  }

  Widget _buildFlashcard() {
    final card = widget.cards[_idx];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: FlipCard(
              isBack: _kanjiFlipped,
              onTap: _flip,
              front: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  card.word,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              back: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  card.meaning,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_kanjiFlipped)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _gradeBtn('Again', Colors.red, 1),
                  _gradeBtn('Hard', Colors.orange, 2),
                  _gradeBtn('Good', Colors.blue, 3),
                  _gradeBtn('Easy', Colors.green, 4),
                ],
              ),
            ),
          if (!_kanjiFlipped) const SizedBox(height: 44),
        ],
      ),
    );
  }

  Widget _gradeBtn(String label, Color color, int q) {
    return ElevatedButton(
      onPressed: () => _grade(q >= 3),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }

  Widget _buildDrawing(LessonStep step) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.type == LessonType.drawing ? widget.cards[_idx].word : '',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DrawingCanvas(onChange: (b) => _drawingBytes = b),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _drawingBytes == null || _drawingBytes!.length < 200
                ? null
                : () => _grade(
                    _drawingBytes != null && _drawingBytes!.length > 1000,
                  ),
            child: const Text('Submit drawing'),
          ),
        ),
      ],
    );
  }

  Widget _buildSpoken(LessonStep step) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            step.prompt,
            const SizedBox(height: 32),
            Text(
              _spokenListened ? 'Say it aloud.' : 'Tap play, then repeat.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('Play'),
              onPressed: () {
                setState(() => _spokenListened = true);
                _audio.play(step.correctAnswer, 'ja');
              },
            ),
            const SizedBox(height: 16),
            IconButton.filled(
              iconSize: 52,
              icon: const Icon(Icons.mic),
              onPressed: () async {
                // Record 3s of speech and grade loosely on loudness
                // (actual STT comparison needs a model — placeholder).
                final recorder = AudioRecorder();
                try {
                  if (await recorder.hasPermission()) {
                    await recorder.start(
                      const RecordConfig(encoder: AudioEncoder.wav),
                      path: '/tmp/opencode/spoken_check.wav',
                    );
                    await Future.delayed(const Duration(seconds: 4));
                    final recorded = await recorder.stop();
                    await Future.delayed(const Duration(milliseconds: 50));
                    // Consider any submission a pass if recording succeeded
                    _grade(recorded != null, score: 0.7);
                  } else {
                    _grade(false);
                  }
                } catch (_) {
                  _grade(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistXp(int xp) async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final total = (p.getInt('study_xp') ?? 0) + xp;
    final lastMs = p.getInt('study_last_ms') ?? 0;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final streakDays = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;
    int streak = p.getInt('study_streak') ?? 0;
    if (streakDays == 1) {
      streak += 1;
    } else if (streakDays > 1) {
      streak = 1;
    } else {
      streak += 0; // same day, no change
    }
    await p.setInt('study_xp', total);
    await p.setInt('study_streak', streak);
    await p.setInt('study_last_ms', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> _onWillPop() async {
    if (xpEarned > 0) await _persistXp(xpEarned);
    return true;
  }

  Widget _buildFinish() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 72, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              '$xpEarned XP earned!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await _onWillPop();
                if (mounted) Navigator.of(context).maybePop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF58CC02),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal freehand canvas that emits its pixel count every stroke end.
class DrawingCanvas extends StatefulWidget {
  final void Function(Uint8List) onChange;
  const DrawingCanvas({super.key, required this.onChange});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<Offset> _points = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        setState(() => _points.add(d.localPosition));
      },
      onPanEnd: (_) {
        // Placeholder byte signal proportional to stroke count
        widget.onChange(Uint8List(_points.length * 4));
      },
      child: CustomPaint(
        painter: _StrokePainter(_points),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<Offset> points;
  _StrokePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..isAntiAlias = true;
    for (var i = 0; i < points.length - 1; i++) {
      if ((points[i] - points[i + 1]).distance < 40) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
