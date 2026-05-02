import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ForvoAudioService {
  static const String _baseUrl = 'https://apifree.forvo.com';
  static const String _forvoApiKeyPref = 'forvo_api_key';

  String? _apiKey;

  String? get apiKey => _apiKey;

  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_forvoApiKeyPref);
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_forvoApiKeyPref, key);
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_forvoApiKeyPref);
  }

  /// Search for pronunciation audio for a given word
  Future<List<ForvoPronunciation>> searchPronunciations(String word, {String language = 'ja'}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return [];
    }
    try {
      final url = Uri.parse('$_baseUrl/key/$_apiKey/format/json/action/word-pronunciations/word/$word/language/$language');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => ForvoPronunciation.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get audio URL for a specific pronunciation
  String getAudioUrl(String word, String language, String username) {
    return '$_baseUrl/key/$_apiKey/format/json/action/word-pronunciations/word/$word/language/$language/user/$username';
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