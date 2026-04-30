import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/advanced_tokenizer_service.dart';

void main() {
  group('AdvancedTokenizerService Tests', () {
    late AdvancedTokenizerService service;

    setUp(() {
      service = AdvancedTokenizerService();
    });

    test('tokenizeJapaneseWithMeCab splits text by spaces', () async {
      final result = await service.tokenizeJapaneseWithMeCab('私 は 学生 です');
      expect(result, isA<List<String>>());
      expect(result.length, equals(4));
      expect(result, equals(['私', 'は', '学生', 'です']));
    });

    test('tokenizeJapaneseWithMeCab handles empty string', () async {
      final result = await service.tokenizeJapaneseWithMeCab('');
      expect(result, isA<List<String>>());
    });

    test('tokenizeJapaneseWithMeCab handles multiple spaces', () async {
      final result = await service.tokenizeJapaneseWithMeCab('私  は  学生');
      expect(result, isA<List<String>>());
    });

    test('tokenizeChineseWithJieba splits text by characters', () async {
      final result = await service.tokenizeChineseWithJieba('你好');
      expect(result, isA<List<String>>());
      expect(result.length, equals(2));
      expect(result, equals(['你', '好']));
    });

    test('tokenizeChineseWithJieba handles empty string', () async {
      final result = await service.tokenizeChineseWithJieba('');
      expect(result, isEmpty);
    });

    test('tokenizeChineseWithJieba handles multi-character Chinese words', () async {
      final result = await service.tokenizeChineseWithJieba('中国');
      expect(result, isA<List<String>>());
      expect(result.length, equals(2));
    });

    test('Japanese tokenization returns list of strings', () async {
      final result = await service.tokenizeJapaneseWithMeCab('日本語を勉強しています');
      expect(result, isA<List<String>>());
      for (final token in result) {
        expect(token, isA<String>());
      }
    });

    test('Chinese tokenization returns list of strings', () async {
      final result = await service.tokenizeChineseWithJieba('学习中文');
      expect(result, isA<List<String>>());
      for (final token in result) {
        expect(token, isA<String>());
      }
    });
  });
}