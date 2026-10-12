import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One clipboard-manager entry: text or image, plus metadata.
class ClipboardItem {
  final String id;
  final String? text;

  /// Absolute path of the stored image file (image lives on disk, not
  /// in the prefs payload).
  final String? imagePath;

  final int timestamp;
  final bool pinned;
  final List<String> tags;

  /// Where the entry came from ('monitor', 'manual', 'screenshot_ocr').
  final String source;

  const ClipboardItem({
    required this.id,
    this.text,
    this.imagePath,
    required this.timestamp,
    this.pinned = false,
    this.tags = const [],
    this.source = 'monitor',
  });

  bool get isImage => imagePath != null;
  bool get isText => text != null;

  /// One-line preview for list rows.
  String preview() {
    if (isText) {
      final t = text!.trim().replaceAll('\n', ' ⏎ ');
      return t.length > 120 ? '${t.substring(0, 120)}…' : t;
    }
    return '🖼 image';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (text != null) 'text': text,
    if (imagePath != null) 'imagePath': imagePath,
    'timestamp': timestamp,
    'pinned': pinned,
    'tags': tags,
    'source': source,
  };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
    id: json['id']?.toString() ?? '',
    text: json['text'] as String?,
    imagePath: json['imagePath'] as String?,
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    pinned: json['pinned'] == true,
    tags: ((json['tags'] as List?) ?? const [])
        .map((t) => t.toString())
        .toList(),
    source: json['source']?.toString() ?? 'monitor',
  );

  ClipboardItem copyWith({
    String? text,
    bool? pinned,
    List<String>? tags,
    String? imagePath,
  }) => ClipboardItem(
    id: id,
    text: text ?? this.text,
    imagePath: imagePath ?? this.imagePath,
    timestamp: timestamp,
    pinned: pinned ?? this.pinned,
    tags: tags ?? this.tags,
    source: source,
  );
}

/// Polling / performance configuration, persisted and owned by the
/// manager service; the monitor reads its cadence from here.
class ClipboardPollingConfig {
  final int textIntervalMs;
  final int imageIntervalMs;
  final bool imagePollingEnabled;
  final int maxItems;
  final int maxItemBytes;

  const ClipboardPollingConfig({
    this.textIntervalMs = 500,
    this.imageIntervalMs = 4000,
    this.imagePollingEnabled = true,
    this.maxItems = 500,
    this.maxItemBytes = 5 * 1024 * 1024,
  });

  ClipboardPollingConfig copyWith({
    int? textIntervalMs,
    int? imageIntervalMs,
    bool? imagePollingEnabled,
    int? maxItems,
    int? maxItemBytes,
  }) => ClipboardPollingConfig(
    textIntervalMs: textIntervalMs ?? this.textIntervalMs,
    imageIntervalMs: imageIntervalMs ?? this.imageIntervalMs,
    imagePollingEnabled: imagePollingEnabled ?? this.imagePollingEnabled,
    maxItems: maxItems ?? this.maxItems,
    maxItemBytes: maxItemBytes ?? this.maxItemBytes,
  );

  Map<String, dynamic> toJson() => {
    'textIntervalMs': textIntervalMs,
    'imageIntervalMs': imageIntervalMs,
    'imagePollingEnabled': imagePollingEnabled,
    'maxItems': maxItems,
    'maxItemBytes': maxItemBytes,
  };

  factory ClipboardPollingConfig.fromJson(Map<String, dynamic> json) =>
      ClipboardPollingConfig(
        textIntervalMs: (json['textIntervalMs'] as num?)?.toInt() ?? 500,
        imageIntervalMs: (json['imageIntervalMs'] as num?)?.toInt() ?? 4000,
        imagePollingEnabled: json['imagePollingEnabled'] != false,
        maxItems: (json['maxItems'] as num?)?.toInt() ?? 500,
        maxItemBytes:
            (json['maxItemBytes'] as num?)?.toInt() ?? 5 * 1024 * 1024,
      );
}

/// CopyQ/Ditto-style clipboard manager store.
///
/// Owns the clipboard entry list (text inline, images on disk), manual
/// ordering with pinned section, tags, and the polling configuration the
/// monitor service follows. Persists metadata in SharedPreferences and
/// image payloads under the app-support directory.
class ClipboardManagerService extends ChangeNotifier {
  static final ClipboardManagerService instance = ClipboardManagerService();

  static const _kItemsKey = 'clipboard_manager_items';
  static const _kConfigKey = 'clipboard_manager_config';

  List<ClipboardItem> _items = [];
  ClipboardPollingConfig _config = const ClipboardPollingConfig();
  bool _loaded = false;
  Directory? _imageDir;

  List<ClipboardItem> get items => List.unmodifiable(_items);
  ClipboardPollingConfig get config => _config;
  bool get isLoaded => _loaded;

  /// Pinned entries first (their manual order), then unpinned.
  List<ClipboardItem> get orderedItems {
    final pinned = _items.where((i) => i.pinned).toList();
    final rest = _items.where((i) => !i.pinned).toList();
    return [...pinned, ...rest];
  }

