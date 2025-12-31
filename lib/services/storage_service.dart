import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // SharedPreferences methods
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);
  double? getDouble(String key) => _prefs.getDouble(key);
  String? getString(String key) => _prefs.getString(key);
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  Map<String, dynamic>? getJson(String key) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  Future<bool> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);

  Future<bool> setJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, json.encode(value));
  }

  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();

  // Word list methods
  Future<Set<String>> getSavedWords() async {
    final words = _prefs.getStringList('saved_words') ?? [];
    return Set<String>.from(words);
  }

  Future<void> saveWord(String word) async {
    final words = await getSavedWords();
    words.add(word);
    await _prefs.setStringList('saved_words', words.toList());
  }

  Future<void> removeWord(String word) async {
    final words = await getSavedWords();
    words.remove(word);
    await _prefs.setStringList('saved_words', words.toList());
  }

  Future<Set<String>> getDeletedWords() async {
    final words = _prefs.getStringList('deleted_words') ?? [];
    return Set<String>.from(words);
  }

  Future<void> addToDeletedWords(String word) async {
    final words = await getDeletedWords();
    words.add(word);
    await _prefs.setStringList('deleted_words', words.toList());
  }

  Future<void> removeFromDeletedWords(String word) async {
    final words = await getDeletedWords();
    words.remove(word);
    await _prefs.setStringList('deleted_words', words.toList());
  }

  Future<Set<String>> getAnkiWords() async {
    final words = _prefs.getStringList('anki_words') ?? [];
    return Set<String>.from(words);
  }

  Future<void> addToAnkiWords(String word) async {
    final words = await getAnkiWords();
    words.add(word);
    await _prefs.setStringList('anki_words', words.toList());
  }

  Future<void> removeFromAnkiWords(String word) async {
    final words = await getAnkiWords();
    words.remove(word);
    await _prefs.setStringList('anki_words', words.toList());
  }

  Future<Set<String>> getFavoriteWords() async {
    final words = _prefs.getStringList('favorite_words') ?? [];
    return Set<String>.from(words);
  }

  Future<void> addToFavorites(String word) async {
    final words = await getFavoriteWords();
    words.add(word);
    await _prefs.setStringList('favorite_words', words.toList());
  }

  Future<void> removeFromFavorites(String word) async {
    final words = await getFavoriteWords();
    words.remove(word);
    await _prefs.setStringList('favorite_words', words.toList());
  }
}
