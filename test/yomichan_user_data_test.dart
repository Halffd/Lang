// YomichanService user-data methods: real implementations
// delegating to NoteLocalDataSource (saved words, history) and
// AudioService (tts). Verifies save/remove/history/words flows
// through SharedPreferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/data/services/dictionary/yomichan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late YomichanService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = YomichanService();
  });

  group('YomichanService user data', () {
    test('saveWord stores word + sentence', () async {
      await service.saveWord('読む', sentence: '本を読む');
      final words = await service.getSavedWords();
      expect(words, isNotEmpty);
      expect(words.first['word'], '読む');
      expect(words.first['sentence'], '本を読む');
    });

    test('removeSavedWord deletes it', () async {
      await service.saveWord('読む');
      await service.removeSavedWord('読む');
      final words = await service.getSavedWords();
      expect(words, isEmpty);
    });

    test('addToHistory moves word to front, caps at 100', () async {
      await service.addToHistory('one');
      await service.addToHistory('two');
      final history = await service.getHistory();
      expect(history, ['two', 'one']);

      // re-adding moves to top
      await service.addToHistory('one');
      final moved = await service.getHistory();
      expect(moved, ['one', 'two']);

      // cap at 100 entries
      for (var i = 0; i < 120; i++) {
        await service.addToHistory('w$i');
      }
      final capped = await service.getHistory();
      expect(capped.length, 100);
      expect(capped.first, 'w119');
    });

    test('getSavedWords sorted newest first', () async {
      await service.saveWord('first');
      // distinct timestamp needed; force by manipulating delay
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service.saveWord('second');
      final words = await service.getSavedWords();
      expect(words.length, 2);
      expect(words.first['word'], 'second');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
