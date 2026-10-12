import 'dart:convert';

import 'package:lang/core/services/app_storage.dart';

/// Saved words / history data source.
///
/// Payloads route through [AppStorage] (SQLite or local files per the
/// storage backend setting); the legacy SharedPreferences copies are
/// imported on first access and remain as a downgrade path.
class NoteLocalDataSource {
  static const String _wordsKey = 'words';
  static const String _saveKey = 'save';
  static const String _historyKey = 'history';

  Map<String, dynamic>? _saveCache;
  List<String>? _wordsCache;

  Future<void> init() async {
    // ensure keys exist in the chosen backend (empty defaults)
    final existing = await AppStorage.readWithMigration(
      _wordsKey,
      legacyPrefsKey: _wordsKey,
    );
    if (existing == null) {
      await AppStorage.instance.write(_wordsKey, '');
    }
    final save = await AppStorage.readWithMigration(
      _saveKey,
      legacyPrefsKey: _saveKey,
    );
    if (save == null) {
      await AppStorage.instance.write(_saveKey, '{}');
    }
    final history = await AppStorage.readWithMigration(
      _historyKey,
      legacyPrefsKey: _historyKey,
    );
    if (history == null) {
      await AppStorage.instance.write(_historyKey, '[]');
    }
  }

  Future<Map<String, dynamic>> getSave() async {
    if (_saveCache != null) return _saveCache!;
    final data =
        await AppStorage.readWithMigration(
          _saveKey,
          legacyPrefsKey: _saveKey,
        ) ??
        '{}';
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
    final entries = save.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    entries.sort((a, b) => (b['id'] ?? '0').compareTo(a['id'] ?? '0'));
    return entries;
  }

  Future<List<String>> getWords() async {
    if (_wordsCache != null) return _wordsCache!;
    final data =
        await AppStorage.readWithMigration(
          _wordsKey,
          legacyPrefsKey: _wordsKey,
        ) ??
        '';
    _wordsCache = data.split(' ').where((w) => w.isNotEmpty).toList();
    return _wordsCache!;
  }

  Future<void> addWord(String word, {String? sentence}) async {
    // Update words list
    List<String> words = await getWords();
    if (!words.contains(word)) {
      words.add(word);
      await AppStorage.instance.write(_wordsKey, words.join(' '));
      _wordsCache = words;
    }

    // Update save object
    Map<String, dynamic> save = await getSave();
    final String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();

    final entry = {'word': word, 'sentence': sentence ?? '', 'id': timestamp};

    save[timestamp] = entry;
    await AppStorage.instance.write(_saveKey, json.encode(save));
    _saveCache = save;
  }

  Future<void> removeWord(String word) async {
    // Update words list
    List<String> words = await getWords();
    if (words.contains(word)) {
      words.remove(word);
      await AppStorage.instance.write(_wordsKey, words.join(' '));
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
      await AppStorage.instance.write(_saveKey, json.encode(save));
      _saveCache = save;
    }
  }

  Future<bool> isKnown(String word) async {
    final words = await getWords();
    return words.contains(word);
  }

  // --- History ---

  Future<List<String>> getHistory() async {
    final raw =
        await AppStorage.readWithMigration(
          _historyKey,
          legacyPrefsKey: _historyKey,
        ) ??
        '[]';
    try {
      final decoded = json.decode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  Future<void> addToHistory(String word) async {
    List<String> history = await getHistory();
    history.remove(word); // Remove if exists to move to top
    history.insert(0, word);
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }
    await AppStorage.instance.write(_historyKey, json.encode(history));
  }
}
