import '../entities/ai_message.dart';

abstract class AiRepository {
  Future<String> generateText(String prompt, String provider, {String? apiKey});
  Future<String> generateImage(String prompt, {String? negativePrompt, String? apiKey});
  
  // Specific Tasks
  Future<String> translate(String text, String targetLang, {String? apiKey});
  Future<String> summarize(String text, {String? apiKey});
  Future<List<Map<String, String>>> breakdown(String text, {String? apiKey});
  Future<String> extractTextFromImage(String imageBase64, {String? prompt, String? apiKey});

  // Custom Prompts
  Future<List<Map<String, String>>> getCustomPrompts();
  Future<void> saveCustomPrompt(String name, String prompt);
  Future<void> deleteCustomPrompt(String name);

  // Settings & History
  Future<void> saveMessage(AiMessage message);
  Future<List<AiMessage>> getHistory();
}
