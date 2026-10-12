import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One front/back pair inside a custom exercise.
class ExercisePair {
  final String front;
  final String back;

  const ExercisePair({required this.front, required this.back});

  Map<String, dynamic> toJson() => {'front': front, 'back': back};

  factory ExercisePair.fromJson(Map<String, dynamic> json) => ExercisePair(
    front: json['front']?.toString() ?? '',
    back: json['back']?.toString() ?? '',
  );
}

/// A manually created or default study exercise: a titled list of
/// front/back pairs playable through the lesson page's flashcard and
/// quiz modes.
class StudyExercise {
  final String id;
  final String title;
  final List<ExercisePair> pairs;

  const StudyExercise({
    required this.id,
    required this.title,
    required this.pairs,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'pairs': [for (final p in pairs) p.toJson()],
  };

  factory StudyExercise.fromJson(Map<String, dynamic> json) => StudyExercise(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Exercise',
    pairs: ((json['pairs'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (p) =>
              ExercisePair.fromJson(p.map((k, v) => MapEntry(k.toString(), v))),
        )
        .where((p) => p.front.isNotEmpty)
        .toList(),
  );

  bool get isPlayable => pairs.length >= 2;
}

/// Storage + built-in defaults for the study screen's exercise list.
class ExerciseStore {
  static const _kCustomKey = 'study_custom_exercises';

  /// Load manually created exercises (newest first). Corrupt payloads
  /// fall back to empty instead of failing the screen.
  static Future<List<StudyExercise>> loadCustom() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kCustomKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => StudyExercise.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveCustom(List<StudyExercise> exercises) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kCustomKey,
      jsonEncode([for (final e in exercises) e.toJson()]),
    );
  }

  /// Starter exercises that are always playable, no user data needed.
  static const List<StudyExercise> defaults = [
    StudyExercise(
      id: 'starter_greetings',
      title: 'Starter: Greetings (JP→EN)',
      pairs: [
        ExercisePair(front: 'おはよう', back: 'good morning'),
        ExercisePair(front: 'こんにちは', back: 'hello / good afternoon'),
        ExercisePair(front: 'こんばんは', back: 'good evening'),
        ExercisePair(front: 'ありがとう', back: 'thank you'),
        ExercisePair(front: 'さようなら', back: 'goodbye'),
        ExercisePair(front: 'すみません', back: 'excuse me / sorry'),
        ExercisePair(front: 'はい', back: 'yes'),
        ExercisePair(front: 'いいえ', back: 'no'),
      ],
    ),
    StudyExercise(
      id: 'starter_numbers',
      title: 'Starter: Numbers 1–10 (JP→EN)',
      pairs: [
        ExercisePair(front: '一 (いち)', back: 'one'),
        ExercisePair(front: '二 (に)', back: 'two'),
        ExercisePair(front: '三 (さん)', back: 'three'),
        ExercisePair(front: '四 (よん/し)', back: 'four'),
        ExercisePair(front: '五 (ご)', back: 'five'),
        ExercisePair(front: '六 (ろく)', back: 'six'),
        ExercisePair(front: '七 (なな/しち)', back: 'seven'),
        ExercisePair(front: '八 (はち)', back: 'eight'),
        ExercisePair(front: '九 (きゅう/く)', back: 'nine'),
        ExercisePair(front: '十 (じゅう)', back: 'ten'),
      ],
    ),
    StudyExercise(
      id: 'starter_hiragana',
      title: 'Starter: Hiragana a–ko (kana→romaji)',
      pairs: [
        ExercisePair(front: 'あ', back: 'a'),
        ExercisePair(front: 'い', back: 'i'),
        ExercisePair(front: 'う', back: 'u'),
        ExercisePair(front: 'え', back: 'e'),
        ExercisePair(front: 'お', back: 'o'),
        ExercisePair(front: 'か', back: 'ka'),
        ExercisePair(front: 'き', back: 'ki'),
        ExercisePair(front: 'く', back: 'ku'),
        ExercisePair(front: 'け', back: 'ke'),
        ExercisePair(front: 'こ', back: 'ko'),
      ],
    ),
  ];
}
