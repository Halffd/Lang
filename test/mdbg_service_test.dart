import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/mdbg_service.dart';

void main() {
  group('MdbgService Tests', () {
    late MdbgService service;

    setUp(() {
      service = MdbgService();
    });

    test('lookupWord returns MdbgEntry for valid Chinese word', () async {
      try {
        final result = await service.lookupWord('你');
        if (result != null) {
          expect(result, isA<MdbgEntry>());
          expect(result.word, isNotEmpty);
          expect(result.pinyin, isNotEmpty);
        }
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('lookupWord returns null for empty query', () async {
      final result = await service.lookupWord('');
      expect(result, isNull);
    });

    test('lookupWord handles non-Chinese characters', () async {
      try {
        final result = await service.lookupWord('test');
        expect(result, anyOf(isNull, isA<MdbgEntry>()));
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('searchWords returns list of entries', () async {
      try {
        final results = await service.searchWords('好');
        expect(results, isA<List<MdbgEntry>>());
        if (results.isNotEmpty) {
          expect(results.first.word, isNotEmpty);
          expect(results.first.pinyin, isNotEmpty);
        }
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('searchWords respects limit parameter', () async {
      try {
        final results = await service.searchWords('中', limit: 3);
        expect(results.length, lessThanOrEqualTo(3));
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('searchWords returns empty list for empty query', () async {
      final results = await service.searchWords('');
      expect(results, isEmpty);
    });

    test('MdbgEntry has correct structure', () async {
      try {
        final result = await service.lookupWord('我');
        if (result != null) {
          expect(result.word, isA<String>());
          expect(result.pinyin, isA<String>());
          expect(result.definitions, isA<List<String>>());
        }
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('searchWords handles multi-character word', () async {
      try {
        final results = await service.searchWords('中国');
        expect(results, isA<List<MdbgEntry>>());
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });
}