import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/dictionary.dart' as model;
import 'package:lang/domain/entities/etymology_model.dart';
import 'package:lang/domain/entities/tone_model.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/data/datasources/remote/wiktionary_etymology_service.dart';
import 'package:lang/utils/search_result_merger.dart';

void main() {
  group('SearchResultMerger', () {
    test('should return new result when existing is null', () {
      // Arrange
      final newResult = SearchResult(
        entries: [MockDictionaryEntry('term1')],
        kanji: [],
        pitchAccents: {'key1': []},
        toneInfo: {'key1': []},
        frequencies: {'key1': []},
        dictionaries: {1: MockDictionary()},
        tags: {'tag1': MockDictionaryTag()},
        etymology: {'key1': []},
        wiktionaryDetails: {'key1': []},
      );

      // Act
      final result = SearchResultMerger.merge(null, newResult);

      // Assert
      expect(result.entries.length, 1);
      expect(result.entries[0].term, 'term1');
    });

    test('should merge results and remove duplicates', () {
      // Arrange
      final existingResult = SearchResult(
        entries: [
          MockDictionaryEntry('term1'),
          MockDictionaryEntry('term2'),
        ],
        kanji: [],
        pitchAccents: {'key1': []},
        toneInfo: {'key1': []},
        frequencies: {'key1': []},
        dictionaries: {1: MockDictionary()},
        tags: {'tag1': MockDictionaryTag()},
        etymology: {'key1': []},
        wiktionaryDetails: {'key1': []},
      );

      final newResult = SearchResult(
        entries: [
          MockDictionaryEntry('term2'), // duplicate
          MockDictionaryEntry('term3'),
        ],
        kanji: [],
        pitchAccents: {'key2': []},
        toneInfo: {'key2': []},
        frequencies: {'key2': []},
        dictionaries: {2: MockDictionary()},
        tags: {'tag2': MockDictionaryTag()},
        etymology: {'key2': []},
        wiktionaryDetails: {'key2': []},
      );

      // Act
      final result = SearchResultMerger.merge(existingResult, newResult);

      // Assert
      expect(result.entries.length, 3); // term1, term2, term3 (no duplicates)
      expect(result.entries.map((e) => e.term), containsAll(['term1', 'term2', 'term3']));
      expect(result.pitchAccents.length, 2); // key1 and key2
      expect(result.dictionaries.length, 2); // dictionary ID 1 and 2
    });

    test('should merge all map properties correctly', () {
      // Arrange
      final existingResult = SearchResult(
        entries: [MockDictionaryEntry('term1')],
        kanji: [MockKanjiEntry('一')],
        pitchAccents: {'term1_reading1': [MockPitchAccent()]},
        toneInfo: {'term1_reading1': [MockToneInfo()]},
        frequencies: {'term1_reading1': [MockFrequencyData()]},
        dictionaries: {1: MockDictionary()},
        tags: {'1_tag1': MockDictionaryTag()},
        etymology: {'term1_reading1': [MockEtymologyEntry()]},
        wiktionaryDetails: {'term1_reading1': [MockWiktionaryEntry()]},
      );

      final newResult = SearchResult(
        entries: [MockDictionaryEntry('term2')],
        kanji: [MockKanjiEntry('二')],
        pitchAccents: {'term2_reading2': [MockPitchAccent()]},
        toneInfo: {'term2_reading2': [MockToneInfo()]},
        frequencies: {'term2_reading2': [MockFrequencyData()]},
        dictionaries: {2: MockDictionary()},
        tags: {'2_tag2': MockDictionaryTag()},
        etymology: {'term2_reading2': [MockEtymologyEntry()]},
        wiktionaryDetails: {'term2_reading2': [MockWiktionaryEntry()]},
      );

      // Act
      final result = SearchResultMerger.merge(existingResult, newResult);

      // Assert
      expect(result.entries.length, 2);
      expect(result.kanji.length, 2);
      expect(result.pitchAccents.length, 2);
      expect(result.toneInfo.length, 2);
      expect(result.frequencies.length, 2);
      expect(result.dictionaries.length, 2);
      expect(result.tags.length, 2);
      expect(result.etymology.length, 2);
      expect(result.wiktionaryDetails.length, 2);
    });
  });
}

class MockDictionaryEntry extends model.DictionaryEntry {
  MockDictionaryEntry(String term)
      : super(
          dictionaryId: 1,
          term: term,
          reading: 'reading_$term',
          definitions: ['definition for $term'],
        );
}

class MockDictionary extends model.Dictionary {
  MockDictionary()
      : super(
          name: 'test_dict',
          title: 'Test Dictionary',
          importedAt: DateTime.now(),
        );
}

class MockDictionaryTag extends model.DictionaryTag {
  MockDictionaryTag()
      : super(
          dictionaryId: 1,
          name: 'test_tag',
          category: 'test_category',
        );
}

class MockKanjiEntry extends model.KanjiEntry {
  MockKanjiEntry(String character)
      : super(
          dictionaryId: 1,
          character: character,
          meanings: ['meaning for $character'],
        );
}

class MockPitchAccent extends model.PitchAccent {
  MockPitchAccent()
      : super(
          dictionaryId: 1,
          term: 'test',
          reading: 'test',
          pitches: [MockPitchPattern()],
        );
}

class MockPitchPattern extends model.PitchPattern {
  MockPitchPattern()
      : super(position: 0);
}

class MockToneInfo extends ToneInfo {
  MockToneInfo()
      : super(
          dictionaryId: 1,
          term: 'test',
          reading: 'test',
          language: 'test',
          tones: [MockTonePattern()],
        );
}

class MockTonePattern extends TonePattern {
  MockTonePattern()
      : super(position: 0, toneNumber: 1);
}

class MockFrequencyData extends model.FrequencyData {
  MockFrequencyData()
      : super(
          dictionaryId: 1,
          term: 'test',
          reading: 'test',
          frequencyType: 'test',
          value: 1.0,
        );
}

class MockEtymologyEntry extends EtymologyEntry {
  MockEtymologyEntry()
      : super(
          sectionTitle: 'test',
          originalLanguage: 'test',
          content: 'test',
        );
}

class MockWiktionaryEntry extends WiktionaryEntry {
  MockWiktionaryEntry()
      : super(
          word: 'test',
          language: 'test',
          definition: 'test',
          partOfSpeech: 'noun',
          etymology: 'test',
          examples: [],
          translations: [],
          synonyms: [],
          antonyms: [],
        );
}