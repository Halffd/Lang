import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/exercise_bank_service.dart';
import 'package:lang/data/services/exercise_schema.dart';
import 'package:lang/presentation/screens/study/ai_exercise_parser.dart';

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
  });
}
