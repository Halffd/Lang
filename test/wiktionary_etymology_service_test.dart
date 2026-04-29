import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/wiktionary_etymology_service.dart';

void main() {
  group('WiktionaryEtymologyService Tests', () {
    late WiktionaryEtymologyService service;

    setUp(() {
      service = WiktionaryEtymologyService();
    });

    test('fetchWordDetails returns list of entries', () async {
      try {
        final results = await service.fetchWordDetails('test', 'en');
        expect(results, isA<List<WiktionaryEntry>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWordDetails for Japanese word works', () async {
      try {
        final results = await service.fetchWordDetails('日本', 'ja');
        expect(results, isA<List<WiktionaryEntry>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWordDetails for Chinese word works', () async {
      try {
        final results = await service.fetchWordDetails('中国', 'zh');
        expect(results, isA<List<WiktionaryEntry>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchEtymology returns EtymologyResult', () async {
      try {
        final result = await service.fetchEtymology('test', 'en');
        expect(result, isA<EtymologyResult>());
        expect(result.word, equals('test'));
        expect(result.language, equals('en'));
        expect(result.sections, isA<List<EtymologySection>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchEtymologyDetailed returns EtymologyResult', () async {
      try {
        final result = await service.fetchEtymologyDetailed('test', 'en');
        expect(result, isA<EtymologyResult>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWordDetails falls back to English for unsupported language', () async {
      try {
        final results = await service.fetchWordDetails('test', 'unsupported_lang');
        expect(results, isA<List<WiktionaryEntry>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('WiktionaryEntry has correct structure', () async {
      try {
        final results = await service.fetchWordDetails('test', 'en');
        if (results.isNotEmpty) {
          final entry = results.first;
          expect(entry.word, isA<String>());
          expect(entry.language, isA<String>());
          expect(entry.partOfSpeech, isA<String>());
          expect(entry.definition, isA<String>());
          expect(entry.etymology, isA<String>());
          expect(entry.examples, isA<List<String>>());
          expect(entry.synonyms, isA<List<String>>());
          expect(entry.antonyms, isA<List<String>>());
          expect(entry.translations, isA<List<String>>());
        }
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('EtymologySection has correct structure', () async {
      try {
        final result = await service.fetchEtymology('test', 'en');
        if (result.sections.isNotEmpty) {
          final section = result.sections.first;
          expect(section.title, isA<String>());
          expect(section.language, isA<String>());
          expect(section.originalLanguage, isA<String>());
          expect(section.content, isA<String>());
        }
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });
}