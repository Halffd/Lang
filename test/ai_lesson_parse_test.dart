import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/study/ai_lesson_page.dart';

void main() {
  group('AiLessonResult.parse', () {
    test('parses plain json array', () {
      const raw = '''
[
  {"type":"flashcard","prompt":"食べる","prompt_sub":"たべる","answer":"to eat"},
  {"type":"mc","prompt":"猫","choices":["cat","dog","bird"],"answer":"cat"},
  {"type":"written","prompt":"to drink","answer":"飲む"},
  {"type":"cloze","prompt":"私はパンを____。","answer":"食べます","choices":["食べます","飲みます","見ます","行きます"]},
  {"type":"match","pairs":[{"left":"犬","right":"dog"},{"left":"猫","right":"cat"}],"answer":""},
  {"type":"listening","prompt":"水","choices":["water","fire","wind","earth"],"answer":"water"},
  {"type":"spoken","prompt":"こんにちは","answer":"こんにちは"}
]
''';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 7);
      expect(r.exercises[0].type, 'flashcard');
      expect(r.exercises[0].promptSub, 'たべる');
      expect(r.exercises[1].choices, ['cat', 'dog', 'bird']);
      expect(r.exercises[3].answer, '食べます');
      expect(r.exercises[4].pairs!.length, 2);
      expect(r.exercises[4].pairs![0]['left'], '犬');
      expect(r.exercises[5].type, 'listening');
      expect(r.exercises[6].answer, 'こんにちは');
    });

    test('strips markdown fences', () {
      const raw =
          '```json\n[{"type":"flashcard","prompt":"a","answer":"b"}]\n```';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 1);
      expect(r.exercises[0].answer, 'b');
    });

    test('defaults type to flashcard', () {
      const raw = '[{"prompt":"x","answer":"y"}]';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.single.type, 'flashcard');
    });

    test('parses breakdown parts', () {
      const raw = '''
[{"type":"flashcard","prompt":"漢字","answer":"kanji",
  "breakdown":[{"char":"漢","reading":"かん","meaning":"china"},{"char":"字","reading":"じ","meaning":"character"}]}]
''';
      final r = AiLessonResult.parse(raw);
      final bd = r.exercises.single.breakdown!;
      expect(bd.length, 2);
      expect(bd[0].char, '漢');
      expect(bd[0].reading, 'かん');
      expect(bd[1].meaning, 'character');
    });

    test('throws on garbage', () {
      expect(
        () => AiLessonResult.parse('not json at all'),
        throwsFormatException,
      );
    });
  });
}
