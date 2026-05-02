import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  static const String _historyKey = 'ai_history';
  static const String _customPromptsKey = 'custom_prompts';

  final String? defaultGeminiKey;
  final String? defaultHfKey;

  AiRepositoryImpl({this.defaultGeminiKey, this.defaultHfKey});

  @override
  Future<List<Map<String, String>>> getCustomPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_customPromptsKey);
    if (data == null) return [];
    
    final List decoded = jsonDecode(data);
    return decoded.map((item) => {
      'name': item['name']?.toString() ?? '',
      'prompt': item['prompt']?.toString() ?? '',
    }).toList();
  }

  @override
  Future<void> saveCustomPrompt(String name, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final prompts = await getCustomPrompts();
    
    // Remove existing with same name if any
    prompts.removeWhere((p) => p['name'] == name);
    prompts.add({'name': name, 'prompt': prompt});
    
    await prefs.setString(_customPromptsKey, jsonEncode(prompts));
  }

  @override
  Future<void> deleteCustomPrompt(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final prompts = await getCustomPrompts();
    prompts.removeWhere((p) => p['name'] == name);
    await prefs.setString(_customPromptsKey, jsonEncode(prompts));
  }

  @override
  Future<String> generateText(String prompt, String provider, {String? apiKey}) async {
    final key = apiKey ?? defaultGeminiKey;
    if (key == null || key.isEmpty) {
      throw Exception('Gemini API key not configured. Set it in Settings > AI.');
    }
    if (provider == 'Gemini') {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response';
      } else {
        throw Exception('Failed to generate text: ${response.body}');
      }
    }
    return 'Unsupported provider';
  }

  @override
  Future<String> generateImage(String prompt, {String? negativePrompt, String? apiKey}) async {
    final key = apiKey ?? defaultHfKey;
    if (key == null || key.isEmpty) {
      throw Exception('HuggingFace API key not configured. Set it in Settings > AI.');
    }
    final url = Uri.parse('https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0');
    final fullPrompt = negativePrompt != null ? "$prompt [Negative: $negativePrompt]" : prompt;
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'inputs': fullPrompt}),
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      return base64Encode(bytes);
    } else {
      throw Exception('Failed to generate image: ${response.body}');
    }
  }

  @override
  Future<String> translate(String text, String targetLang, {String? apiKey}) async {
    final prompt = "Translate the following text to $targetLang. Output ONLY the translation: $text";
    return generateText(prompt, 'Gemini', apiKey: apiKey);
  }

  @override
  Future<String> summarize(String text, {String? apiKey}) async {
    final prompt = "Summarize the following text in a concise manner: $text";
    return generateText(prompt, 'Gemini', apiKey: apiKey);
  }

  @override
  Future<List<Map<String, String>>> breakdown(String text, {String? apiKey}) async {
    final prompt = """
Break down each word in the following text. 
Output ONLY a JSON array of objects with keys 'term' and 'meaning'.
Example: [{"term": "こんにちは", "meaning": "hello"}]
Text: $text
""";
    final response = await generateText(prompt, 'Gemini', apiKey: apiKey);
    
    try {
      // Basic extraction of JSON array from text response
      final start = response.indexOf('[');
      final end = response.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      
      final jsonStr = response.substring(start, end + 1);
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((item) => {
        'term': item['term']?.toString() ?? '',
        'meaning': item['meaning']?.toString() ?? '',
      }).toList();
    } catch (e) {
      debugPrint('Breakdown parse error: $e');
      return [];
    }
  }

  @override
  Future<void> saveMessage(AiMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    
    // We'll store a simple JSON list for now
    final historyJson = history.map((m) => {
      'text': m.text,
      'sender': m.sender.name,
      'imageUrl': m.imageUrl,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();

    historyJson.add({
      'text': message.text,
      'sender': message.sender.name,
      'imageUrl': message.imageUrl,
      'timestamp': message.timestamp.toIso8601String(),
    });

    await prefs.setString(_historyKey, jsonEncode(historyJson));
  }

  @override
  Future<List<AiMessage>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data == null) return [];

    final List decoded = jsonDecode(data);
    return decoded.map((m) => AiMessage(
      text: m['text'],
      sender: m['sender'] == 'user' ? AiSender.user : AiSender.ai,
      imageUrl: m['imageUrl'],
      timestamp: DateTime.parse(m['timestamp']),
    )).toList();
  }
}
