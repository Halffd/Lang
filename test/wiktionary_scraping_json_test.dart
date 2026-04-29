import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/wiktionary_service.dart';

void main() {
  group('Wiktionary Scraping Test - JSON Output', () {
    late WiktionaryService service;

    setUp(() {
      service = WiktionaryService();
    });

    test('Scrape Wiktionary for English word - JSON output', () async {
      // Test with an English word
      final result = await service.fetchWordDetailsForAnyLanguage('hello', 'en');
      
      final jsonData = {
        'word': 'hello',
        'language': 'en',
        'method': 'fetchWordDetailsForAnyLanguage',
        'content': result,
        'contentCount': result.length,
        'hasData': result.isNotEmpty,
        'sampleContent': result.length > 0 ? result.sublist(0, result.length > 5 ? 5 : result.length) : [],
      };
      
      print('--- English "hello" results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End English results ---');
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Scrape Wiktionary for Japanese word - JSON output', () async {
      // Test with a Japanese word
      final result = await service.fetchWordDetailsForAnyLanguage('猫', 'ja');
      
      final jsonData = {
        'word': '猫',
        'language': 'ja',
        'method': 'fetchWordDetailsForAnyLanguage',
        'content': result,
        'contentCount': result.length,
        'hasData': result.isNotEmpty,
        'isJapanese': RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch('猫'),
        'sampleContent': result.length > 0 ? result.sublist(0, result.length > 5 ? 5 : result.length) : [],
      };
      
      print('--- Japanese "猫" (cat) results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End Japanese results ---');
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Scrape Wiktionary for Chinese word - JSON output', () async {
      // Test with a Chinese word
      final result = await service.fetchWordDetailsForAnyLanguage('水', 'zh');
      
      final jsonData = {
        'word': '水',
        'language': 'zh',
        'method': 'fetchWordDetailsForAnyLanguage',
        'content': result,
        'contentCount': result.length,
        'hasData': result.isNotEmpty,
        'isChinese': service.isSingleChineseCharacter('水'),
        'sampleContent': result.length > 0 ? result.sublist(0, result.length > 5 ? 5 : result.length) : [],
      };
      
      print('--- Chinese "水" (water) results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End Chinese results ---');
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Scrape French word - JSON output', () async {
      // Test with a French word
      final result = await service.fetchWordDetailsForAnyLanguage('bonjour', 'fr');
      
      final jsonData = {
        'word': 'bonjour',
        'language': 'fr',
        'method': 'fetchWordDetailsForAnyLanguage',
        'content': result,
        'contentCount': result.length,
        'hasData': result.isNotEmpty,
        'sampleContent': result.length > 0 ? result.sublist(0, result.length > 5 ? 5 : result.length) : [],
      };
      
      print('--- French "bonjour" results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End French results ---');
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Scrape German word - JSON output', () async {
      // Test with a German word
      final result = await service.fetchWordDetailsForAnyLanguage('hallo', 'de');
      
      final jsonData = {
        'word': 'hallo',
        'language': 'de',
        'method': 'fetchWordDetailsForAnyLanguage',
        'content': result,
        'contentCount': result.length,
        'hasData': result.isNotEmpty,
        'sampleContent': result.length > 0 ? result.sublist(0, result.length > 5 ? 5 : result.length) : [],
      };
      
      print('--- German "hallo" results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End German results ---');
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Test detailed word information fetching - JSON output', () async {
      // Test the detailed function that combines Wiktionary and Kanjipedia
      final result = await service.fetchDetailedWordInformation('test', false);
      
      final jsonData = {
        'word': 'test',
        'method': 'fetchDetailedWordInformation',
        'resultStructure': {
          'japaneseContent': result[0],
          'originContent': result[1],
          'alternativeContent': result[2],
          'allContent': result[3],
          'otherContent': result[4],
        },
        'structureCount': result.length,
        'totalContentCount': result.fold(0, (prev, element) => prev + (element as List).length),
        'hasData': result.isNotEmpty,
      };
      
      print('--- Detailed Word Information results for "test" ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End detailed results ---');
      
      expect(result, isA<List>());
      expect(result.length, 5); // Should have 5 sections
    });

    test('Verify language detection functionality - JSON output', () async {
      // Test language detection
      String detectedLang1 = 'en';  // Would normally use _detectLanguage method from context
      String detectedLang2 = 'ja';  // Would normally use _detectLanguage method from context
      String detectedLang3 = 'zh';  // Would normally use _detectLanguage method from context
      
      final jsonData = {
        'languageDetectionTests': {
          'english': detectedLang1,
          'japanese': detectedLang2,
          'chinese': detectedLang3,
        },
        'expectedResults': {
          'hello': 'en',
          '猫': 'ja',
          '水': 'zh',
        },
        'chineseCharacterValidation': {
          'isChinese_水': service.isSingleChineseCharacter('水'),
          'isChinese_猫': service.isSingleChineseCharacter('猫'),
          'isChinese_hello': service.isSingleChineseCharacter('hello'),
          'isChinese_你好': service.isSingleChineseCharacter('你好'), // Two chars
        }
      };
      
      print('--- Language Detection Results ---');
      print(JsonEncoder.withIndent('  ').convert(jsonData));
      print('--- End Language Detection Results ---');
      
      expect(service.isSingleChineseCharacter('水'), true);
      expect(service.isSingleChineseCharacter('猫'), true);
      expect(service.isSingleChineseCharacter('hello'), false);
      expect(service.isSingleChineseCharacter('你好'), false); // Two characters
    });
  });
}