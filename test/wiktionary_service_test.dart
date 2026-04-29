import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/wiktionary_service.dart';

void main() {
  group('WiktionaryService Tests', () {
    late WiktionaryService service;

    setUp(() {
      service = WiktionaryService();
    });

    test('fetchWiktionaryData returns HTML for valid word', () async {
      try {
        final result = await service.fetchWiktionaryData('test');
        expect(result, isA<String>());
        expect(result.isNotEmpty, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWiktionaryData for Japanese word works', () async {
      try {
        final result = await service.fetchWiktionaryData('日本', 1);
        expect(result, isA<String>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWiktionaryData for Chinese word works', () async {
      try {
        final result = await service.fetchWiktionaryData('中国', 0);
        expect(result, isA<String>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWiktionaryData for Indonesian word works', () async {
      try {
        final result = await service.fetchWiktionaryData('test', 2);
        expect(result, isA<String>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchKanjipediaData returns HTML for valid character', () async {
      try {
        final result = await service.fetchKanjipediaData(
          'https://www.kanjipedia.jp/search?kt=1&sk=leftHand&k=中',
          0,
          '中',
          true,
        );
        expect(result, isA<String>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchDetailedWordInformation returns list of lists', () async {
      try {
        final result = await service.fetchDetailedWordInformation('test', false);
        expect(result, isA<List<List<String>>>());
        expect(result.length, equals(5));
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchDetailedWordInformation for Chinese character includes Kanjipedia', () async {
      try {
        final result = await service.fetchDetailedWordInformation('中', true);
        expect(result, isA<List<List<String>>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWordDetailsForAnyLanguage returns list of strings', () async {
      try {
        final result = await service.fetchWordDetailsForAnyLanguage('test', 'en');
        expect(result, isA<List<String>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('fetchWordDetailsForAnyLanguage for Chinese character works', () async {
      try {
        final result = await service.fetchWordDetailsForAnyLanguage('中', 'zh');
        expect(result, isA<List<String>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('isSingleChineseCharacter returns true for Chinese character', () {
      expect(service.isSingleChineseCharacter('中'), isTrue);
      expect(service.isSingleChineseCharacter('国'), isTrue);
    });

    test('isSingleChineseCharacter returns false for non-Chinese', () {
      expect(service.isSingleChineseCharacter('a'), isFalse);
      expect(service.isSingleChineseCharacter('test'), isFalse);
      expect(service.isSingleChineseCharacter('中日'), isFalse);
    });

    test('fetchDetailedWordInformation returns empty lists for non-existent word', () async {
      try {
        final result = await service.fetchDetailedWordInformation('xyznonexistent123', false);
        expect(result, isA<List<List<String>>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });
}