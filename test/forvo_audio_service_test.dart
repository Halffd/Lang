import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/forvo_audio_service.dart';

void main() {
  group('ForvoAudioService Tests', () {
    late ForvoAudioService service;

    setUp(() {
      service = ForvoAudioService();
    });

  test('searchPronunciations returns empty list without API key', () async {
    final results = await service.searchPronunciations('test');
    expect(results, isA<List<ForvoPronunciation>>());
    expect(results.isEmpty, isTrue);
  });

  test('searchPronunciations with language parameter works without key', () async {
    final results = await service.searchPronunciations('test', language: 'ja');
    expect(results, isA<List<ForvoPronunciation>>());
  });

  test('searchPronunciations for Japanese word returns empty without key', () async {
    final results = await service.searchPronunciations('日本', language: 'ja');
    expect(results, isA<List<ForvoPronunciation>>());
  });

    test('getAudioUrl returns valid URL format', () {
      final url = service.getAudioUrl('test', 'ja', 'user123');
      expect(url, isA<String>());
      expect(url.contains('test'), isTrue);
      expect(url.contains('ja'), isTrue);
      expect(url.contains('user123'), isTrue);
    });

    test('ForvoPronunciation fromMap creates valid object', () {
      final map = {
        'word': 'test',
        'language': 'ja',
        'gender': 'female',
        'country': 'JP',
        'user_name': 'testuser',
        'pronunciation': 'http://example.com/audio.mp3',
        'num_votes': 5,
        'region': 'Tokyo',
      };

      final pronunciation = ForvoPronunciation.fromMap(map);

      expect(pronunciation.word, equals('test'));
      expect(pronunciation.language, equals('ja'));
      expect(pronunciation.gender, equals('female'));
      expect(pronunciation.country, equals('JP'));
      expect(pronunciation.userName, equals('testuser'));
      expect(pronunciation.votes, equals(5));
      expect(pronunciation.region, equals('Tokyo'));
    });

    test('ForvoPronunciation fromMap handles missing fields', () {
      final map = <String, dynamic>{};

      final pronunciation = ForvoPronunciation.fromMap(map);

      expect(pronunciation.word, equals(''));
      expect(pronunciation.language, equals(''));
      expect(pronunciation.votes, equals(0));
    });

    test('ForvoPronunciation fromMap handles alternative username key', () {
      final map = {
        'word': 'test',
        'username': 'alt_user',
        'votes': 3,
      };

      final pronunciation = ForvoPronunciation.fromMap(map);

      expect(pronunciation.userName, equals('alt_user'));
    });
  });
}