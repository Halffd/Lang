import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NoteLocalDataSource {
  static const String _wordsKey = 'words';
  static const String _saveKey = 'save';
  static const String _historyKey = 'history';

  Map<String, dynamic>? _saveCache;
  List<String>? _wordsCache;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_wordsKey)) await prefs.setString(_wordsKey, '');
    if (!prefs.containsKey(_saveKey)) await prefs.setString(_saveKey, '{}');
    if (!prefs.containsKey(_historyKey)) await prefs.setStringList(_historyKey, []);
  }

  Future<Map<String, dynamic>> getSave() async {
    if (_saveCache != null) return _saveCache!;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_saveKey) ?? '{}';
    try {
      _saveCache = json.decode(data);
      return _saveCache!;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getSavedEntries() async {
    final save = await getSave();
    // Convert the map to a list of entries, sorted by ID (timestamp) descending
    final entries = save.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    entries.sort((a, b) => (b['id'] ?? '0').compareTo(a['id'] ?? '0'));
    return entries;
  }

  Future<List<String>> getWords() async {
    if (_wordsCache != null) return _wordsCache!;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_wordsKey) ?? '';
    _wordsCache = data.split(' ').where((w) => w.isNotEmpty).toList();
    return _wordsCache!;
  }

  Future<void> addWord(String word, {String? sentence}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update words list
    List<String> words = await getWords();
    if (!words.contains(word)) {
      words.add(word);
      await prefs.setString(_wordsKey, words.join(' '));
      _wordsCache = words;
    }

    // Update save object
    Map<String, dynamic> save = await getSave();
    final String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    
    final entry = {
      'word': word,
      'sentence': sentence ?? '',
      'id': timestamp,
    };
    
    save[timestamp] = entry;
    await prefs.setString(_saveKey, json.encode(save));
    _saveCache = save;
  }

  Future<void> removeWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update words list
    List<String> words = await getWords();
    if (words.contains(word)) {
      words.remove(word);
      await prefs.setString(_wordsKey, words.join(' '));
      _wordsCache = words;
    }

    // Update save object
    Map<String, dynamic> save = await getSave();
    final keyToRemove = save.keys.firstWhere(
      (k) => save[k]['word'] == word,
      orElse: () => '',
    );
    
    if (keyToRemove.isNotEmpty) {
      save.remove(keyToRemove);
      await prefs.setString(_saveKey, json.encode(save));
      _saveCache = save;
    }
  }

  Future<bool> isKnown(String word) async {
    final words = await getWords();
    return words.contains(word);
  }

  // --- History ---

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addToHistory(String word) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = await getHistory();
    history.remove(word); // Remove if exists to move to top
    history.insert(0, word);
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }
    await prefs.setStringList(_historyKey, history);
  }
}
