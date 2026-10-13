import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'clip_store.dart';

/// `lang clip` — explore / search / list / mutate the clipboard manager's
/// store. Runs standalone (pure Dart): reads the same SQLite / files /
/// legacy-prefs stores the app writes.
Future<void> handleClip(List<String> args) async {
  if (args.isEmpty || args.first == 'help') {
    _printClipUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  final sub = args.first;
  final rest = args.sublist(1);

  switch (sub) {
    case 'list':
      _clipList(rest);
      break;
    case 'search':
      _clipList(rest, implySearch: true);
      break;
    case 'get':
      _clipGet(rest);
      break;
    case 'copy':
      await _clipCopy(rest);
      break;
    case 'image':
      _clipImage(rest);
      break;
    case 'pin':
      _clipSetPinned(rest, true);
      break;
    case 'unpin':
      _clipSetPinned(rest, false);
      break;
    case 'rm':
      _clipRemove(rest);
      break;
    case 'tag':
      _clipTag(rest);
      break;
    case 'clear':
      _clipClear(rest);
      break;
    case 'stats':
      _clipStats();
      break;
    default:
      stderr.writeln("error: unknown clip subcommand '$sub'");
      _printClipUsage();
      exit(1);
  }
}

void _printClipUsage() {
  stdout.writeln('''
lang clip — clipboard manager explorer

Usage: lang clip <subcommand> [options]

Subcommands:
  list                       List entries (pinned first, newest first)
    --type=text|image        Filter by entry type
    --tag=<tag>              Filter by tag
    --pinned                 Pinned entries only
    --days=N                 Only entries from the last N days
    --limit=N                Max rows (default 30; 0 = all)
    --json                   Machine-readable JSON output
  search <query> [opts]      Same as list plus a text/tag/ref query
  get <id|#pos> [--raw]      Print an entry's full text (--raw: no header)
  copy <id|#pos> [--osc52]   Copy entry to system clipboard
                             (--osc52: escape sequence, works over ssh)
  image <id|#pos> [-o FILE]  Export the image payload (default: ./<id>.png)
  pin <id|#pos>              Pin entry
  unpin <id|#pos>            Unpin entry
  tag <id|#pos> <t1,t2>      Replace the entry's tags
  rm <id|#pos>               Remove entry
  clear [--force]            Remove all unpinned entries
  stats                      Store summary (counts by type/source, tags)

Selectors: a full id or a #N / N position from the last list order.
Store: \$LANG_HOME or ~/.local/share/lang (lang_storage.db, or
lang_storage/ files, or the legacy shared_preferences.json).
''');
}

// ------------------------------------------------------------
// arg helpers
// ------------------------------------------------------------

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

bool _hasFlag(List<String> args, String name) => args.contains('--$name');

int _argInt(List<String> args, String name, int fallback) {
  final v = _argValue(args, name);
  return v == null ? fallback : (int.tryParse(v) ?? fallback);
}

/// Resolve a selector (id, #N, or N) to an entry.
ClipItem? _resolveSelector(ClipStore store, String sel) {
  if (sel.startsWith('#')) {
    final pos = int.tryParse(sel.substring(1));
    if (pos == null || pos < 1 || pos > store.ordered.length) return null;
    return store.ordered[pos - 1];
  }
  final byId = store.items.where((i) => i.id == sel).toList();
  if (byId.isNotEmpty) return byId.first;
  final pos = int.tryParse(sel);
  if (pos != null && pos >= 1 && pos <= store.ordered.length) {
    return store.ordered[pos - 1];
  }
  return null;
}

ClipFilter _parseFilter(List<String> args, {bool implySearch = false}) {
  final f = ClipFilter();
  f.type = _argValue(args, 'type');
  f.tag = _argValue(args, 'tag');
  f.pinnedOnly = _hasFlag(args, 'pinned');
  final days = _argValue(args, 'days');
  if (days != null) f.withinDays = int.tryParse(days);
  // query: first non-flag arg (search subcommand) or --query=
  f.query = _argValue(args, 'query');
  if (f.query == null) {
    for (final a in args) {
      if (!a.startsWith('-')) {
        f.query = a;
        break;
      }
    }
  }
  if (implySearch && (f.query == null || f.query!.isEmpty)) {
    stderr.writeln('error: search requires a query');
    exit(1);
  }
  return f;
}

// ------------------------------------------------------------
// subcommands
// ------------------------------------------------------------

void _clipList(List<String> args, {bool implySearch = false}) {
  final store = loadStore();
  final filter = _parseFilter(args, implySearch: implySearch);
  final limit = _argInt(args, 'limit', 30);
  final asJson = _hasFlag(args, 'json');

  final matched = store.ordered.where(filter.matches).toList();
  final shown = limit <= 0 ? matched : matched.take(limit).toList();

  if (asJson) {
    stdout.writeln(
      jsonEncode({
        'backend': store.backend,
        'store': store.supportDir,
        'total': matched.length,
        'items': [for (final i in shown) i.toJson()],
      }),
    );
    return;
  }

  stdout.writeln(
    'clipboard store: ${store.backend} (${store.supportDir}) — '
    '${matched.length} match${matched.length == 1 ? '' : 'es'}',
  );
  if (shown.isEmpty) {
    stdout.writeln('(no entries)');
    return;
  }
  for (var i = 0; i < shown.length; i++) {
    final item = shown[i];
    final pos = store.ordered.indexOf(item) + 1;
    final pin = item.pinned ? '📌 ' : '   ';
    final tagStr = item.tags.isNotEmpty ? ' [${item.tags.join(',')}]' : '';
    stdout.writeln(
      '$pin#${pos.toString().padLeft(3)}  ${item.timeLabel}  '
      '${item.preview}$tagStr',
    );
  }
  if (matched.length > shown.length) {
    stdout.writeln(
      '… ${matched.length - shown.length} more (--limit=0 shows all)',
    );
  }
}

void _clipGet(List<String> args) {
  final sel = args.where((a) => !a.startsWith('-')).firstOrNull;
  if (sel == null) {
    stderr.writeln('error: get requires an id or #position');
    exit(1);
  }
  final store = loadStore();
  final item = _resolveSelector(store, sel);
  if (item == null) {
    stderr.writeln("error: no entry '$sel'");
    exit(1);
  }
  if (item.isImage) {
    stderr.writeln("entry '$sel' is an image — use: lang clip image $sel");
    exit(1);
  }
  final raw = _hasFlag(args, 'raw');
  if (!raw) {
    stdout.writeln('id: ${item.id}');
    stdout.writeln('time: ${item.timeLabel}');
    stdout.writeln('pinned: ${item.pinned}');
    stdout.writeln('tags: ${item.tags.join(", ")}');
    stdout.writeln('source: ${item.source}');
    stdout.writeln('---');
  }
  stdout.write(item.text ?? '');
  if (!raw) stdout.writeln();
}

Future<void> _clipCopy(List<String> args) async {
  final positional = args.where((a) => !a.startsWith('-')).toList();
  if (positional.isEmpty) {
    stderr.writeln('error: copy requires an id or #position');
    exit(1);
  }
  final store = loadStore();
  final item = _resolveSelector(store, positional.first);
  if (item == null) {
    stderr.writeln("error: no entry '${positional.first}'");
    exit(1);
  }

  final osc52 = _hasFlag(args, 'osc52');
  var ok = false;
  if (item.isImage) {
    final bytes = readImageBytes(store.supportDir, item.imageRef!);
    if (bytes == null) {
      stderr.writeln('error: image payload missing for ${item.id}');
      exit(1);
    }
    ok = copyImageToClipboard(bytes);
  } else {
    ok = copyTextToClipboard(item.text ?? '');
    if (!ok && osc52) {
      printOsc52(item.text ?? '');
      stdout.writeln('copied via OSC52 escape sequence');
      return;
    }
  }
  if (!ok) {
    stderr.writeln(
      'error: no clipboard tool found (install wl-copy or xclip), '
      'or use --osc52 for text',
    );
    exit(1);
  }
  stdout.writeln('copied ${item.id}');
}

void _clipImage(List<String> args) {
  final outIdx = args.indexOf('-o');
  final outFile = outIdx >= 0 && outIdx + 1 < args.length
      ? args[outIdx + 1]
      : null;
  final positional = args
      .where((a) => !a.startsWith('-') && a != outFile)
      .toList();
  if (positional.isEmpty) {
    stderr.writeln('error: image requires an id or #position');
    exit(1);
  }
  final store = loadStore();
  final item = _resolveSelector(store, positional.first);
  if (item == null || !item.isImage) {
    stderr.writeln("error: no image entry '${positional.first}'");
    exit(1);
  }
  final bytes = readImageBytes(store.supportDir, item.imageRef!);
  if (bytes == null) {
    stderr.writeln('error: image payload missing for ${item.id}');
    exit(1);
  }
  final target = outFile ?? '${item.id}.png';
  File(target).writeAsBytesSync(bytes);
  stdout.writeln('wrote $target (${bytes.length} bytes)');
}

ClipStore _loadForWrite() {
  final store = loadStore();
  if (store.backend == 'none') {
    stderr.writeln('error: no clipboard entries to modify');
    exit(1);
  }
  if (store.backend == 'legacy-prefs') {
    stderr.writeln(
      'warning: store is the legacy shared_preferences.json; '
      'mutations write to it directly (run the app once to migrate)',
    );
  }
  if (store.backend == 'files') {
    stderr.writeln('note: files-backend mutation writes JSON in place');
  }
  return store;
}

void _persistStore(ClipStore store) {
  final updated = jsonEncode([for (final i in store.items) i.toJson()]);
  if (store.backend == 'sqlite') {
    writeToSqlite('${store.supportDir}/lang_storage.db', store.items);
    return;
  }
  if (store.backend == 'files') {
    File(
      '${store.supportDir}/lang_storage/clipboard_manager_items.json',
    ).writeAsStringSync(updated);
    return;
  }
  // legacy prefs: shared_preferences.json is a flat map of json payloads
  final prefsFile = File('${store.supportDir}/shared_preferences.json');
  final map = jsonDecode(prefsFile.readAsStringSync()) as Map<String, dynamic>;
  map['clipboard_manager_items'] = updated;
  prefsFile.writeAsStringSync(jsonEncode(map));
}

void _clipSetPinned(List<String> args, bool pinned) {
  final sel = args.where((a) => !a.startsWith('-')).firstOrNull;
  if (sel == null) {
    stderr.writeln(
      'error: ${pinned ? 'pin' : 'unpin'} requires an id or #position',
    );
    exit(1);
  }
  final store = _loadForWrite();
  final item = _resolveSelector(store, sel);
  if (item == null) {
    stderr.writeln("error: no entry '$sel'");
    exit(1);
  }
  final idx = store.items.indexWhere((i) => i.id == item.id);
  store.items[idx] = ClipItem(
    id: item.id,
    text: item.text,
    imageRef: item.imageRef,
    timestamp: item.timestamp,
    pinned: pinned,
    tags: item.tags,
    source: item.source,
  );
  _persistStore(store);
  stdout.writeln('${pinned ? 'pinned' : 'unpinned'} ${item.id}');
}

void _clipRemove(List<String> args) {
  final sel = args.where((a) => !a.startsWith('-')).firstOrNull;
  if (sel == null) {
    stderr.writeln('error: rm requires an id or #position');
    exit(1);
  }
  final store = _loadForWrite();
  final item = _resolveSelector(store, sel);
  if (item == null) {
    stderr.writeln("error: no entry '$sel'");
    exit(1);
  }
  // payload cleanup for image entries
  if (item.isImage) {
    final ref = item.imageRef!;
    if (ref.startsWith('db:')) {
      final id = ref.substring(3);
      final db = sqlite3.open('${store.supportDir}/lang_storage.db');
      try {
        db.execute('DELETE FROM media WHERE id = ?', [id]);
      } finally {
        db.dispose();
      }
    } else {
      final path = ref.startsWith('file:') ? ref.substring(5) : ref;
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
  }
  store.items.removeWhere((i) => i.id == item.id);
  _persistStore(store);
  stdout.writeln('removed ${item.id}');
}

void _clipTag(List<String> args) {
  final positional = args.where((a) => !a.startsWith('-')).toList();
  if (positional.length < 2) {
    stderr.writeln('error: tag requires <id|#pos> <tag1,tag2>');
    exit(1);
  }
  final store = _loadForWrite();
  final item = _resolveSelector(store, positional.first);
  if (item == null) {
    stderr.writeln("error: no entry '${positional.first}'");
    exit(1);
  }
  final tags = positional[1]
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  final idx = store.items.indexWhere((i) => i.id == item.id);
  store.items[idx] = ClipItem(
    id: item.id,
    text: item.text,
    imageRef: item.imageRef,
    timestamp: item.timestamp,
    pinned: item.pinned,
    tags: tags,
    source: item.source,
  );
  _persistStore(store);
  stdout.writeln('tags set on ${item.id}: ${tags.join(", ")}');
}

void _clipClear(List<String> args) {
  if (!_hasFlag(args, 'force')) {
    stderr.writeln(
      'error: clear removes every unpinned entry — pass --force to confirm',
    );
    exit(1);
  }
  final store = _loadForWrite();
  final before = store.items.length;
  // delete image payloads too
  for (final item in store.items.where((i) => !i.pinned && i.isImage)) {
    final ref = item.imageRef!;
    if (ref.startsWith('db:')) {
      final db = sqlite3.open('${store.supportDir}/lang_storage.db');
      try {
        db.execute('DELETE FROM media WHERE id = ?', [ref.substring(3)]);
      } finally {
        db.dispose();
      }
    } else {
      final path = ref.startsWith('file:') ? ref.substring(5) : ref;
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
  }
  store.items.removeWhere((i) => !i.pinned);
  _persistStore(store);
  stdout.writeln('removed ${before - store.items.length} entries');
}

void _clipStats() {
  final store = loadStore();
  final text = store.items.where((i) => i.isText).length;
  final images = store.items.where((i) => i.isImage).length;
  final pinned = store.items.where((i) => i.pinned).length;
  final tagCounts = <String, int>{};
  for (final i in store.items) {
    for (final t in i.tags) {
      tagCounts[t] = (tagCounts[t] ?? 0) + 1;
    }
  }
  final sources = <String, int>{};
  for (final i in store.items) {
    sources[i.source] = (sources[i.source] ?? 0) + 1;
  }

  stdout.writeln('store: ${store.backend} (${store.supportDir})');
  stdout.writeln(
    'entries: ${store.items.length} '
    '($text text, $images image, $pinned pinned)',
  );
  if (sources.isNotEmpty) {
    stdout.writeln(
      'sources: ${sources.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
    );
  }
  if (tagCounts.isNotEmpty) {
    final sorted = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln(
      'tags: ${sorted.take(10).map((e) => '${e.key}=${e.value}').join(', ')}',
    );
  }
}
