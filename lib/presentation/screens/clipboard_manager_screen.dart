import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/clipboard_manager_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Entry-point for the popup hotkey: hosts [ClipboardManagerScreen] in a
/// compact CopyQ-style dialog.
Future<void> showClipboardManagerPopup(BuildContext context) async {
  final theme = Theme.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 640,
        height: 560,
        child: ClipboardManagerScreen(popupMode: true),
      ),
    ),
  );
}

enum _TypeFilter { all, text, image }

enum _DateFilter { any, today, week, month }

/// Full clipboard manager: search, type/tag/date filters, keyboard
/// navigation, multi-select, per-item menus (copy/edit/pin/tags/move/
/// remove), toolbar actions (clear, screenshots with OCR to clipboard,
/// monitor captures, region + last-region, auto-capture interval), and
/// polling/performance + appearance settings.
class ClipboardManagerScreen extends StatefulWidget {
  /// Compact popup styling (smaller paddings, tighter rows).
  final bool popupMode;

  const ClipboardManagerScreen({super.key, this.popupMode = false});

  @override
  State<ClipboardManagerScreen> createState() => _ClipboardManagerScreenState();
}

class _ClipboardManagerScreenState extends State<ClipboardManagerScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Set<String> _selected = {};
  final FocusNode _listFocus = FocusNode();
  int _keyboardIndex = -1;

  _TypeFilter _typeFilter = _TypeFilter.all;
  _DateFilter _dateFilter = _DateFilter.any;
  String _tagFilter = '';
  bool _pinnedOnly = false;

  // appearance config (session-level, defaults from font scale)
  double _rowScale = 1.0;
  double _fontScaleFactor = 1.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // filtering
  // ------------------------------------------------------------

  List<ClipboardItem> _visible(ClipboardManagerService mgr) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();
    return mgr.orderedItems.where((item) {
      if (_pinnedOnly && !item.pinned) return false;
      if (_typeFilter == _TypeFilter.text && !item.isText) return false;
      if (_typeFilter == _TypeFilter.image && !item.isImage) return false;
      if (_tagFilter.isNotEmpty && !item.tags.contains(_tagFilter)) {
        return false;
      }
      if (_dateFilter != _DateFilter.any) {
        final d = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
        final cutoff = switch (_dateFilter) {
          _DateFilter.today => DateTime(now.year, now.month, now.day),
          _DateFilter.week => now.subtract(const Duration(days: 7)),
          _DateFilter.month => DateTime(now.year, now.month),
          _DateFilter.any => null,
        };
        if (cutoff != null && d.isBefore(cutoff)) return false;
      }
      if (q.isNotEmpty) {
        final inText = item.text?.toLowerCase().contains(q) ?? false;
        final inTags = item.tags.any((t) => t.toLowerCase().contains(q));
        final inName = item.imagePath?.toLowerCase().contains(q) ?? false;
        if (!inText && !inTags && !inName) return false;
      }
      return true;
    }).toList();
  }

  // ------------------------------------------------------------
  // actions
  // ------------------------------------------------------------

  Future<void> _copyItem(
    ClipboardItem item,
    ClipboardManagerService mgr,
  ) async {
    final ok = await mgr.copyItem(item, copyImageBytes: _copyImageBytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Copied' : 'Copy failed'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _copyImageBytes(Uint8List bytes) async {
    // image clipboard writes route through the same helper the
    // screenshot tab uses (super_clipboard writer injected at the call
    // site); here we use the platform image writer via X11/Wayland-safe
    // path: fall back to xclip/wl-copy/wins through ScreenshotService's
    // registered writer when available.
    await ClipboardManagerImageCopy.copy(bytes);
  }

  Future<void> _removeSelected(ClipboardManagerService mgr) async {
    if (_selected.isEmpty) return;
    for (final id in _selected.toList()) {
      await mgr.remove(id);
    }
    _selected.clear();
    if (mounted) setState(() {});
  }

  Future<void> _editDialog(
    ClipboardItem item,
    ClipboardManagerService mgr,
  ) async {
    final ctrl = TextEditingController(text: item.text ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit entry'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText != null && newText != item.text) {
      await mgr.editItemText(item.id, newText);
    }
  }

  Future<void> _tagsDialog(
    ClipboardItem item,
    ClipboardManagerService mgr,
  ) async {
    final ctrl = TextEditingController(text: item.tags.join(', '));
    final tagsRaw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tags'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'comma,separated,tags',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (tagsRaw == null) return;
    final tags = tagsRaw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    await mgr.setTags(item.id, tags);
  }

  // ------------------------------------------------------------
  // screenshot + OCR actions (wired like the screenshot tab)
  // ------------------------------------------------------------

  Future<String?> _runOcr(String path) async {
    final appState = context.read<AppState>();
    var engine = OcrService.engineFromName(appState.ocrEngine);
    if (engine == OcrEngine.ai) engine = OcrEngine.mlKit;
    final lang = appState.ocrLanguage;
    final language = (lang.isEmpty || lang == 'auto')
        ? appState.learningLanguage
        : lang;
    final ocrService = OcrService();
    try {
      if (appState.ocrApiEndpoint.isNotEmpty) {
        ocrService.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await ocrService.recognizeFromFile(
        path,
        engine: engine,
        language: language,
        apiKey: appState.ocrApiKey,
      );
      return result.isSuccess ? result.text : null;
    } catch (_) {
      return null;
    } finally {
      ocrService.dispose();
    }
  }

  Future<void> _screenshotAction(
    ScreenshotKind kind, {
    int monitor = 0,
    bool ocrToClipboard = false,
    bool imageToClipboard = false,
  }) async {
    final service = ScreenshotService();
    final item = await service.captureWithPipeline(
      kind,
      monitor: monitor,
      autoOcr: ocrToClipboard,
      copyOcrText: ocrToClipboard,
      copyImage: imageToClipboard,
      ocrRunner: _runOcr,
      copyImageRunner: imageToClipboard
          ? (path) async {
              final bytes = await File(path).readAsBytes();
              await ClipboardManagerImageCopy.copy(bytes);
            }
          : null,
      copyTextRunner: (text) async {
        await ClipboardSetText.write(text);
        await ClipboardManagerService.instance.addText(
          text,
          source: 'screenshot_ocr',
        );
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item == null ? 'Capture failed' : 'Screenshot captured'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  // ------------------------------------------------------------
  // settings sheets
  // ------------------------------------------------------------

  void _showSettings(ClipboardManagerService mgr) {
    final cfg = mgr.config;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clipboard manager settings',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Text polling: ${cfg.textIntervalMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: cfg.textIntervalMs.clamp(250, 5000).toDouble(),
                  min: 250,
                  max: 5000,
                  divisions: 19,
                  label: '${cfg.textIntervalMs} ms',
                  onChanged: (v) => setSheet(
                    () => mgr.updateConfig(
                      cfg.copyWith(textIntervalMs: v.round()),
                    ),
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Poll image clipboard'),
                  value: cfg.imagePollingEnabled,
                  onChanged: (v) => setSheet(() {
                    mgr.updateConfig(
                      cfg.copyWith(imagePollingEnabled: v ?? true),
                    );
                  }),
                ),
                Text(
                  'Image polling: ${cfg.imageIntervalMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: cfg.imageIntervalMs.clamp(1000, 20000).toDouble(),
                  min: 1000,
                  max: 20000,
                  divisions: 19,
                  label: '${cfg.imageIntervalMs} ms',
                  onChanged: (v) => setSheet(
                    () => mgr.updateConfig(
                      cfg.copyWith(imageIntervalMs: v.round()),
                    ),
                  ),
                ),
                Text(
                  'Max entries: ${cfg.maxItems}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: cfg.maxItems.clamp(20, 2000).toDouble(),
                  min: 20,
                  max: 2000,
                  divisions: 19,
                  label: '${cfg.maxItems}',
                  onChanged: (v) => setSheet(
                    () => mgr.updateConfig(cfg.copyWith(maxItems: v.round())),
                  ),
                ),
                Text(
                  'Max entry size: ${(cfg.maxItemBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: cfg.maxItemBytes
                      .clamp(65536, 64 * 1024 * 1024)
                      .toDouble(),
                  min: 65536,
                  max: 64 * 1024 * 1024,
                  divisions: 10,
                  label:
                      '${(cfg.maxItemBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  onChanged: (v) => setSheet(
                    () =>
                        mgr.updateConfig(cfg.copyWith(maxItemBytes: v.round())),
                  ),
                ),
                const Divider(),
                Text(
                  'Appearance',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('Row height ×${_rowScale.toStringAsFixed(2)}'),
                Slider(
                  value: _rowScale,
                  min: 0.7,
                  max: 2.0,
                  divisions: 13,
                  label: _rowScale.toStringAsFixed(2),
                  onChanged: (v) => setSheet(() => _rowScale = v),
                ),
                Text('Font size ×${_fontScaleFactor.toStringAsFixed(2)}'),
                Slider(
                  value: _fontScaleFactor,
                  min: 0.7,
                  max: 2.0,
                  divisions: 13,
                  label: _fontScaleFactor.toStringAsFixed(2),
                  onChanged: (v) => setSheet(() => _fontScaleFactor = v),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // keyboard navigation
  // ------------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final mgr = context.read<ClipboardManagerService>();
    final items = _visible(mgr);
    if (items.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      setState(
        () => _keyboardIndex = (_keyboardIndex + 1).clamp(0, items.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      setState(
        () => _keyboardIndex = (_keyboardIndex - 1).clamp(0, items.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      setState(
        () => _keyboardIndex = (_keyboardIndex + 10).clamp(0, items.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      setState(
        () => _keyboardIndex = (_keyboardIndex - 10).clamp(0, items.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final idx = _keyboardIndex.clamp(0, items.length - 1);
      _copyItem(items[idx], mgr);
      if (widget.popupMode && mounted) Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final idx = _keyboardIndex.clamp(0, items.length - 1);
      mgr.remove(items[idx].id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP &&
        HardwareKeyboard.instance.isControlPressed) {
      final idx = _keyboardIndex.clamp(0, items.length - 1);
      mgr.togglePin(items[idx].id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && widget.popupMode) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------
  // build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ClipboardManagerService>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final visible = _visible(mgr);
    final allTags = <String>{for (final i in mgr.items) ...i.tags}.toList()
      ..sort();

    return Focus(
      focusNode: _listFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          // ---- toolbar
          Padding(
            padding: EdgeInsets.all(widget.popupMode ? 8 : 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) => _onMenu(mgr, v),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear unpinned'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'shot_region_ocr',
                          child: Text('Screenshot region → OCR → clipboard'),
                        ),
                        const PopupMenuItem(
                          value: 'shot_region',
                          child: Text('Screenshot region → clipboard'),
                        ),
                        const PopupMenuItem(
                          value: 'shot_last_region',
                          child: Text('Repeat last region'),
                        ),
                        for (var m = 0; m < 3; m++)
                          PopupMenuItem(
                            value: 'shot_monitor_$m',
                            child: Text(
                              'Screenshot monitor ${m + 1} → clipboard',
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'shot_full_ocr',
                          child: Text(
                            'Screenshot fullscreen → OCR → clipboard',
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Text('Settings…'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in _TypeFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              switch (t) {
                                _TypeFilter.all => 'All',
                                _TypeFilter.text => 'Text',
                                _TypeFilter.image => 'Images',
                              },
                              style: TextStyle(
                                fontSize: fs(context, 11) * _fontScaleFactor,
                              ),
                            ),
                            selected: _typeFilter == t,
                            onSelected: (_) => setState(() => _typeFilter = t),
                          ),
                        ),
                      for (final d in _DateFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              switch (d) {
                                _DateFilter.any => 'Any date',
                                _DateFilter.today => 'Today',
                                _DateFilter.week => '7 days',
                                _DateFilter.month => 'This month',
                              },
                              style: TextStyle(
                                fontSize: fs(context, 11) * _fontScaleFactor,
                              ),
                            ),
                            selected: _dateFilter == d,
                            onSelected: (_) => setState(() => _dateFilter = d),
                          ),
                        ),
                      ChoiceChip(
                        label: Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: fs(context, 11) * _fontScaleFactor,
                          ),
                        ),
                        selected: _pinnedOnly,
                        onSelected: (v) => setState(() => _pinnedOnly = v),
                      ),
                      if (allTags.isNotEmpty) const VerticalDivider(width: 12),
                      for (final t in allTags)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              '#$t',
                              style: TextStyle(
                                fontSize: fs(context, 11) * _fontScaleFactor,
                              ),
                            ),
                            selected: _tagFilter == t,
                            onSelected: (v) =>
                                setState(() => _tagFilter = v ? t : ''),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('${_selected.length} selected'),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: const Text('Copy all'),
                    onPressed: () async {
                      for (final id in _selected) {
                        final idx = mgr.items.indexWhere((i) => i.id == id);
                        if (idx >= 0) {
                          await _copyItem(mgr.items[idx], mgr);
                        }
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    onPressed: () => _removeSelected(mgr),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('Deselect'),
                  ),
                ],
              ),
            ),
          // ---- list
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'Clipboard is empty.\nCopy something — it lands here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: visible.length,
                    itemExtent: (widget.popupMode ? 48 : 60) * _rowScale,
                    itemBuilder: (context, i) {
                      final item = visible[i];
                      final isKbFocus = i == _keyboardIndex;
                      final isSelected = _selected.contains(item.id);
                      return _buildRow(
                        context,
                        theme,
                        l10n,
                        mgr,
                        item,
                        isKbFocus: isKbFocus,
                        isSelected: isSelected,
                      );
                    },
                  ),
          ),
          // ---- status bar
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${visible.length}/${mgr.items.length} items'
                    '${_selected.isNotEmpty ? ' · ${_selected.length} selected' : ''}',
                    style: TextStyle(
                      fontSize: fs(context, 11) * _fontScaleFactor,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '↑↓ navigate · Enter copy · Del remove · Ctrl+P pin',
                    style: TextStyle(
                      fontSize: fs(context, 10) * _fontScaleFactor,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
    ClipboardManagerService mgr,
    ClipboardItem item, {
    required bool isKbFocus,
    required bool isSelected,
  }) {
    final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    final hh =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final rowFont = fs(context, 12.5) * _fontScaleFactor;

    return InkWell(
      onTap: () => _copyItem(item, mgr),
      onLongPress: () => setState(() {
        isSelected ? _selected.remove(item.id) : _selected.add(item.id);
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isKbFocus
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : isSelected
              ? theme.colorScheme.secondary.withValues(alpha: 0.14)
              : null,
          border: Border(
            left: BorderSide(
              color: item.pinned
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.popupMode ? 8 : 12,
          vertical: 4,
        ),
        child: Row(
          children: [
            if (item.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(item.imagePath!),
                  width: 36 * _rowScale,
                  height: 36 * _rowScale,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                ),
              )
            else
              Icon(
                Icons.notes_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preview(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: rowFont),
                  ),
                  if (item.tags.isNotEmpty)
                    Text(
                      item.tags.map((t) => '#$t').join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fs(context, 10) * _fontScaleFactor,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              hh,
              style: TextStyle(
                fontSize: fs(context, 10) * _fontScaleFactor,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            if (item.pinned)
              Icon(Icons.push_pin, size: 13, color: theme.colorScheme.primary),
            _rowMenu(theme, mgr, item),
          ],
        ),
      ),
    );
  }

  Widget _rowMenu(
    ThemeData theme,
    ClipboardManagerService mgr,
    ClipboardItem item,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      padding: EdgeInsets.zero,
      onSelected: (v) => _onRowMenu(mgr, item, v),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        if (item.isText)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'tags', child: Text('Tags…')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'pin',
          child: Text(item.pinned ? 'Unpin' : 'Pin to top'),
        ),
        const PopupMenuItem(value: 'top', child: Text('Move to top')),
        const PopupMenuItem(value: 'up', child: Text('Move up')),
        const PopupMenuItem(value: 'down', child: Text('Move down')),
        const PopupMenuItem(value: 'bottom', child: Text('Move to bottom')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remove', child: Text('Remove')),
      ],
    );
  }

  void _onRowMenu(ClipboardManagerService mgr, ClipboardItem item, String v) {
    switch (v) {
      case 'copy':
        _copyItem(item, mgr);
      case 'edit':
        _editDialog(item, mgr);
      case 'tags':
        _tagsDialog(item, mgr);
      case 'pin':
        mgr.togglePin(item.id);
      case 'top':
        mgr.move(item.id, ClipboardMoveDir.top);
      case 'up':
        mgr.move(item.id, ClipboardMoveDir.up);
      case 'down':
        mgr.move(item.id, ClipboardMoveDir.down);
      case 'bottom':
        mgr.move(item.id, ClipboardMoveDir.bottom);
      case 'remove':
        mgr.remove(item.id);
    }
  }

  void _onMenu(ClipboardManagerService mgr, String v) {
    if (v == 'clear') {
      mgr.clearUnpinned();
    } else if (v == 'settings') {
      _showSettings(mgr);
    } else if (v.startsWith('shot_monitor_')) {
      final m = int.tryParse(v.substring('shot_monitor_'.length)) ?? 0;
      _screenshotAction(
        ScreenshotKind.monitor,
        monitor: m,
        imageToClipboard: true,
      );
    } else {
      switch (v) {
        case 'shot_region_ocr':
          _screenshotAction(ScreenshotKind.region, ocrToClipboard: true);
        case 'shot_region':
          _screenshotAction(ScreenshotKind.region, imageToClipboard: true);
        case 'shot_last_region':
          _screenshotAction(
            ScreenshotKind.previousRegion,
            ocrToClipboard: true,
          );
        case 'shot_full_ocr':
          _screenshotAction(ScreenshotKind.fullscreen, ocrToClipboard: true);
      }
    }
  }
}

/// Image clipboard writer isolated so tests can stub it. On desktop the
/// super_clipboard / xclip route is wired by the host; text entries go
/// through [ClipboardSetText].
class ClipboardManagerImageCopy {
  static Future<void> Function(Uint8List bytes)? override;

  static Future<void> copy(Uint8List bytes) async {
    final o = override;
    if (o != null) {
      await o(bytes);
      return;
    }
    // best-effort desktop image copy through the CLI tools the
    // screenshot service already depends on
    try {
      final dir = await Directory.systemTemp.createTemp('clipimg');
      final f = File('${dir.path}/img.png');
      await f.writeAsBytes(bytes);
      if (Platform.isLinux) {
        final wl = await Process.run('wl-copy', [], runInShell: false);
        final xclip = await Process.run('xclip', []);
        // prefer wayland tool when it exists; run via args
        final hasWl = await _exists('wl-copy');
        final hasXclip = await _exists('xclip');
        if (hasWl) {
          await Process.run('sh', ['-c', 'wl-copy < "${f.path}"']);
        } else if (hasXclip) {
          await Process.run('sh', [
            '-c',
            'xclip -selection clipboard -t image/png -i "${f.path}"',
          ]);
        } else {
          wl.exitCode;
          xclip.exitCode;
        }
      } else if (Platform.isMacOS) {
        await Process.run('sh', [
          '-c',
          'osascript -e "set the clipboard to (read (POSIX file \\"${f.path}\\") as «class PNGf»)"',
        ]);
      } else if (Platform.isWindows) {
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '[Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile("${f.path.replaceAll('\\', '/')}"))',
        ]);
      }
    } catch (_) {
      // image clipboard not available
    }
  }

  static Future<bool> _exists(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
