import 'dart:typed_data';
import '../entities/analyzed_word.dart';

abstract class AnalyzerRepository {
  Future<void> init();
  
  // Settings
  Future<Map<String, dynamic>> getSettings();
  Future<void> saveSettings(Map<String, dynamic> settings);
  
  // Analysis
  Future<List<String>> tokenizeText(String text, String lang);
  Map<String, String> splitSentences(List<String> tokens);
  
  // Dictionary / Lookup
  Future<AnalyzedWord> enrichWord(String word, String lang, {
    bool showIchiMoe = true,
    bool showWiktionary = true,
    bool showKanji = true,
    bool showEtymology = true,
  });

  Future<List<AnalyzedWord>> lookupWord(String query, String lang);

  // Dictionary Management
  Future<List<Map<String, dynamic>>> getInstalledDictionaries();
  Future<void> importDictionary(Uint8List bytes);
  Future<void> deleteDictionary(String title);

  // Saved Words
  Future<void> saveWord(String word, {String? sentence});
  Future<void> removeSavedWord(String word);
  Future<List<Map<String, dynamic>>> getSavedWords();
  Future<bool> isWordSaved(String word);
  
  // History
  Future<List<String>> getHistory();
  Future<void> addToHistory(String word);

  // Audio
  Future<void> playAudio(String text, String lang);
}
