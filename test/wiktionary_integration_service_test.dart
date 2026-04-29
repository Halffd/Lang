import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/dictionary.dart' as model;
import 'package:lang/domain/entities/etymology_model.dart';
import 'package:lang/domain/entities/tone_model.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/data/datasources/remote/wiktionary_etymology_service.dart';
import 'package:lang/data/datasources/remote/wiktionary_integration_service.dart';

void main() {
  group('WiktionaryIntegrationService', () {
    late DictionaryService mockDictionaryService;
    late WiktionaryIntegrationService wiktionaryService;

    setUp(() {
      mockDictionaryService = MockDictionaryService();
      wiktionaryService = WiktionaryIntegrationService(mockDictionaryService);
    });

    test('should enrich search result with Wiktionary details when details exist', () async {
      // Arrange
      final baseResult = SearchResult(
        entries: [MockDictionaryEntry()],
        kanji: [],
        pitchAccents: {},
        toneInfo: {},
        frequencies: {},
        dictionaries: {},
        tags: {},
      );
      final query = 'test';
      final detectedLanguage = 'en';

      // Act
      final result = await wiktionaryService.enrichSearchResult(baseResult, query, detectedLanguage);

      // Assert
      expect(result.wiktionaryDetails.length, 1);
      expect(result.wiktionaryDetails['${query}_'], isNotNull);
      expect(result.wiktionaryDetails['${query}_']!.length, 2);
      expect(result.wiktionaryDetails['${query}_']![0].word, query);
      expect(result.wiktionaryDetails['${query}_']![0].language, detectedLanguage);
      expect(result.wiktionaryDetails['${query}_']![0].definition, 'definition 1');
      expect(result.wiktionaryDetails['${query}_']![1].definition, 'definition 2');
    });

    test('should return base result unchanged when no Wiktionary details exist', () async {
      // Arrange
      final baseResult = SearchResult(
        entries: [MockDictionaryEntry()],
        kanji: [],
        pitchAccents: {},
        toneInfo: {},
        frequencies: {},
        dictionaries: {},
        tags: {},
      );
      final query = 'no-details';
      final detectedLanguage = 'en';

      // Act
      final result = await wiktionaryService.enrichSearchResult(baseResult, query, detectedLanguage);

      // Assert
      expect(result.wiktionaryDetails.length, 0);
      expect(result.entries, baseResult.entries);
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      final baseResult = SearchResult(
        entries: [MockDictionaryEntry()],
        kanji: [],
        pitchAccents: {},
        toneInfo: {},
        frequencies: {},
        dictionaries: {},
        tags: {},
      );
      final query = 'exception';
      final detectedLanguage = 'en';

      // Act
      final result = await wiktionaryService.enrichSearchResult(baseResult, query, detectedLanguage);

      // Assert
      expect(result, equals(baseResult)); // Should return base result when exception occurs
    });
  });
}

class MockDictionaryService extends DictionaryService {
  @override
  Future<List<String>> fetchWordDetailsMultiLanguage(String word, String language) async {
    if (word == 'test') {
      return ['definition 1', 'definition 2'];
    } else if (word == 'no-details') {
      return [];
    } else if (word == 'exception') {
      throw Exception('Test exception');
    }
    return [];
  }
}

class MockDictionaryEntry extends model.DictionaryEntry {
  MockDictionaryEntry()
      : super(
          dictionaryId: 1,
          term: 'mock_term',
          reading: 'mock_reading',
          definitions: ['mock_definition'],
        );
}