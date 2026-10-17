import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:lang/core/services/app_storage.dart';

/// Shared bookmark / rename / tags / colors metadata for any item the app
/// tracks — transcription sessions, history entries, analyze-screen
/// sentences. One record per (domain, id); persisted through AppStorage.
class ItemLabel {
  /// Display name override. Null = use the item's own name.
  final String? name;

  final bool bookmarked;

  final List<String> tags;

  /// ARGB color value; null = no custom color.
  final int? color;

  const ItemLabel({
    this.name,
    this.bookmarked = false,
    this.tags = const [],
    this.color,
  });

  static const ItemLabel empty = ItemLabel();

  bool get isEmpty =>
      name == null && !bookmarked && tags.isEmpty && color == null;

  ItemLabel copyWith({
    String? name,
    bool? bookmarked,
    List<String>? tags,
    int? color,
    bool clearName = false,
    bool clearColor = false,
  }) {
    return ItemLabel(
      name: clearName ? null : (name ?? this.name),
      bookmarked: bookmarked ?? this.bookmarked,
      tags: tags ?? this.tags,
      color: clearColor ? null : (color ?? this.color),
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    'bookmarked': bookmarked,
    if (tags.isNotEmpty) 'tags': tags,
    if (color != null) 'color': color,
  };

  factory ItemLabel.fromJson(Map<String, dynamic> json) => ItemLabel(
    name: json['name']?.toString(),
    bookmarked: json['bookmarked'] == true,
    tags: ((json['tags'] as List?) ?? const [])
        .map((t) => t.toString())
        .toList(),
    color: (json['color'] as num?)?.toInt(),
  );
}

/// Color palette offered by the label editor (name + ARGB).
const List<(String, int)> kLabelColors = [
  ('Red', 0xFFE53935),
  ('Orange', 0xFFFB8C00),
  ('Yellow', 0xFFFDD835),
  ('Green', 0xFF43A047),
  ('Teal', 0xFF00897B),
  ('Blue', 0xFF1E88E5),
  ('Purple', 0xFF8E24AA),
  ('Pink', 0xFFEC407A),
];

/// Per-domain label storage + lookup. Domains are free-form strings
/// (`speech-session`, `history`, `analyze-sentence`, ...); ids are the
/// host item's stable key. Persisted through AppStorage as one JSON
/// document per domain.
class LabelService extends ChangeNotifier {
  LabelService._();
  static final LabelService instance = LabelService._();

  static const String domainSpeechSession = 'speech-session';
  static const String domainHistory = 'history';
  static const String domainAnalyzeSentence = 'analyze-sentence';

  final Map<String, Map<String, ItemLabel>> _cache = {};

  String _docKey(String domain) => 'labels/$domain';

  /// Label for (domain, id), or null when unlabeled.
  ItemLabel? get(String domain, String id) {
    final cached = _cache[domain];
    if (cached != null) return cached[id];
    return _loadDomainSync(domain)[id];
  }

  /// Synchronous domain map: served from cache; on first access the
  /// AppStorage document is read via the one-shot legacy migration
  /// (file backends are sync-readable; sqlite falls back to cache after
  /// the first [preload] call).
  Map<String, ItemLabel> _loadDomainSync(String domain) {
    final cached = _cache[domain];
    if (cached != null) return cached;
    // synchronous first-read: only possible for file-backed storage
    // (AppStorage.read is async for sqlite). Misses serve empty until
    // a [preload] or [set] fills the cache.
    var raw = AppStorage.readFileSync(_docKey(domain));
    final map = <String, ItemLabel>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            map[e.key.toString()] = ItemLabel.fromJson(
              (e.value as Map).map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        }
      } catch (_) {}
    }
    _cache[domain] = map;
    return map;
  }

  /// Pre-read a domain's document (async for the sqlite backend). Call
  /// before first synchronous [get] on that domain.
  Future<void> preload(String domain) async {
    if (_cache.containsKey(domain)) return;
    final raw = await AppStorage.instance.read(_docKey(domain));
    final map = <String, ItemLabel>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            map[e.key.toString()] = ItemLabel.fromJson(
              (e.value as Map).map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        }
      } catch (_) {}
    }
    _cache[domain] = map;
    notifyListeners();
  }

  /// Create / update the label for (domain, id).
  Future<void> set(String domain, String id, ItemLabel label) async {
    final map = _loadDomainSync(domain);
    if (label.isEmpty) {
      map.remove(id);
    } else {
      map[id] = label;
    }
    _cache[domain] = map;
    await AppStorage.instance.write(
      _docKey(domain),
      jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}),
    );
    notifyListeners();
  }

  Future<void> remove(String domain, String id) =>
      set(domain, id, ItemLabel.empty);

  Future<void> toggleBookmark(String domain, String id) async {
    final current = get(domain, id) ?? ItemLabel.empty;
    await set(domain, id, current.copyWith(bookmarked: !current.bookmarked));
  }

  /// Move a label from [oldId] to [newId] (rename support): drops the old
  /// record when the new id has none, merges otherwise.
  Future<void> rename(String domain, String oldId, String newId) async {
    if (oldId == newId) return;
    final map = _loadDomainSync(domain);
    final old = map.remove(oldId);
    if (old == null) return;
    final existing = map[newId];
    map[newId] = existing ?? old;
    _cache[domain] = map;
    await AppStorage.instance.write(
      _docKey(domain),
      jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}),
    );
    notifyListeners();
  }

  /// Test hook: drop all cached labels.
  @visibleForTesting
  void resetForTest() {
    _cache.clear();
  }
}

