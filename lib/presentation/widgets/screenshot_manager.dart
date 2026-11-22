import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/image_clipboard_service.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/app_context_menu.dart';
import 'package:lang/presentation/widgets/screenshot_ref_image.dart';
import 'package:lang/presentation/widgets/submit_text_field.dart';
import 'package:lang/utils/font_scale.dart';

/// How the manager filters the stored screenshots.
enum ScreenshotFilter {
  /// Everything, hidden items included.
  all,

  /// Only the items the user has hidden.
  hidden,

  /// Only the items with recognized text.
  withText,

  /// Only the items without recognized text.
  withoutText,
}

/// How the manager orders the stored screenshots.
enum ScreenshotSort {
  /// Newest first (the capture order).
  newest,

  /// Oldest first.
  oldest,

  /// By name, A to Z.
  name,
}

/// The screenshot manager: the stored screenshots with filtering,
/// sorting and the per-item actions (copy path, properties, rename,
/// edit, crop, hide, delete).
class ScreenshotManager extends StatefulWidget {
  const ScreenshotManager({super.key, this.service});

  /// Override for tests; defaults to the shared instance.
  final ScreenshotService? service;

  @override
  State<ScreenshotManager> createState() => _ScreenshotManagerState();
}

class _ScreenshotManagerState extends State<ScreenshotManager> {
  ScreenshotFilter _filter = ScreenshotFilter.all;
  ScreenshotSort _sort = ScreenshotSort.newest;
  final TextEditingController _searchCtrl = TextEditingController();

