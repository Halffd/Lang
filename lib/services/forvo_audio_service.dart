import 'dart:convert';
import 'package:http/http.dart' as http;

class ForvoAudioService {
  static const String _baseUrl = 'https://apifree.forvo.com';
  static const String _apiKey = 'YOUR_FORVO_API_KEY'; // This would be set in a real implementation

  /// Search for pronunciation audio for a given word
  Future<List<ForvoPronunciation>> searchPronunciations(String word, {String language = 'ja'}) async {
    try {
      // Note: This is a simulated implementation since we can't include real API keys
      // In a real implementation, this would make actual API calls to Forvo
      final pronunciations = <ForvoPronunciation>[];
      
      // This is a simulation - in real implementation it would fetch from Forvo API
      // For demonstration purposes, we'll return mock data
      pronunciations.add(ForvoPronunciation(
        word: word,
        language: language,
        gender: 'female',
        country: 'JP',
        userName: 'sample_user',
        pronunciation: 'pronunciation_url', // in real implementation this would be the audio URL
        votes: 5,
        region: 'Tokyo',
      ));

      return pronunciations;
    } catch (e) {
      print('Error fetching Forvo pronunciations: $e');
      return [];
    }
  }

  /// Get audio URL for a specific pronunciation
  String getAudioUrl(String word, String language, String username) {
    // In a real implementation, this would construct the actual audio URL
    return 'https://forvo.example.com/audio/$word/$language/$username.mp3';
  }
}

class ForvoPronunciation {
  final String word;
  final String language;
  final String gender;
  final String country;
  final String userName;
  final String pronunciation;
  final int votes;
  final String? region;

  ForvoPronunciation({
    required this.word,
    required this.language,
    required this.gender,
    required this.country,
    required this.userName,
    required this.pronunciation,
    required this.votes,
    this.region,
  });

  factory ForvoPronunciation.fromMap(Map<String, dynamic> map) {
    return ForvoPronunciation(
      word: map['word'] ?? '',
      language: map['language'] ?? '',
      gender: map['gender'] ?? '',
      country: map['country'] ?? '',
      userName: map['user_name'] ?? map['username'] ?? '',
      pronunciation: map['pronunciation'] ?? '',
      votes: map['num_votes'] ?? map['votes'] ?? 0,
      region: map['region'],
    );
  }
}