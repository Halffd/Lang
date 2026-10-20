import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/exercise_bank_service.dart';
import 'package:lang/data/services/exercise_schema.dart';
import 'package:lang/presentation/screens/study/ai_exercise_parser.dart';
import 'package:lang/presentation/screens/study/ai_lesson_generator.dart';

void main() {
  setUpAll(() {
    // ExerciseBankService uses the yomichan database (sqflite FFI in
    // tests via the app's database manager; the table is created
    // on-demand so no schema bump is needed).
  });

  group('ExerciseBankService.dedupeKey', () {
    test('normalizes whitespace and case', () {
      final a = AiExercise(type: 'mc', prompt: 'Hello  World', answer: 'x');
      final b = AiExercise(type: 'mc', prompt: 'hello world', answer: 'y');
      expect(
        ExerciseBankService.dedupeKey(a),
        ExerciseBankService.dedupeKey(b),
      );
    });

    test('match exercises key on pairs, not prompt', () {
      final a = AiExercise(
        type: 'match',
        prompt: '',
        answer: '',
        pairs: [
          const {'left': 'cat', 'right': '猫'},
          const {'left': 'dog', 'right': '犬'},
        ],
      );
      final b = AiExercise(
        type: 'match',
        prompt: 'totally different prompt',
        answer: '',
        pairs: [
          const {'left': 'cat', 'right': '猫'},
          const {'left': 'dog', 'right': '犬'},
        ],
      );
      expect(
        ExerciseBankService.dedupeKey(a),
        ExerciseBankService.dedupeKey(b),
        reason: 'match has no prompt — pairs content is the identity',
      );
    });

    test('different types never collide', () {
      final mc = AiExercise(type: 'mc', prompt: 'same', answer: 'x');
      final cloze = AiExercise(type: 'cloze', prompt: 'same', answer: 'y');
      expect(
        ExerciseBankService.dedupeKey(mc),
        isNot(ExerciseBankService.dedupeKey(cloze)),
      );
    });
  });

  group('ExerciseSchema', () {
    test('gemini schema requires type/prompt/answer on every exercise', () {
      final schema = ExerciseSchema.gemini();
      final exercises = schema['properties']['exercises'] as Map;
      final items = exercises['items'] as Map;
      expect(
        (items['required'] as List),
        containsAll(['type', 'prompt', 'answer']),
      );
      final types = (items['properties']['type'] as Map)['enum'] as List;
      expect(types, containsAll(['flashcard', 'mc', 'cloze', 'match']));
    });

    test('openai strict schema marks all properties required', () {
      final schema = ExerciseSchema.openAi();
      final exercises = schema['properties']['exercises'] as Map;
      final items = exercises['items'] as Map;
      expect(items['additionalProperties'], isFalse);
      // strict mode: nullable via type unions, optional omission not allowed
      final promptSub = (items['properties']['prompt_sub'] as Map)['type'];
      expect(promptSub, contains('null'));
    });

    test('grader schema requires index+verdict, reason nullable', () {
      final schema = ExerciseSchema.grader();
      final verdicts = schema['properties']['verdicts'] as Map;
      final items = verdicts['items'] as Map;
      expect((items['required'] as List), containsAll(['index', 'verdict']));
      final verdictEnum =
          (items['properties']['verdict'] as Map)['enum'] as List;
      expect(verdictEnum, ['ok', 'flag']);
      final reasonType = (items['properties']['reason'] as Map)['type'] as List;
      expect(reasonType, contains('null'));
    });
  });

  group('AiLessonGenerator.parseGraderVerdicts', () {
    test('parses 1-based indices into 0-based flagged/ok verdicts', () {
      final verdicts = AiLessonGenerator.parseGraderVerdicts(
        '{"verdicts": ['
        '{"index": 1, "verdict": "ok"},'
        '{"index": 2, "verdict": "flag", "reason": "two correct choices"},'
        '{"index": 3, "verdict": "flagged"}'
        ']}',
      );
      expect(verdicts, hasLength(3));
      expect(verdicts[0].index, 0);
      expect(verdicts[0].flagged, isFalse);
      expect(verdicts[1].index, 1);
      expect(verdicts[1].flagged, isTrue);
      expect(verdicts[1].reason, 'two correct choices');
      expect(verdicts[2].flagged, isTrue);
    });

    test('unwraps code fences and bare arrays', () {
      final fenced = AiLessonGenerator.parseGraderVerdicts(
        '```json\n[{"index": 1, "verdict": "ok"}]\n```',
      );
      expect(fenced, hasLength(1));
      expect(fenced[0].flagged, isFalse);

      final bare = AiLessonGenerator.parseGraderVerdicts(
        '[{"index": 2, "verdict": "flag"}]',
      );
      expect(bare, hasLength(1));
      expect(bare[0].index, 1);
      expect(bare[0].flagged, isTrue);
    });

    test('garbage input yields empty list, never throws', () {
      expect(AiLessonGenerator.parseGraderVerdicts('not json'), isEmpty);
      expect(AiLessonGenerator.parseGraderVerdicts('{"other": 1}'), isEmpty);
      expect(AiLessonGenerator.parseGraderVerdicts(''), isEmpty);
    });

    test('string indices and missing reason tolerated', () {
      final verdicts = AiLessonGenerator.parseGraderVerdicts(
        '{"verdicts": [{"index": "1", "verdict": "FLAG"}]}',
      );
      expect(verdicts, hasLength(1));
      expect(verdicts[0].index, 0);
      expect(verdicts[0].flagged, isTrue);
      expect(verdicts[0].reason, isNull);
    });
  });

  group('ExerciseBankService.graderPrompt', () {
    test('numbers exercises 1-based with type, prompt, answer', () {
      final prompt = AiLessonGenerator.graderPrompt('Japanese', [
        (
          id: 1,
          exercise: AiExercise(
            type: 'cloze',
            prompt: 'The cat ___ on the mat',
            answer: 'sat',
          ),
        ),
        (
          id: 2,
          exercise: AiExercise(
            type: 'mc',
            prompt: 'Pick the word for dog',
            answer: '犬',
            choices: const ['犬', '猫', '鳥'],
          ),
        ),
      ]);
      expect(prompt, contains('grading Japanese'));
      expect(prompt, contains('1. type=cloze'));
      expect(prompt, contains('"The cat ___ on the mat"'));
      expect(prompt, contains('"sat"'));
      expect(prompt, contains('2. type=mc'));
      expect(prompt, contains('["犬","猫","鳥"]'));
    });
  });
}
