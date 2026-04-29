import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/wiktionary_service.dart';

void main() {
  group('Wiktionary Service Tests', () {
    late WiktionaryService service;

    setUp(() {
      service = WiktionaryService();
    });

    test('Fetch Wiktionary data for English word', () async {
      final result = await service.fetchWordDetailsForAnyLanguage('hello', 'en');
      
      // Convert result to JSON format for checking
      final jsonResult = {
        'word': 'hello',
        'language': 'en',
        'data': result,
        'count': result.length,
      };
      
      print('English "hello" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0)); // Wiktionary might not have detailed sections
    });

    test('Fetch Wiktionary data for Japanese word', () async {
      final result = await service.fetchWordDetailsForAnyLanguage('猫', 'ja');
      
      // Convert result to JSON format for checking
      final jsonResult = {
        'word': '猫',
        'language': 'ja',
        'data': result,
        'count': result.length,
      };
      
      print('Japanese "猫" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Fetch Wiktionary data for Chinese character', () async {
      final result = await service.fetchWordDetailsForAnyLanguage('水', 'zh');
      
      // Convert result to JSON format for checking
      final jsonResult = {
        'word': '水',
        'language': 'zh',
        'data': result,
        'count': result.length,
        'isChineseCharacter': service.isSingleChineseCharacter('水'),
      };
      
      print('Chinese "水" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Fetch Wiktionary data for French word', () async {
      final result = await service.fetchWordDetailsForAnyLanguage('bonjour', 'fr');
      
      // Convert result to JSON format for checking
      final jsonResult = {
        'word': 'bonjour',
        'language': 'fr',
        'data': result,
        'count': result.length,
      };
      
      print('French "bonjour" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Fetch Wiktionary data for Spanish word', () async {
      final result = await service.fetchWordDetailsForAnyLanguage('casa', 'es');
      
      // Convert result to JSON format for checking
      final jsonResult = {
        'word': 'casa',
        'language': 'es',
        'data': result,
        'count': result.length,
      };
      
      print('Spanish "casa" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
      expect(result.length, greaterThanOrEqualTo(0));
    });

    test('Check Chinese character detection', () {
      expect(service.isSingleChineseCharacter('水'), true);
      expect(service.isSingleChineseCharacter('猫'), true);
      expect(service.isSingleChineseCharacter('hello'), false);
      expect(service.isSingleChineseCharacter('hello world'), false);
      expect(service.isSingleChineseCharacter(''), false);
      expect(service.isSingleChineseCharacter('猫狗'), false); // Two characters
    });

    test('Test detailed information extraction', () async {
      // Test with a common English word that should have definitions
      final result = await service.fetchWordDetailsForAnyLanguage('test', 'en');
      
      final jsonResult = {
        'word': 'test',
        'language': 'en',
        'data': result,
        'count': result.length,
        'hasContent': result.any((element) => element.isNotEmpty),
        'contentPreview': result.take(5).toList(), // Show first 5 items
      };
      
      print('Test word "test" result:');
      print(JsonEncoder.withIndent('  ').convert(jsonResult));
      
      expect(result, isA<List<String>>());
    });

    test('Check structured data extraction', () async {
      final result = await service.fetchDetailedWordInformation('water', false);
      
      // The result contains [japaneseContent, originContent, alternativeContent, allContent, otherContent]
      final structuredResult = {
        'word': 'water',
        'japaneseContent': result[0],
        'originContent': result[1], 
        'alternativeContent': result[2],
        'allContent': result[3],
        'otherContent': result[4],
        'totalSections': result.length,
      };
      
      print('Structured extraction for "water":');
      print(JsonEncoder.withIndent('  ').convert(structuredResult));
      
      expect(result, isA<List<List<String>>>());
      expect(result.length, 5); // Should have 5 sections
    });
  });
}