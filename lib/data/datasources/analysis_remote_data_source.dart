import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalysisRemoteDataSource {
  static const String _defaultApiUrl = 'http://localhost:5000';
  static const List<String> _allowedHosts = [
    'localhost',
    '127.0.0.1',
    '[::1]',
  ];

  final String _apiUrl;

  AnalysisRemoteDataSource({String? apiUrl}) : _apiUrl = _validateAndSanitizeUrl(apiUrl ?? _defaultApiUrl);

  static String _validateAndSanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Validate scheme
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw ArgumentError('Invalid scheme: ${uri.scheme}. Only http/https allowed.');
      }
      
      // Validate host against allowlist
      final host = uri.host;
      if (!_allowedHosts.contains(host)) {
        throw ArgumentError('Host not allowed: $host. Allowed: $_allowedHosts');
      }
      
      // Validate port (optional but recommended)
      if (uri.port != 80 && uri.port != 443 && uri.port != 5000) {
        // Warn but allow for development
        // In production, restrict to specific ports
      }
      
      // Reconstruct URL to prevent injection
      return uri.toString();
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid URL: $url');
    }
  }

  String get apiUrl => _apiUrl;

  Future<List<String>> tokenize(String text, String lang) async {
    if (lang == 'zh') {
      try {
        final response = await http.post(
          Uri.parse('$_apiUrl/tokenize_zh'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'text': text}),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return List<String>.from(data['tokens'] ?? []);
        }
      } catch (e) {
        // Fallback to character-based segmentation if API fails
      }
      return _simpleChineseTokenize(text);
    } else if (lang == 'ja') {
      try {
        final response = await http.post(
          Uri.parse('$_apiUrl/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'text': text}),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return List<String>.from(data['tokens'] ?? []);
        }
      } catch (e) {
        return text.split('');
      }
    } else if (lang == 'ko') {
      return text.split(RegExp(r'\s+'));
    }
    return text.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((s) => s.isNotEmpty).toList();
  }

  List<String> _simpleChineseTokenize(String text) {
    final List<String> tokens = [];
    int i = 0;
    while (i < text.length) {
      bool matched = false;
      for (int len = (4 < text.length - i ? 4 : text.length - i); len >= 2; len--) {
        final String word = text.substring(i, i + len);
        tokens.add(word);
        i += len;
        matched = true;
        break;
      }
      if (!matched) {
        tokens.add(text[i]);
        i++;
      }
    }
    return tokens;
  }

  Map<String, String> splitIntoSentences(List<String> tokens) {
    Map<String, String> ref = {};
    List<String> currentSentence = [];
    String currentSentenceStr = '';

    for (var token in tokens) {
      currentSentence.add(token);
      currentSentenceStr += " $token";

      if (token.contains('\n') ||
          token.endsWith('.') ||
          token.endsWith('。') ||
          token.endsWith('！') ||
          token.endsWith('!') ||
          token.endsWith('？') ||
          token.endsWith('?')) {
        for (var word in currentSentence) {
          if (!ref.containsKey(word)) {
            ref[word] = currentSentenceStr.trim();
          }
        }
        currentSentence = [];
        currentSentenceStr = '';
      }
    }

    if (currentSentence.isNotEmpty) {
      for (var word in currentSentence) {
        if (!ref.containsKey(word)) {
          ref[word] = currentSentenceStr.trim();
        }
      }
    }
    return ref;
  }
}