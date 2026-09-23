import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/study/ai_exercise_parser.dart';

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

    test('object-shaped choices upgrade tolerated', () {
      const raw = '''
[{"type":"mc","prompt":"猫","choices":[{"text":"cat","correct":true},{"text":"dog"},{"text":"bird"}],"answer":"cat"}]
''';
      final r = AiLessonResult.parse(raw);
      final ex = r.exercises.single;
      expect(ex.choices, ['cat', 'dog', 'bird']);
      expect(ex.answer, 'cat');
    });

    test('index answers resolve to choice text', () {
      const raw =
          '[{"type":"mc","prompt":"犬","choices":["dog","cat","bird"],"answer":0}]';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.single.answer, 'dog');
    });

    test('wrapped object array accepted', () {
      const raw =
          '{"exercises":[{"type":"written","prompt":"to drink","answer":"飲む"}]}';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 1);
      expect(r.exercises.single.answer, '飲む');
    });

    test('one malformed exercise skipped, rest survive', () {
      const raw = '''
[
  {"type":"flashcard","prompt":"a","answer":"b"},
  {"type":"mc","prompt":"broken","choices":"not-a-list","answer":true},
  {"type":"written","prompt":"c","answer":"d"}
]
''';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 2);
      expect(r.exercises[0].prompt, 'a');
      expect(r.exercises[1].prompt, 'c');
    });

    test('type aliases normalized', () {
      const raw = '''
[
  {"type":"multiple_choice","prompt":"x","choices":["a","b"],"answer":"a"},
  {"type":"listen","prompt":"y","choices":["c","d"],"answer":"d"},
  {"type":"speaking","prompt":"z","answer":"z"}
]
''';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises[0].type, 'mc');
      expect(r.exercises[1].type, 'listening');
      expect(r.exercises[2].type, 'spoken');
    });

    test('pairs accept word/meaning keys and arrays', () {
      const raw = '''
[
  {"type":"match","pairs":[{"word":"犬","meaning":"dog"},{"word":"猫","meaning":"cat"}],"answer":""},
  {"type":"match","pairs":[["日","sun"],["月","moon"]],"answer":""}
]
''';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises[0].pairs![0]['left'], '犬');
      expect(r.exercises[0].pairs![0]['right'], 'dog');
      expect(r.exercises[1].pairs![1]['left'], '月');
      expect(r.exercises[1].pairs![1]['right'], 'moon');
    });

    test('limit slices after parse', () {
      final raw =
          '[${List.generate(60, (i) => '{"type":"flashcard","prompt":"w$i","answer":"m$i"}').join(',')}]';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 60);
      expect(r.exercises.take(50).length, 50);
    });

    test('duplicate prompts deduped (normalized)', () {
      const raw = '''
[
  {"type":"flashcard","prompt":"  Cat ","answer":"猫"},
  {"type":"flashcard","prompt":"cat","answer":"猫"},
  {"type":"written","prompt":"cat   here","answer":"x"},
  {"type":"written","prompt":"cat here","answer":"y"}
]
''';
      final r = AiLessonResult.parse(raw);
      expect(r.exercises.length, 2);
      expect(r.exercises[0].prompt.trim(), 'Cat');
      expect(r.exercises[1].prompt, 'cat   here');
    });
  });
}
