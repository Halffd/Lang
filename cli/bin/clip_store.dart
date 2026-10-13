/// Clipboard-manager explorer for the Lang CLI.
///
/// Reads the same stores the app writes:
/// - SQLite backend: `<support>/lang_storage.db`, table `kv` key
///   `clipboard_manager_items`, image bytes in table `media`
/// - Files backend: `<support>/lang_storage/clipboard_manager_items.json`,
///   images under `lang_storage/media/`
/// - Legacy: `shared_preferences.json` → key `clipboard_manager_items`
///
/// Support-dir candidates (first that exists wins): `$LANG_HOME`,
/// `$XDG_DATA_HOME/lang`, `~/.local/share/lang`,
/// `~/.local/share/io.github.halffd.lang`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// One clipboard entry as stored by the app.
class ClipItem {
  final String id;
  final String? text;
  final String? imageRef; // db:<id> | file:<path> | legacy bare path
  final int timestamp;
  final bool pinned;
  final List<String> tags;
  final String source;

  ClipItem({
    required this.id,
    this.text,
    this.imageRef,
    required this.timestamp,
    required this.pinned,
    required this.tags,
    required this.source,
  });

  bool get isImage => imageRef != null;
  bool get isText => text != null;

  factory ClipItem.fromJson(Map<String, dynamic> json) => ClipItem(
    id: json['id']?.toString() ?? '',
    text: json['text'] as String?,
    imageRef: json['imagePath'] as String?,
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    pinned: json['pinned'] == true,
    tags: ((json['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    source: json['source']?.toString() ?? 'monitor',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (text != null) 'text': text,
    if (imageRef != null) 'imagePath': imageRef,
    'timestamp': timestamp,
    'pinned': pinned,
    'tags': tags,
    'source': source,
  };

  String get preview {
    if (isImage) return '[image]';
    final t = text!.trim().replaceAll('\n', ' ⏎ ');
    return t.length > 90 ? '${t.substring(0, 90)}…' : t;
  }

  String get timeLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${d.year}-${_two(d.month)}-${_two(d.day)} '
        '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// Everything the CLI knows about the on-disk store.
class ClipStore {
  /// Which source the items were read from.
  final String backend;
  final String supportDir;
  final List<ClipItem> items;

  ClipStore({
    required this.backend,
    required this.supportDir,
    required this.items,
  });

  /// Items in display order: pinned first, then newest first.
  List<ClipItem> get ordered {
    final pinned = items.where((i) => i.pinned).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final rest = items.where((i) => !i.pinned).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [...pinned, ...rest];
  }
}

// ------------------------------------------------------------
// store discovery + readers
// ------------------------------------------------------------

/// Resolve the app support directory.
String? resolveSupportDir() {
  final env = Platform.environment;
  final home = env['HOME'] ?? '';
  final candidates = <String>[
    if (env['LANG_HOME'] != null) env['LANG_HOME']!,
    if (env['XDG_DATA_HOME'] != null)
      '${env['XDG_DATA_HOME']}/lang'
    else if (home.isNotEmpty)
      '$home/.local/share/lang',
    if (home.isNotEmpty) '$home/.local/share/io.github.halffd.lang',
  ];
  for (final c in candidates) {
    if (Directory(c).existsSync()) return c;
  }
  return null;
}

/// Load items, trying sqlite → files → legacy prefs.
ClipStore loadStore() {
  final support = resolveSupportDir();
  if (support == null) {
    stderr.writeln(
      'error: no Lang store found. Looked in \$LANG_HOME, '
      '\$XDG_DATA_HOME/lang, ~/.local/share/{lang,io.github.halffd.lang}. '
      'Set LANG_HOME to the app support directory.',
    );
    exit(2);
  }

  final sqliteDb = File('$support/lang_storage.db');
  if (sqliteDb.existsSync()) {
    try {
      final items = readFromSqlite(sqliteDb.path);
      return ClipStore(backend: 'sqlite', supportDir: support, items: items);
    } catch (e) {
      stderr.writeln('warning: sqlite read failed ($e); trying files');
    }
  }

  final filesStore = File('$support/lang_storage/clipboard_manager_items.json');
  if (filesStore.existsSync()) {
    try {
      final items = parseItemsJson(filesStore.readAsStringSync());
      return ClipStore(backend: 'files', supportDir: support, items: items);
    } catch (e) {
      stderr.writeln('warning: files read failed ($e); trying legacy prefs');
    }
  }

  final legacy = File('$support/shared_preferences.json');
  if (legacy.existsSync()) {
    final items = readFromLegacyPrefs(legacy.readAsStringSync());
    return ClipStore(
      backend: 'legacy-prefs',
      supportDir: support,
      items: items,
    );
  }

  return ClipStore(backend: 'none', supportDir: support, items: []);
}

List<ClipItem> parseItemsJson(String raw) {
  if (raw.trim().isEmpty) return [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => ClipItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();
}

/// Legacy shared_preferences.json: top-level map; the items key holds a
/// JSON string (or, for old string-list keys, a JSON array).
List<ClipItem> readFromLegacyPrefs(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return [];
  final value = decoded['clipboard_manager_items'];
  if (value == null) return [];
  if (value is String) return parseItemsJson(value);
  if (value is List) return parseItemsJson(jsonEncode(value));
  return [];
}

/// Read items from the sqlite kv store.
List<ClipItem> readFromSqlite(String path) {
  final db = sqlite3.open(path);
  try {
    final rows = db.select(
      "SELECT value FROM kv WHERE key = 'clipboard_manager_items'",
    );
    if (rows.isEmpty) return [];
    final raw = rows.first['value'];
    if (raw is! String) return [];
    return parseItemsJson(raw);
  } finally {
    db.dispose();
  }
}

/// Persist the full item list back to the sqlite kv store (WAL db —
/// safe alongside a running app).
void writeToSqlite(String path, List<ClipItem> items) {
  final db = sqlite3.open(path);
  try {
    final updated = jsonEncode([for (final i in items) i.toJson()]);
    final now = DateTime.now().millisecondsSinceEpoch;
    final stmt = db.prepare(
      'UPDATE kv SET value = ?, updated_at = ? '
      "WHERE key = 'clipboard_manager_items'",
    );
    db.execute('BEGIN IMMEDIATE');
    stmt.execute([updated, now]);
    db.execute('COMMIT');
    stmt.dispose();
  } finally {
    db.dispose();
  }
}

/// Read image bytes for a ref (db:ID, file:PATH, or bare path).
Uint8List? readImageBytes(String supportDir, String ref) {
  if (ref.startsWith('db:')) {
    final id = ref.substring(3);
    final dbPath = '$supportDir/lang_storage.db';
    if (!File(dbPath).existsSync()) return null;
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT data FROM media WHERE id = ?', [id]);
      if (rows.isEmpty) return null;
      final data = rows.first['data'];
      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);
      return null;
    } finally {
      db.dispose();
    }
  }
  final path = ref.startsWith('file:') ? ref.substring(5) : ref;
  final f = File(path);
  if (!f.existsSync()) return null;
  return f.readAsBytesSync();
}

// ------------------------------------------------------------
// filtering
// ------------------------------------------------------------

class ClipFilter {
  String? type; // text | image
  String? tag;
  String? query;
  bool pinnedOnly = false;
  int? withinDays;

  bool matches(ClipItem item) {
    if (type == 'text' && item.isImage) return false;
    if (type == 'image' && !item.isImage) return false;
    if (tag != null && tag!.isNotEmpty && !item.tags.contains(tag)) {
      return false;
    }
    if (pinnedOnly && !item.pinned) return false;
    if (withinDays != null) {
      final cutoff = DateTime.now()
          .subtract(Duration(days: withinDays!))
          .millisecondsSinceEpoch;
      if (item.timestamp < cutoff) return false;
    }
    if (query != null && query!.isNotEmpty) {
      final q = query!.toLowerCase();
      final inText = item.text?.toLowerCase().contains(q) ?? false;
      final inTags = item.tags.any((t) => t.toLowerCase().contains(q));
      final inRef = item.imageRef?.toLowerCase().contains(q) ?? false;
      if (!inText && !inTags && !inRef) return false;
    }
    return true;
  }
}

// ------------------------------------------------------------
// system clipboard writers (xclip / wl-copy / OSC52)
// ------------------------------------------------------------

/// Copy [text] to the system clipboard. Returns false when no tool is
/// available (then the caller may offer --osc52).
bool copyTextToClipboard(String text) {
  if (_hasBin('wl-copy')) {
    final tmp = Directory.systemTemp.createTempSync('lang_clip');
    final f = File('${tmp.path}/txt')..writeAsStringSync(text);
    try {
      final r = Process.runSync('sh', ['-c', 'wl-copy < "${f.path}"']);
      return r.exitCode == 0;
    } finally {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
  if (_hasBin('xclip')) {
    final tmp = Directory.systemTemp.createTempSync('lang_clip');
    final f = File('${tmp.path}/txt')..writeAsStringSync(text);
    try {
      final r = Process.runSync('sh', [
        '-c',
        'xclip -selection clipboard -in "${f.path}"',
      ]);
      return r.exitCode == 0;
    } finally {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
  return false;
}

/// Copy image bytes as image/png.
bool copyImageToClipboard(List<int> bytes) {
  final tmp = Directory.systemTemp.createTempSync('lang_clip');
  final f = File('${tmp.path}/img.png')..writeAsBytesSync(bytes);
  try {
    if (_hasBin('wl-copy')) {
      final r = Process.runSync('sh', ['-c', 'wl-copy < "${f.path}"']);
      return r.exitCode == 0;
    }
    if (_hasBin('xclip')) {
      final r = Process.runSync('sh', [
        '-c',
        'xclip -selection clipboard -t image/png -i "${f.path}"',
      ]);
      return r.exitCode == 0;
    }
    return false;
  } finally {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// OSC 52 escape sequence — works over ssh terminals.
void printOsc52(String text) {
  final b64 = base64Encode(utf8.encode(text));
  stdout.write('\x1b]52;c;$b64\x07');
}

bool _hasBin(String bin) {
  final r = Process.runSync('sh', ['-c', 'command -v $bin >/dev/null 2>&1']);
  return r.exitCode == 0;
}