  ScreenshotService get _service =>
      widget.service ?? ScreenshotService.instance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// The items the filter and the search box select.
  List<ScreenshotItem> _visible(List<ScreenshotItem> items) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = items.where((item) {
      switch (_filter) {
        case ScreenshotFilter.all:
          if (item.hidden) return false;
        case ScreenshotFilter.hidden:
          if (!item.hidden) return false;
        case ScreenshotFilter.withText:
          if (item.hidden) return false;
          if ((item.ocrText ?? '').trim().isEmpty) return false;
        case ScreenshotFilter.withoutText:
          if (item.hidden) return false;
          if ((item.ocrText ?? '').trim().isNotEmpty) return false;
      }
      if (query.isEmpty) return true;
      return item.displayName.toLowerCase().contains(query) ||
          (item.ocrText ?? '').toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case ScreenshotSort.newest:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      case ScreenshotSort.oldest:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      case ScreenshotSort.name:
        filtered.sort(
          (a, b) =>
              a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final all = _service.items;
        final items = _visible(all);
        return Column(
          children: [
            Flexible(child: _buildToolbar(l10n)),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty
                            ? l10n.noScreenshots
                            : l10n.screenshotNoMatches,
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildRow(l10n, theme, items[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(AppLocalizations l10n) {
    return Padding(
      // the vertical padding shrinks in a short slot, so the toolbar
      // fits the space it is given
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              // the field grows to its usual height but shrinks when the
              // manager is hosted in a short slot, so the toolbar never
              // overflows the space it is given
              constraints: const BoxConstraints(maxHeight: 36),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: l10n.screenshotSearch,
                  prefixIcon: const Icon(Icons.search, size: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<ScreenshotFilter>(
            icon: const Icon(Icons.filter_list, size: 18),
            tooltip: l10n.screenshotFilter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (context) => [
              for (final f in ScreenshotFilter.values)
                PopupMenuItem(
                  value: f,
                  child: Text(_filterLabel(l10n, f)),
                ),
            ],
          ),
          PopupMenuButton<ScreenshotSort>(
            icon: const Icon(Icons.sort, size: 18),
            tooltip: l10n.screenshotSort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final s in ScreenshotSort.values)
                PopupMenuItem(value: s, child: Text(_sortLabel(l10n, s))),
            ],
          ),
        ],
      ),
    );
  }

  String _filterLabel(AppLocalizations l10n, ScreenshotFilter filter) =>
      switch (filter) {
        ScreenshotFilter.all => l10n.screenshotFilterAll,
        ScreenshotFilter.hidden => l10n.screenshotFilterHidden,
        ScreenshotFilter.withText => l10n.screenshotFilterWithText,
        ScreenshotFilter.withoutText => l10n.screenshotFilterWithoutText,
      };

  String _sortLabel(AppLocalizations l10n, ScreenshotSort sort) =>
      switch (sort) {
        ScreenshotSort.newest => l10n.screenshotSortNewest,
        ScreenshotSort.oldest => l10n.screenshotSortOldest,
        ScreenshotSort.name => l10n.screenshotSortName,
      };

  Widget _buildRow(
    AppLocalizations l10n,
    ThemeData theme,
    ScreenshotItem item,
  ) {
    final relative = _service.relativePath(item);
    return ListTile(
      dense: true,
      leading: ScreenshotRefImage(
        ref: item.path,
        fit: BoxFit.cover,
        cacheWidth: 96,
        size: 40,
      ),
      title: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fs(context, 13),
          color: item.hidden ? theme.colorScheme.outline : null,
        ),
      ),
      subtitle: Text(
        [
          DateFormat.yMd().add_Hm().format(item.time),
          ?relative,
          if ((item.ocrText ?? '').trim().isNotEmpty) l10n.screenshotHasText,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fs(context, 11)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.hidden)
            Icon(
              Icons.visibility_off,
              size: 15,
              color: theme.colorScheme.outline,
            ),
          _rowMenu(l10n, item),
        ],
      ),
      onTap: () => _showItem(l10n, item),
    );
  }

  Widget _rowMenu(AppLocalizations l10n, ScreenshotItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 16),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        // The menu closes by marking this button dirty and rebuilding it
        // in the next frame. An action that removes the row from the
        // list would deactivate the still-dirty button, which the
        // framework refuses to do. Running the action after that frame
        // keeps the button's own rebuild and the list rebuild apart.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _onAction(l10n, item, v);
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'copy_path', child: Text('Copy path')),
        const PopupMenuItem(
          value: 'copy_relative_path',
          child: Text('Copy relative path'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'properties', child: Text('Properties')),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'edit', child: Text('Edit text')),
        const PopupMenuItem(value: 'crop', child: Text('Crop')),
        PopupMenuItem(
          value: 'hide',
          child: Text(item.hidden ? 'Unhide' : 'Hide'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _onAction(
    AppLocalizations l10n,
    ScreenshotItem item,
    String action,
  ) async {
    switch (action) {
      case 'copy_path':
        final path = await _service.absolutePath(item);
        if (path != null) await _copyText(l10n, path);
      case 'copy_relative_path':
        final relative = _service.relativePath(item);
        if (relative != null) {
          await _copyText(l10n, relative);
        } else {
          _notify(l10n, l10n.screenshotNoRelativePath);
        }
      case 'properties':
        await _showProperties(l10n, item);
      case 'rename':
        await _rename(l10n, item);
      case 'edit':
        await _editText(l10n, item);
      case 'crop':
        await _crop(l10n, item);
      case 'hide':
        _service.setHidden(item.id, !item.hidden);
      case 'delete':
        _service.remove(item.id);
    }
  }

  Future<void> _copyText(AppLocalizations l10n, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _notify(l10n, l10n.screenshotCopied);
  }

  void _notify(AppLocalizations l10n, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showProperties(
    AppLocalizations l10n,
    ScreenshotItem item,
  ) async {
    final path = await _service.absolutePath(item);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.screenshotProperties),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _propertyRow(l10n, l10n.screenshotPropertyName, item.displayName),
              _propertyRow(
                l10n,
                l10n.screenshotPropertyKind,
                item.kind.name,
              ),
              _propertyRow(
                l10n,
                l10n.screenshotPropertyTaken,
                DateFormat.yMd().add_jms().format(item.time),
              ),
              _propertyRow(l10n, l10n.screenshotPropertyPath, path ?? item.path),
              _propertyRow(
                l10n,
                l10n.screenshotPropertySize,
                _fileSize(path),
              ),
              _propertyRow(
                l10n,
                l10n.screenshotPropertyText,
                (item.ocrText ?? '').isEmpty ? '—' : item.ocrText!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _propertyRow(AppLocalizations l10n, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fs(context, 11),
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          SelectableText(value, style: TextStyle(fontSize: fs(context, 12))),
        ],
      ),
    );
  }

  String _fileSize(String? path) {
    if (path == null) return '—';
    try {
      final file = File(path);
      if (!file.existsSync()) return '—';
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _rename(AppLocalizations l10n, ScreenshotItem item) async {
    final fieldKey = GlobalKey<OwnedTextFieldState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.screenshotRename),
        content: OwnedTextField(
          key: fieldKey,
          initialText: item.displayName,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.screenshotPropertyName,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, fieldKey.currentState!.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) _service.rename(item.id, name);
  }

  Future<void> _editText(AppLocalizations l10n, ScreenshotItem item) async {
    final fieldKey = GlobalKey<OwnedTextFieldState>();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.screenshotEditText),
        content: OwnedTextField(
          key: fieldKey,
          initialText: item.ocrText ?? '',
          autofocus: true,
          maxLines: 8,
          useAppContextMenu: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, fieldKey.currentState!.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text != null) _service.editOcrText(item.id, text);
  }

  Future<void> _crop(AppLocalizations l10n, ScreenshotItem item) async {
    final rect = await showDialog<ScreenshotCropRect>(
      context: context,
      builder: (ctx) => _CropDialog(
        item: item,
        l10n: l10n,
        service: _service,
      ),
    );
    if (rect == null) return;
    final cropped = await _service.crop(item, rect);
    if (!mounted) return;
    _notify(
      l10n,
      cropped == null ? l10n.screenshotCropFailed : l10n.screenshotCropped,
    );
  }

  Future<void> _showItem(AppLocalizations l10n, ScreenshotItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => _ItemSheet(
          item: item,
          scrollController: controller,
          onCopyImage: () async {
            final bytes = await AppStorage.readMedia(item.path);
            if (bytes == null) return;
            final ok = await ImageClipboardService.copyPng(bytes);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? l10n.screenshotCopied : l10n.copyFailed),
                ),
              );
            }
          },
          onDelete: () {
            _service.remove(item.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

/// Full detail sheet for one screenshot: preview, OCR text, copy
/// actions, delete.
class _ItemSheet extends StatelessWidget {
  final ScreenshotItem item;
  final ScrollController scrollController;
  final VoidCallback onCopyImage;
  final VoidCallback onDelete;

  const _ItemSheet({
    required this.item,
    required this.scrollController,
    required this.onCopyImage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ScreenshotRefImage(ref: item.path, fit: BoxFit.contain),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: TextStyle(
                    fontSize: fs(context, 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat.yMd().add_jms().format(item.time),
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if ((item.ocrText ?? '').isNotEmpty) ...[
                  SelectableText(
                    contextMenuBuilder: AppContextMenu.editable,
                    item.ocrText!,
                    style: TextStyle(fontSize: fs(context, 13)),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onCopyImage,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy image'),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the crop rectangle by dragging over the image preview.
/// The selection is reported in image pixels.
class _CropDialog extends StatefulWidget {
  final ScreenshotItem item;
  final AppLocalizations l10n;
  final ScreenshotService service;

  const _CropDialog({
    required this.item,
    required this.l10n,
    required this.service,
  });

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  /// The image pixel size, loaded once the dialog opens.
  ({int width, int height})? _size;

  /// The current drag selection in image pixels.
  Rect? _selection;

  /// The drag start in image pixels.
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final size = await widget.service.imageSize(widget.item);
    if (!mounted) return;
    setState(() => _size = size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final size = _size;
    return AlertDialog(
      title: Text(l10n.screenshotCrop),
      content: SizedBox(
        width: 480,
        height: 360,
        child: size == null
            ? Center(child: CircularProgressIndicator())
            : _buildSelector(size),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selection == null
              ? null
              : () => Navigator.pop(
                  context,
                  ScreenshotCropRect(
                    left: _selection!.left.round(),
                    top: _selection!.top.round(),
                    width: _selection!.width.round(),
                    height: _selection!.height.round(),
                  ),
                ),
          child: const Text('Crop'),
        ),
      ],
    );
  }

  Widget _buildSelector(({int width, int height}) size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // fit the image inside the available box, keeping its aspect
        final scale = (constraints.maxWidth / size.width).clamp(
          0.0,
          constraints.maxHeight / size.height,
        );
        final displayWidth = size.width * scale;
        final displayHeight = size.height * scale;
        final offset = Offset(
          (constraints.maxWidth - displayWidth) / 2,
          (constraints.maxHeight - displayHeight) / 2,
        );

        // the drag is expressed in image pixels, so it is clamped to
        // the image box before it becomes a selection
        Offset toImagePixels(Offset local) {
          final x = (local.dx - offset.dx) / scale;
          final y = (local.dy - offset.dy) / scale;
          return Offset(
            x.clamp(0.0, size.width.toDouble()),
            y.clamp(0.0, size.height.toDouble()),
          );
        }

        return GestureDetector(
          onPanStart: (details) {
            final local = toImagePixels(details.localPosition);
            setState(() {
              _dragStart = local;
              _selection = Rect.fromPoints(local, local);
            });
          },
          onPanUpdate: (details) {
            final start = _dragStart;
            if (start == null) return;
            final local = toImagePixels(details.localPosition);
            setState(() => _selection = Rect.fromPoints(start, local));
          },
          onPanEnd: (_) {
            final selection = _selection;
            if (selection == null) return;
            // an empty drag means "no selection"
            if (selection.width < 2 || selection.height < 2) {
              setState(() => _selection = null);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ScreenshotRefImage(
                    ref: widget.item.path,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  width: displayWidth,
                  height: displayHeight,
                  child: CustomPaint(
                    painter: _CropPainter(
                      selection: _selection,
                      scale: scale,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Draws the dimmed area outside the crop selection plus its border.
class _CropPainter extends CustomPainter {
  final Rect? selection;
  final double scale;
  final Color color;

  _CropPainter({
    required this.selection,
    required this.scale,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selection = this.selection;
    if (selection == null) return;

    final rect = Rect.fromLTRB(
      selection.left * scale,
      selection.top * scale,
      selection.right * scale,
      selection.bottom * scale,
    );

    // dim everything outside the selection
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      border,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.selection != selection ||
      oldDelegate.scale != scale ||
      oldDelegate.color != color;
}