  Future<Directory> _imagesDir() async {
    if (_imageDir != null) return _imageDir!;
    final base = await getApplicationSupportDirectory();
    _imageDir = Directory('${base.path}/clipboard_images')
      ..createSync(recursive: true);
    return _imageDir!;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawItems = prefs.getString(_kItemsKey);
      if (rawItems != null && rawItems.isNotEmpty) {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          _items = decoded
              .whereType<Map>()
              .map(
                (e) => ClipboardItem.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v)),
                ),
              )
              .toList();
        }
      }
      final rawCfg = prefs.getString(_kConfigKey);
      if (rawCfg != null && rawCfg.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawCfg);
          if (decoded is Map) {
            _config = ClipboardPollingConfig.fromJson(
              decoded.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('ClipboardManagerService load error: $e');
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kItemsKey,
      jsonEncode([for (final i in _items) i.toJson()]),
    );
  }

  Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigKey, jsonEncode(_config.toJson()));
  }

  void updateConfig(ClipboardPollingConfig next) {
    _config = next;
    saveConfig();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // adds
  // ------------------------------------------------------------

  /// Add (or dedupe-move) a text entry. Returns the entry.
  Future<ClipboardItem> addText(
    String text, {
    String source = 'monitor',
  }) async {
    await load();
    // dedupe: same text → move to top (respecting pinned-ness)
    final existing = _items.indexWhere((i) => i.text == text);
    if (existing >= 0) {
      final item = _items.removeAt(existing);
      _items.insert(0, item);
      await _persist();
      notifyListeners();
      return item;
    }
    final item = ClipboardItem(
      id: 'cb_${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      source: source,
    );
    _items.insert(0, item);
    await _enforceLimit();
    await _persist();
    notifyListeners();
    return item;
  }

  /// Add an image entry; bytes are written to the image dir. Oversized
  /// payloads beyond [config.maxItemBytes] are rejected (return null).
  Future<ClipboardItem?> addImage(
    Uint8List bytes, {
    String source = 'monitor',
    String extension = 'png',
  }) async {
    await load();
    if (bytes.length > _config.maxItemBytes) return null;
    final dir = await _imagesDir();
    final now = DateTime.now();
    final path =
        '${dir.path}/img_${now.millisecondsSinceEpoch}.${extension.isEmpty ? 'png' : extension}';
    await File(path).writeAsBytes(bytes);
    final item = ClipboardItem(
      id: 'cbi_${now.millisecondsSinceEpoch}_${_items.length}',
      imagePath: path,
      timestamp: now.millisecondsSinceEpoch,
      source: source,
    );
    _items.insert(0, item);
    await _enforceLimit();
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> _enforceLimit() async {
    // drop oldest unpinned beyond maxItems; delete orphaned image files
    while (_items.length > _config.maxItems) {
      final idx = _items.lastIndexWhere((i) => !i.pinned);
      if (idx < 0) break;
      final removed = _items.removeAt(idx);
      if (removed.imagePath != null) {
        try {
          final f = File(removed.imagePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  // ------------------------------------------------------------
  // item operations
  // ------------------------------------------------------------

  /// Write an entry back to the system clipboard. Returns true on
  /// success (text path is reliable; image path is best-effort via
  /// the caller-supplied writer).
  Future<bool> copyItem(
    ClipboardItem item, {
    required Future<void> Function(Uint8List bytes)? copyImageBytes,
  }) async {
    if (item.isText) {
      await ClipboardSetText.write(item.text!);
      return true;
    }
    if (item.isImage && copyImageBytes != null) {
      try {
        final bytes = await File(item.imagePath!).readAsBytes();
        await copyImageBytes(bytes);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<ClipboardItem?> editItemText(String id, String newText) async {
    await load();
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return null;
    final updated = _items[idx].copyWith(text: newText);
    _items[idx] = updated;
    await _persist();
    notifyListeners();
    return updated;
  }

  Future<void> remove(String id) async {
    await load();
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final removed = _items.removeAt(idx);
    if (removed.imagePath != null) {
      try {
        final f = File(removed.imagePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }

  /// Clear all unpinned entries (pinned survive, CopyQ/Ditto behaviour).
  Future<int> clearUnpinned() async {
    await load();
    final removed = _items.where((i) => !i.pinned).toList();
    _items.removeWhere((i) => !i.pinned);
    for (final r in removed) {
      if (r.imagePath != null) {
        try {
          final f = File(r.imagePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
    await _persist();
    notifyListeners();
    return removed.length;
  }

  Future<void> togglePin(String id) async {
    await load();
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(pinned: !_items[idx].pinned);
    await _persist();
    notifyListeners();
  }

  Future<void> setTags(String id, List<String> tags) async {
    await load();
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(tags: tags);
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // manual ordering (operates on the ordered view: pinned section then
  // unpinned section; moves never cross the pinned boundary)
  // ------------------------------------------------------------

  Future<void> move(String id, ClipboardMoveDir dir) async {
    await load();
    final ordered = orderedItems;
    final pos = ordered.indexWhere((i) => i.id == id);
    if (pos < 0) return;
    final item = ordered[pos];

    int target;
    switch (dir) {
      case ClipboardMoveDir.top:
        target = 0;
      case ClipboardMoveDir.up:
        target = (pos - 1).clamp(0, ordered.length - 1);
      case ClipboardMoveDir.down:
        target = (pos + 1).clamp(0, ordered.length - 1);
      case ClipboardMoveDir.bottom:
        target = ordered.length - 1;
    }
    if (target == pos) return;

    // rebuild the backing list in the new ordered arrangement
    ordered.removeAt(pos);
    ordered.insert(target, item);

    final pinnedOnly = ordered.where((i) => i.pinned).toSet();
    final newPinned = ordered.where((i) => pinnedOnly.contains(i)).toList();
    final newRest = ordered.where((i) => !pinnedOnly.contains(i)).toList();
    _items = [...newRest, ...newPinned.reversed];
    // note: _items order is "unpinned (oldest→newest at tail) + pinned";
    // simpler: keep a single list ordered like the view
    _items = ordered;
    await _persist();
    notifyListeners();
  }
}

enum ClipboardMoveDir { top, up, down, bottom }

/// Clipboard text setter isolated so tests can stub it.
class ClipboardSetText {
  static Future<void> Function(String text)? override;

  static Future<void> write(String text) async {
    final o = override;
    if (o != null) {
      await o(text);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}
