import 'dart:convert';
import '../../domain/entities/ai_message.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_local_data_source.dart';
import '../datasources/ai_remote_data_source.dart';

class AiRepositoryImpl implements AiRepository {
  final AiRemoteDataSource _remoteDataSource;
  final AiLocalDataSource _localDataSource;

  static const String _defaultGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _defaultHfKey =
      String.fromEnvironment('HF_API_KEY', defaultValue: '');

  AiRepositoryImpl({
    required AiRemoteDataSource remoteDataSource,
    required AiLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  String _resolveGeminiKey(String? apiKey) =>
      apiKey?.isNotEmpty == true ? apiKey! : _defaultGeminiKey;

  String _resolveHfKey(String? apiKey) =>
      apiKey?.isNotEmpty == true ? apiKey! : _defaultHfKey;

  @override
  Future<String> generateText(String prompt, String provider, {String? apiKey}) async {
    if (provider == 'Gemini') {
      final key = _resolveGeminiKey(apiKey);
      if (key.isEmpty) {
        throw AiRepositoryException('Gemini API key not configured');
      }
      return _remoteDataSource.generateText(prompt, key);
    }
    throw AiRepositoryException('Unsupported provider: $provider');
  }

  @override
  Future<String> generateImage(String prompt, {String? negativePrompt, String? apiKey}) async {
    final key = _resolveHfKey(apiKey);
    if (key.isEmpty) {
      throw AiRepositoryException('HuggingFace API key not configured');
    }
    return _remoteDataSource.generateImage(prompt, key, negativePrompt: negativePrompt);
  }

  @override
  Future<String> translate(String text, String targetLang, {String? apiKey}) async {
    final prompt = 'Translate the following text to $targetLang. Output ONLY the translation: $text';
    return generateText(prompt, 'Gemini', apiKey: apiKey);
  }

  @override
  Future<String> summarize(String text, {String? apiKey}) async {
    final prompt = 'Summarize the following text in a concise manner: $text';
    return generateText(prompt, 'Gemini', apiKey: apiKey);
  }

  @override
  Future<List<Map<String, String>>> breakdown(String text, {String? apiKey}) async {
    final prompt = '''
Break down each word in the following text.
Output ONLY a JSON array of objects with keys 'term' and 'meaning'.
Example: [{"term": "こんにちは", "meaning": "hello"}]
Text: $text
''';
    final response = await generateText(prompt, 'Gemini', apiKey: apiKey);

    try {
      final extracted = _extractJsonArray(response);
      if (extracted == null) return [];
      final List decoded = extracted;
      return decoded.map((item) => {
        'term': item['term']?.toString() ?? '',
        'meaning': item['meaning']?.toString() ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<dynamic>? _extractJsonArray(String text) {
    int depth = 0;
    int? start;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == '[') {
        if (depth == 0) start = i;
        depth++;
      } else if (text[i] == ']') {
        depth--;
        if (depth == 0 && start != null) {
          try {
            return jsonDecode(text.substring(start, i + 1)) as List<dynamic>;
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, String>>> getCustomPrompts() =>
      _localDataSource.getCustomPrompts();

  @override
  Future<void> saveCustomPrompt(String name, String prompt) =>
      _localDataSource.saveCustomPrompt(name, prompt);

  @override
  Future<void> deleteCustomPrompt(String name) =>
      _localDataSource.deleteCustomPrompt(name);

  @override
  Future<void> saveMessage(AiMessage message) =>
      _localDataSource.saveMessage(message);

  @override
  Future<List<AiMessage>> getHistory() =>
      _localDataSource.getHistory();
}

class AiRepositoryException implements Exception {
  final String message;
  AiRepositoryException(this.message);

  @override
  String toString() => 'AiRepositoryException: $message';
}
