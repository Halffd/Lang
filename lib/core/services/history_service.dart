import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories tracked by [HistoryService].
enum HistoryCategory {
  search,
  word,
  kanji,
  favorite,
  anki,
  document,
  visit,
  action,
  analysis,
  clipboard,
}

/// One recorded history item.
class HistoryItem {
  final String id;
  final HistoryCategory category;
  final String title;
  final String? subtitle;
  final int timestamp; // ms since epoch

  const HistoryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.timestamp,
    this.subtitle,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'subtitle': subtitle,
    'timestamp': timestamp,
  };

  static HistoryItem fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String,
    category: HistoryCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => HistoryCategory.action,
    ),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    timestamp: (json['timestamp'] as num).toInt(),
  );

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

/// Records user activity across the app: searches, word lookups, kanji
/// views, favorites, anki exports, opened documents, browser visits
/// and generic actions. Persisted to SharedPreferences as JSON.
class HistoryService extends ChangeNotifier {
  static const String _prefsKey = 'activity_history';
  static const int _maxItems = 500;

  static final HistoryService instance = HistoryService._();

  List<HistoryItem> _items = [];
  bool _loaded = false;

  HistoryService._();

  List<HistoryItem> get items => List.unmodifiable(_items);

  bool get isLoaded => _loaded;

  /// Drop cached state so the next [load] re-reads storage.
  /// Only for tests.
  @visibleForTesting
  void resetForTest() {
    _items = [];
    _loaded = false;
  }

  /// Load persisted history. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _items = decoded
            .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('HistoryService load error: $e');
      _items = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Record one event. [subtitle] shows extra context in the list.
  void record(
    HistoryCategory category,
    String title, {
    String? subtitle,
    String? id,
  }) {
    final item = HistoryItem(
      id: id ?? '${category.name}_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      title: title,
      subtitle: subtitle,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _items.insert(0, item);
    if (_items.length > _maxItems) {
      _items = _items.sublist(0, _maxItems);
    }
    notifyListeners();
    _persist();
  }

  /// Remove a single item by id.
  void remove(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    _persist();
  }

  /// Clear everything, or just one category when [category] is set.
  void clear({HistoryCategory? category}) {
    if (category == null) {
      _items = [];
    } else {
      _items.removeWhere((i) => i.category == category);
    }
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_items));
    } catch (e) {
      debugPrint('HistoryService persist error: $e');
    }
  }
}
