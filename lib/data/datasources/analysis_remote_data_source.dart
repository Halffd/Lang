import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalysisRemoteDataSource {
  final String apiUrl = 'http://localhost:5000';

  Future<List<String>> tokenize(String text, String lang) async {
    if (lang == 'zh') {
      try {
        final response = await http.post(
          Uri.parse('$apiUrl/tokenize_zh'),
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
          Uri.parse('$apiUrl/analyze'),
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