/// Opens the shared label editor sheet for (domain, id). [defaultName]
/// pre-fills the rename field with the item's current name.
Future<void> showItemLabelSheet(
  BuildContext context,
  String domain,
  String id, {
  String? defaultName,
}) async {
  final service = LabelService.instance;
  await service.preload(domain);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _ItemLabelSheet(
      domain: domain,
      id: id,
      defaultName: defaultName,
      onRename: defaultName != null
          ? (newName) async {
              await service.rename(domain, defaultName, newName);
            }
          : null,
    ),
  );
}

/// The shared label editor: bookmark toggle, rename field, tags field,
/// color swatches. Saves through LabelService on Apply.
class _ItemLabelSheet extends StatefulWidget {
  final String domain;
  final String id;
  final String? defaultName;
  final Future<void> Function(String newName)? onRename;

  const _ItemLabelSheet({
    required this.domain,
    required this.id,
    this.defaultName,
    this.onRename,
  });

  @override
  State<_ItemLabelSheet> createState() => _ItemLabelSheetState();
}

class _ItemLabelSheetState extends State<_ItemLabelSheet> {
  late final ItemLabel _initial =
      LabelService.instance.get(widget.domain, widget.id) ?? ItemLabel.empty;
  late final TextEditingController _nameCtrl = TextEditingController(
    text:
        LabelService.instance.get(widget.domain, widget.id)?.name ??
        widget.defaultName ??
        '',
  );
  late final TextEditingController _tagsCtrl = TextEditingController(
    text: _initial.tags.join(', '),
  );
  late bool _bookmarked = _initial.bookmarked;
  late int? _color = _initial.color;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Label',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.onRename != null)
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          if (widget.onRename != null) const SizedBox(height: 12),
          TextField(
            controller: _tagsCtrl,
            decoration: const InputDecoration(
              labelText: 'Tags (comma separated)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Color', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (name, value) in kLabelColors)
                Tooltip(
                  message: name,
                  child: InkWell(
                    onTap: () => setState(() => _color = value),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == value
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_color != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear color',
                  onPressed: () => setState(() => _color = null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton.icon(
                icon: Icon(
                  _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(_bookmarked ? 'Bookmarked' : 'Bookmark'),
                onPressed: () => setState(() => _bookmarked = !_bookmarked),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final newName = _nameCtrl.text.trim();
                  if (widget.onRename != null &&
                      newName.isNotEmpty &&
                      widget.defaultName != null &&
                      newName != widget.defaultName) {
                    await widget.onRename!(newName);
                  }
                  final tags = _tagsCtrl.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();
                  await LabelService.instance.set(
                    widget.domain,
                    widget.onRename != null ? newName : widget.id,
                    ItemLabel(
                      name: newName.isEmpty ? null : newName,
                      bookmarked: _bookmarked,
                      tags: tags,
                      color: _color,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small decoration row for labelled items: bookmark icon, color dot and
/// tag chips. Renders nothing when the label is empty.
class ItemLabelBadges extends StatelessWidget {
  final String domain;
  final String id;

  const ItemLabelBadges({super.key, required this.domain, required this.id});

  @override
  Widget build(BuildContext context) {
    final label = LabelService.instance.get(domain, id);
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (label.bookmarked)
            Icon(Icons.bookmark, size: 12, color: theme.colorScheme.primary),
          if (label.color != null)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(label.color!),
                shape: BoxShape.circle,
              ),
            ),
          for (final tag in label.tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 9.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
