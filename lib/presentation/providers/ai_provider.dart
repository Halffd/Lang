import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/repositories/ai_repository.dart';

class AiProvider with ChangeNotifier {
  final AiRepository _repository;

  List<AiMessage> _messages = [];
  List<AiMessage> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _selectedProvider = 'Gemini';
  String get selectedProvider => _selectedProvider;

  // AI Settings
  bool _isAiEnabled = true;
  bool get isAiEnabled => _isAiEnabled;
  
  String _geminiApiKey = '';
  String get geminiApiKey => _geminiApiKey;
  
  String _hfApiKey = '';
  String get hfApiKey => _hfApiKey;

  List<Map<String, String>> _customPrompts = [];
  List<Map<String, String>> get customPrompts => _customPrompts;

  // Specific results
  List<Map<String, String>> _lastBreakdown = [];
  List<Map<String, String>> get lastBreakdown => _lastBreakdown;

  AiProvider(this._repository);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAiEnabled = prefs.getBool('isAiEnabled') ?? true;
    _geminiApiKey = prefs.getString('geminiApiKey') ?? '';
    _hfApiKey = prefs.getString('hfApiKey') ?? '';
    _selectedProvider = prefs.getString('selectedAiProvider') ?? 'Gemini';

    _messages = await _repository.getHistory();
    await refreshCustomPrompts();
    notifyListeners();
  }

  Future<void> refreshCustomPrompts() async {
    _customPrompts = await _repository.getCustomPrompts();
    notifyListeners();
  }

  Future<void> addCustomPrompt(String name, String prompt) async {
    await _repository.saveCustomPrompt(name, prompt);
    await refreshCustomPrompts();
  }

  Future<void> deleteCustomPrompt(String name) async {
    await _repository.deleteCustomPrompt(name);
    await refreshCustomPrompts();
  }

  // Combined prompts for the UI
  List<Map<String, String>> get allPrompts => [
    ...promptTemplates,
    ..._customPrompts,
  ];


  Future<void> updateSettings({bool? isEnabled, String? geminiKey, String? hfKey, String? provider}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isEnabled != null) {
      _isAiEnabled = isEnabled;
      await prefs.setBool('isAiEnabled', isEnabled);
    }
    if (geminiKey != null) {
      _geminiApiKey = geminiKey;
      await prefs.setString('geminiApiKey', geminiKey);
    }
    if (hfKey != null) {
      _hfApiKey = hfKey;
      await prefs.setString('hfApiKey', hfKey);
    }
    if (provider != null) {
      _selectedProvider = provider;
      await prefs.setString('selectedAiProvider', provider);
    }
    notifyListeners();
  }

  void setProvider(String provider) {
    updateSettings(provider: provider);
  }

  String? get _activeGeminiKey => _geminiApiKey.isEmpty ? null : _geminiApiKey;
  String? get _activeHfKey => _hfApiKey.isEmpty ? null : _hfApiKey;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || !_isAiEnabled) return;

    final userMessage = AiMessage(text: text, sender: AiSender.user);
    _messages.add(userMessage);
    await _repository.saveMessage(userMessage);
    
    _isLoading = true;
    notifyListeners();

    try {
      final responseText = await _repository.generateText(
        text, 
        _selectedProvider, 
        apiKey: _activeGeminiKey
      );
      final aiMessage = AiMessage(text: responseText, sender: AiSender.ai);
      _messages.add(aiMessage);
      await _repository.saveMessage(aiMessage);
    } catch (e) {
      final errorMessage = AiMessage(text: 'Error: $e', sender: AiSender.ai);
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateImage(String prompt, {String? negativePrompt}) async {
    if (prompt.trim().isEmpty || !_isAiEnabled) return;

    final userMessage = AiMessage(text: 'Generate image: $prompt', sender: AiSender.user);
    _messages.add(userMessage);
    
    _isLoading = true;
    notifyListeners();

    try {
      final base64Image = await _repository.generateImage(
        prompt, 
        negativePrompt: negativePrompt,
        apiKey: _activeHfKey
      );
      final aiMessage = AiMessage(text: 'Image generated', sender: AiSender.ai, imageUrl: base64Image);
      _messages.add(aiMessage);
      await _repository.saveMessage(aiMessage);
    } catch (e) {
      final errorMessage = AiMessage(text: 'Image error: $e', sender: AiSender.ai);
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runBreakdown(String text) async {
    if (!_isAiEnabled) return;
    _isLoading = true;
    _lastBreakdown = [];
    notifyListeners();

    try {
      _lastBreakdown = await _repository.breakdown(text, apiKey: _activeGeminiKey);
      
      final displayText = text.length > 30 ? text.substring(0, 30) : text;
      final aiMessage = AiMessage(
        text: 'Breakdown for: $displayText...', 
        sender: AiSender.ai
      );
      _messages.add(aiMessage);
      await _repository.saveMessage(aiMessage);
    } catch (e) {
      debugPrint('Breakdown error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runTranslate(String text, String targetLang) async {
    if (!_isAiEnabled) return;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repository.translate(text, targetLang, apiKey: _activeGeminiKey);
      final aiMessage = AiMessage(text: 'Translation: $result', sender: AiSender.ai);
      _messages.add(aiMessage);
      await _repository.saveMessage(aiMessage);
    } catch (e) {
      debugPrint('Translation error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runSummarize(String text) async {
    if (!_isAiEnabled) return;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repository.summarize(text, apiKey: _activeGeminiKey);
      final aiMessage = AiMessage(text: 'Summary: $result', sender: AiSender.ai);
      _messages.add(aiMessage);
      await _repository.saveMessage(aiMessage);
    } catch (e) {
      debugPrint('Summary error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _messages = [];
    // TODO: Implement persistent clear in repository
    notifyListeners();
  }

  // Templates
  List<Map<String, String>> get promptTemplates => [
    {'name': 'Analyze Grammar', 'prompt': 'Analyze the grammar and etymology of the following sentence: '},
    {'name': 'Breakdown Vocabulary', 'prompt': 'Break down each word in the following text with meanings and readings: '},
    {'name': 'Translate to English', 'prompt': 'Translate the following text to natural English: '},
    {'name': 'Explain Like 5', 'prompt': 'Explain the following concept like I am a 5-year-old: '},
    {'name': 'Usage Examples', 'prompt': 'Give me 3 different example sentences showing how to use the following word in context: '},
    {'name': 'Politeness Level', 'prompt': 'Explain the politeness level (keigo/informal) of the following text and suggest alternatives: '},
    {'name': 'Summarize', 'prompt': 'Provide a concise bullet-point summary of the following text: '},
    {'name': 'Identify Slang', 'prompt': 'Identify any slang, idioms, or cultural references in the following text: '},
    {'name': 'Pitch Accent', 'prompt': 'Explain the pitch accent and pronunciation nuances for the following words: '},
    {'name': 'Karakoke Lyrics', 'prompt': 'Break down the meaning and poetic nuances of these song lyrics: '},
  ];
}
