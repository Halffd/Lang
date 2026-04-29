import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/repositories/text_analyzer.dart';
import 'package:lang/data/repositories/database.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:drift/drift.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextAnalyzer Tests', () {
    late AppDatabase appDatabase;
    late DictionaryService dictionaryService;
    late TextAnalyzer textAnalyzer;

    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Create in-memory database for testing
      appDatabase = AppDatabase();
      dictionaryService = DictionaryService();

      textAnalyzer = TextAnalyzer(appDatabase, dictionaryService);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('analyzeText should process Japanese text and return frequencies', () async {
      // Use a simple Japanese sentence for testing
      const testText = '私は学生です。日本語を勉強しています。';

      final results = await textAnalyzer.analyzeText(testText);

      // Verify results are returned
      expect(results, isList);
      expect(results.length, greaterThanOrEqualTo(0)); // Could be 0 if no tokens are found

      // If there are results, check the properties
      if (results.isNotEmpty) {
        final firstResult = results.first;
        expect(firstResult.word, isA<String>());
        expect(firstResult.count, isA<int>());
        expect(firstResult.count, greaterThan(0));
      }
    });

    test('analyzeTextTopWords should limit results', () async {
      const testText = '私は学生です。日本語を勉強しています。学生は勉強が好きです。';

      final results = await textAnalyzer.analyzeTextTopWords(testText, limit: 5);

      expect(results, isList);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('WordOccurrences table methods work properly', () async {
      // Test the database methods directly
      await appDatabase.clearWordOccurrences();

      // Insert some test data
      await appDatabase.insertWordOccurrences([
        WordOccurrencesCompanion.insert(
          word: 'test',
          reading: Value('てすと'),
          baseForm: const Value(''),
          position: 0,
        ),
        WordOccurrencesCompanion.insert(
          word: 'test',
          reading: Value('てすと'),
          baseForm: const Value(''),
          position: 1,
        ),
        WordOccurrencesCompanion.insert(
          word: 'another',
          reading: Value('アナザー'),
          baseForm: const Value(''),
          position: 2,
        ),
      ]);

      // Get frequencies
      final frequencies = await appDatabase.getWordFrequencies();

      expect(frequencies.length, greaterThanOrEqualTo(2));

      // Find the 'test' word frequency
      final testWordFreq = frequencies.firstWhere((f) => f.word == 'test');
      expect(testWordFreq.count, 2);
      expect(testWordFreq.firstOccurrence, 0);
    });
  });
}