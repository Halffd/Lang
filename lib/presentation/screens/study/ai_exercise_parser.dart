import 'dart:convert';

/// One generated exercise element.
///
/// Parsing is intentionally paranoid: LLMs omit optional fields, upgrade
/// schemas mid-response (choices as objects), and mix field types. Never
/// trust shape — see [AiExercise.fromJson].
class AiExercise {
  final String type; // flashcard, mc, written, cloze, match, spoken, listening
  final String prompt;
  final String? promptSub;
  final String answer;
  final List<String>? choices;
  final List<Map<String, String>>? pairs; // 'match': [{left, right}, ...]
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

  /// Defensive parse: tolerates missing fields, numeric values where strings
  /// are expected, and object-shaped choices ({text, correct}).
  factory AiExercise.fromJson(Map<String, dynamic> json) {
    List<AiBreakdownPart>? bd;
    if (json['breakdown'] is List) {
      bd = (json['breakdown'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AiBreakdownPart.fromJson)
          .toList();
    }

    // choices: either ["a","b"] or [{"text":"a","correct":true}, ...]
    List<String>? choices;
    final rawChoices = json['choices'] ?? json['options'];
    if (rawChoices is List) {
      choices = [
        for (final e in rawChoices)
          if (e is Map<String, dynamic>)
            (e['text'] ?? e['value'] ?? '').toString()
          else
            e.toString(),
      ].where((s) => s.isNotEmpty).toList();
    }

    // pairs: [{left,right}] or [{word, meaning}] or [[left, right]]
    List<Map<String, String>>? pairs;
    final rawPairs = json['pairs'] ?? json['matches'];
    if (rawPairs is List) {
      pairs = [
        for (final e in rawPairs)
          if (e is Map<String, dynamic>)
            {
              'left': (e['left'] ?? e['word'] ?? '').toString(),
              'right': (e['right'] ?? e['meaning'] ?? '').toString(),
            }
          else if (e is List && e.length >= 2)
            {'left': e[0].toString(), 'right': e[1].toString()},
      ].where((p) => p['left']!.isNotEmpty && p['right']!.isNotEmpty).toList();
    }

    return AiExercise(
      type: _normalizeType(json['type']?.toString()),
      prompt: (json['prompt'] ?? json['question'] ?? json['word'] ?? '')
          .toString(),
      promptSub:
          (json['prompt_sub'] ?? json['promptSub'] ?? json['hint'] as Object?)
              ?.toString(),
      answer: _pickAnswer(json, choices),
      choices: (choices != null && choices.length >= 2) ? choices : null,
      pairs: (pairs != null && pairs.length >= 2) ? pairs : null,
      breakdown: bd,
    );
  }

  static String _normalizeType(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'flashcard':
      case 'card':
        return 'flashcard';
      case 'mc':
      case 'multiple_choice':
      case 'multiplechoice':
      case 'choice':
        return 'mc';
      case 'written':
      case 'write':
      case 'typing':
        return 'written';
      case 'cloze':
      case 'fill_blank':
      case 'fill-in-the-blank':
        return 'cloze';
      case 'match':
      case 'matchwords':
      case 'match_words':
        return 'match';
      case 'listening':
      case 'listen':
        return 'listening';
      case 'spoken':
      case 'speaking':
      case 'speak':
        return 'spoken';
      default:
        return 'flashcard'; // never trust it's present
    }
  }

  /// Answer may be a bare string, an index into choices, or the text of the
  /// correct choice object.
  static String _pickAnswer(Map<String, dynamic> json, List<String>? choices) {
    final raw = json['answer'] ?? json['correct'];
    if (raw == null) return '';
    if (raw is num && choices != null) {
      final i = raw.toInt();
      if (i >= 0 && i < choices.length) return choices[i];
    }
    return raw.toString();
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'prompt': prompt,
    if (promptSub != null) 'prompt_sub': promptSub,
    'answer': answer,
    if (choices != null) 'choices': choices,
    if (pairs != null) 'pairs': pairs,
    if (breakdown != null)
      'breakdown': [
        for (final b in breakdown!)
          {
            'char': b.char,
            if (b.reading != null) 'reading': b.reading,
            'meaning': b.meaning,
          },
      ],
  };
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
    char: (m['char'] ?? m['word'] ?? m['part'] ?? '').toString(),
    reading: (m['reading'] ?? m['kana'] as Object?)?.toString(),
    meaning: (m['meaning'] ?? m['definition'] ?? '').toString(),
  );
}

/// Generic AI lesson prompt — schema spec lives here so prompt tuning never
/// recompiles widget code.
const kAiLessonScratchPrompt = '''
Return a JSON array and nothing else — no prose, no markdown fences. Each element is one exercise:
{"type":"flashcard","prompt":"word or sentence","prompt_sub":"reading","answer":"meaning or translation"}
{"type":"mc","prompt":"word","prompt_sub":"reading","choices":["a","b","c","d"],"answer":"<one of choices>"}
{"type":"written","prompt":"meaning or translation","answer":"<the original language text>"}
{"type":"cloze","prompt":"sentence with ____ blank","answer":"<missing word>","choices":["opt1","opt2","opt3","opt4"]}
{"type":"match","pairs":[{"left":"word1","right":"meaning1"},{"left":"word2","right":"meaning2"}],"answer":""}
{"type":"listening","prompt":"word the learner will hear via TTS","choices":["a","b","c","d"],"answer":"<one of choices>"}
{"type":"spoken","prompt":"word to repeat aloud","answer":"word"}
Exercises may carry an optional "breakdown": [{"char":"漢","reading":"かん","meaning":"gloss"}] with per-character parts for CJK prompts.
HARD CONSTRAINT: the array must contain at most the requested number of exercises.''';

class AiLessonResult {
  final List<AiExercise> exercises;

  const AiLessonResult(this.exercises);

  /// Top-level parse: strips fences, then parses items ONE AT A TIME —
  /// one malformed exercise is skipped, the other 49 survive.
  static AiLessonResult parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '');
      s = s.replaceAll(RegExp(r'```$'), '');
    }
    final decoded = jsonDecode(s);
    final List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      // model wrapped the array in an object — accept {"exercises": [...]}
      rawList = (decoded['exercises'] ?? decoded['lesson'] ?? []) as List;
    } else {
      return const AiLessonResult([]);
    }

    final exercises = <AiExercise>[];
    for (final item in rawList) {
      try {
        AiExercise? ex;
        if (item is Map<String, dynamic>) {
          ex = AiExercise.fromJson(item);
        } else if (item is Map) {
          ex = AiExercise.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
        // skip unusable ones, don't crash the whole lesson: mc/listening/
        // cloze need choices, match needs pairs (match has no prompt),
        // everything else needs a prompt
        if (ex == null) continue;
        if (ex.type != 'match' && ex.prompt.trim().isEmpty) continue;
        if ((ex.type == 'mc' || ex.type == 'listening' || ex.type == 'cloze') &&
            (ex.choices == null || ex.choices!.length < 2)) {
          continue;
        }
        if (ex.type == 'match' && (ex.pairs == null || ex.pairs!.length < 2)) {
          continue;
        }
        exercises.add(ex);
      } catch (_) {
        continue; // skip bad ones, don't crash the whole lesson
      }
    }
    return AiLessonResult(exercises);
  }
}
