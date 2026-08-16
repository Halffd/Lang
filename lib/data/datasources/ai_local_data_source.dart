import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/domain/entities/ai_message.dart';

class AiLocalDataSource {
  static const String _historyKey = 'ai_history';
  static const String _customPromptsKey = 'custom_prompts';

  Future<List<AiMessage>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data == null) return [];

    final List decoded = jsonDecode(data);
    return decoded
        .map((m) => AiMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMessage(AiMessage message) async {
    final history = await getHistory();
    history.add(message);
    await _saveHistory(history);
  }

  Future<void> saveAllMessages(List<AiMessage> messages) async {
    await _saveHistory(messages);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

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

  Future<void> saveCustomPrompt(String name, String prompt) async {
    final prompts = await getCustomPrompts();
    prompts.removeWhere((p) => p['name'] == name);
    prompts.add({'name': name, 'prompt': prompt});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPromptsKey, jsonEncode(prompts));
  }

  Future<void> deleteCustomPrompt(String name) async {
    final prompts = await getCustomPrompts();
    prompts.removeWhere((p) => p['name'] == name);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPromptsKey, jsonEncode(prompts));
  }

  Future<void> _saveHistory(List<AiMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => m.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }
}
