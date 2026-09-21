import 'package:flutter/material.dart';

import 'package:lang/utils/screen_size.dart';

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
}

/// Common chrome around every lesson page: progress bar + close button.
class LessonScaffold extends StatelessWidget {
  final int current;
  final int total;
  final Widget child;
  final VoidCallback onSkip;
  final VoidCallback onExit;

  const LessonScaffold({
    super.key,
    required this.current,
    required this.total,
    required this.child,
    required this.onSkip,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: onExit),
        title: Text('$current / $total'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            minHeight: 6,
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
    return Padding(
      padding: ScreenSize.adaptivePadding(context),
      child: Column(
        children: [
          // prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subLabel!,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                  backgroundColor: i == correctIndex
                      ? Colors.lightGreen.shade50
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onPressed: () => onPick(i),
                child: Text(
                  meanings[i],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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
    return Padding(
      padding: ScreenSize.adaptivePadding(context),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
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
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type the answer…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
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
              Text('Answer: $correctAnswer'),
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
