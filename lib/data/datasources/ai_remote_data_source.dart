import 'dart:convert';
import 'package:http/http.dart' as http;

class AiRemoteDataSource {
  final http.Client _client;

  AiRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  Future<String> generateText(String prompt, String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw AiRemoteException(
        'Gemini API failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw AiRemoteException('No candidates in Gemini response');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw AiRemoteException('No content in Gemini candidate');
    }
    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw AiRemoteException('No parts in Gemini content');
    }
    return parts[0]['text']?.toString() ?? 'No response';
  }

  Future<String> generateImage(String prompt, String apiKey, {String? negativePrompt}) async {
    final url = Uri.parse(
      'https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0',
    );
    final fullPrompt = negativePrompt != null ? '$prompt [Negative: $negativePrompt]' : prompt;

    final response = await _client.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'inputs': fullPrompt}),
    );

    if (response.statusCode != 200) {
      throw AiRemoteException(
        'HuggingFace API failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return base64Encode(response.bodyBytes);
  }

  Future<String> extractTextFromImage(String imageBase64, String prompt, String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt.isNotEmpty ? prompt : 'Extract all text from this image. Preserve line breaks.'},
            {'inlineData': {'mimeType': 'image/jpeg', 'data': imageBase64}},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 8192,
      }
    };

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw AiRemoteException(
        'Vision API failed (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw AiRemoteException('No candidates in Vision response');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw AiRemoteException('No content in Vision candidate');
    }
    final parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw AiRemoteException('No parts in Vision content');
    }
    return parts[0]['text']?.toString() ?? 'No response';
  }
}

class AiRemoteException implements Exception {
  final String message;
  final int? statusCode;

  AiRemoteException(this.message, {this.statusCode});

  @override
  String toString() => 'AiRemoteException: $message';
}
