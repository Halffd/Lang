import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Screenshot tab inside the OCR screen: capture buttons (full
/// screen, monitor, window, region, previous region, auto),
/// per-capture options (auto OCR, copy text/image), and a
/// history/album view of taken screenshots.
class ScreenshotTab extends StatefulWidget {
  const ScreenshotTab({super.key, this.service});

  /// Override for tests; defaults to the shared instance.
  final ScreenshotService? service;

  @override
  State<ScreenshotTab> createState() => _ScreenshotTabState();
}

class _ScreenshotTabState extends State<ScreenshotTab> {
  ScreenshotService get _service =>
      widget.service ?? ScreenshotService.instance;
  bool _isCapturing = false;
  int _monitor = 0;
  int _monitorCount = 1;

  @override
  void initState() {
    super.initState();
    _service.load();
    _service.monitorCount().then((n) {
      if (mounted) setState(() => _monitorCount = n);
    });
  }

  Future<void> _capture(ScreenshotKind kind) async {
    if (_isCapturing) return;
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isCapturing = true);

    final item = await _service.captureWithPipeline(
      kind,
      monitor: _monitor,
      autoOcr: appState.screenshotAutoOcr,
      copyOcrText: appState.screenshotCopyOcrText,
      copyImage: appState.screenshotCopyImage,
      ocrRunner: _runOcr,
      copyImageRunner: _copyImageToClipboard,
      copyTextRunner: (text) async {
        await Clipboard.setData(ClipboardData(text: text));
      },
    );

    if (!mounted) return;
    setState(() => _isCapturing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null ? l10n.screenshotFailed : l10n.screenshotCaptured,
        ),
      ),
    );
  }

  Future<void> _copyImageToClipboard(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final item = DataWriterItem(suggestedName: 'screenshot.png');
      item.add(Formats.png(bytes));
      await ClipboardWriter.instance.write([item]);
    } catch (_) {
      // clipboard write is best-effort
    }
  }

  Future<String?> _runOcr(String path) async {
    final appState = context.read<AppState>();
    var engine = OcrService.engineFromName(appState.ocrEngine);
    // ai engine needs the AI provider which lives in the search
    // screen context; use mlKit for screenshot auto-OCR instead
    if (engine == OcrEngine.ai) engine = OcrEngine.mlKit;
    final ocrService = OcrService();
    try {
      if (appState.ocrApiEndpoint.isNotEmpty) {
        ocrService.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await ocrService.recognizeFromFile(
        path,
        engine: engine,
        language: appState.learningLanguage,
        apiKey: appState.ocrApiKey,
      );
      return result.isSuccess ? result.text : null;
    } catch (_) {
      return null;
    } finally {
      ocrService.dispose();
    }
  }

  Future<void> _showItem(ScreenshotItem item) async {
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
          onCopyText: item.ocrText != null
              ? () async {
                  await Clipboard.setData(ClipboardData(text: item.ocrText!));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              : null,
          onCopyImage: () async {
            await _copyImageToClipboard(item.path);
            if (context.mounted) Navigator.pop(context);
          },
          onDelete: () {
            _service.remove(item.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);

    return Column(
      children: [
        // capture buttons row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _captureButton(
              icon: Icons.monitor,
              label: l10n.captureFullscreen,
              onPressed: () => _capture(ScreenshotKind.fullscreen),
            ),
            if (_monitorCount > 1)
              _captureButton(
                icon: Icons.desktop_windows,
                label: l10n.captureMonitor,
                onPressed: () => _capture(ScreenshotKind.monitor),
              ),
            _captureButton(
              icon: Icons.window,
              label: l10n.captureWindow,
              onPressed: () => _capture(ScreenshotKind.window),
            ),
            _captureButton(
              icon: Icons.crop,
              label: l10n.captureRegion,
              onPressed: () => _capture(ScreenshotKind.region),
            ),
            _captureButton(
              icon: Icons.crop_din,
              label: l10n.capturePreviousRegion,
              onPressed: () => _capture(ScreenshotKind.previousRegion),
            ),
          ],
        ),
        if (_monitorCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButton<int>(
              value: _monitor.clamp(0, _monitorCount - 1),
              items: List.generate(_monitorCount, (i) {
                return DropdownMenuItem(value: i, child: Text('Monitor $i'));
              }),
              onChanged: (v) => setState(() => _monitor = v ?? 0),
            ),
          ),
        const SizedBox(height: 8),
        if (_isCapturing) const LinearProgressIndicator(),

        // hotkey legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.screenshotHotkeys,
            style: TextStyle(
              fontSize: fs(context, 10),
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // options
        SwitchListTile(
          dense: true,
          title: Text(
            l10n.autoOcr,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          value: appState.screenshotAutoOcr,
          onChanged: (v) => appState.setScreenshotAutoOcr(v),
        ),
        SwitchListTile(
          dense: true,
          title: Text(
            l10n.copyOcrText,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          value: appState.screenshotCopyOcrText,
          onChanged: (v) => appState.setScreenshotCopyOcrText(v),
        ),
        SwitchListTile(
          dense: true,
          title: Text(
            l10n.copyImage,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          value: appState.screenshotCopyImage,
          onChanged: (v) => appState.setScreenshotCopyImage(v),
        ),

        // auto screenshot interval
        ListTile(
          dense: true,
          title: Text(
            l10n.autoScreenshot,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          trailing: DropdownButton<int>(
            value: appState.screenshotAutoIntervalMin,
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.off)),
              DropdownMenuItem(value: 1, child: Text('1 min')),
              DropdownMenuItem(value: 5, child: Text('5 min')),
              DropdownMenuItem(value: 10, child: Text('10 min')),
              DropdownMenuItem(value: 30, child: Text('30 min')),
              DropdownMenuItem(value: 60, child: Text('60 min')),
            ],
            onChanged: (v) {
              if (v == null) return;
              appState.setScreenshotAutoIntervalMin(v);
              _restartAutoCapture();
            },
          ),
        ),

        const Divider(height: 1),

        // history + album
        Expanded(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final items = _service.items;
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    l10n.noScreenshots,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      color: theme.colorScheme.outline,
                    ),
                  ),
                );
              }
              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            tabAlignment: TabAlignment.start,
                            isScrollable: true,
                            tabs: [
                              Tab(
                                icon: Icon(Icons.history, size: 18),
                                text: l10n.screenshotHistory,
                              ),
                              Tab(
                                icon: Icon(Icons.photo_library, size: 18),
                                text: l10n.screenshotAlbum,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          tooltip: l10n.deleteAllScreenshots,
                          onPressed: () => _confirmClearAll(context),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // history: list with timestamp + kind + ocr text
                          _buildHistoryList(items),
                          // album: image grid
                          _buildAlbumGrid(items),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _captureButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isCapturing ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(fontSize: fs(context, 12))),
    );
  }

  Widget _buildHistoryList(List<ScreenshotItem> items) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final kindLabel = switch (item.kind) {
          ScreenshotKind.fullscreen => l10n.captureFullscreen,
          ScreenshotKind.monitor => l10n.captureMonitor,
          ScreenshotKind.window => l10n.captureWindow,
          ScreenshotKind.region => l10n.captureRegion,
          ScreenshotKind.previousRegion => l10n.capturePreviousRegion,
          ScreenshotKind.auto => l10n.autoScreenshot,
        };
        return ListTile(
          dense: true,
          leading: const Icon(Icons.image),
          title: Text(kindLabel, style: TextStyle(fontSize: fs(context, 13))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.Hms().format(item.time),
                style: TextStyle(fontSize: fs(context, 11)),
              ),
              if (item.ocrText != null && item.ocrText!.isNotEmpty)
                Text(
                  item.ocrText!.length > 80
                      ? '${item.ocrText!.substring(0, 80)}…'
                      : item.ocrText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: fs(context, 11)),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _service.remove(item.id),
          ),
          onTap: () => _showItem(item),
        );
      },
    );
  }

  Widget _buildAlbumGrid(List<ScreenshotItem> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => _showItem(item),
          child: Image.file(
            File(item.path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllScreenshots),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _service.clear();
  }

  void _restartAutoCapture() {
    final appState = context.read<AppState>();
    final interval = appState.screenshotAutoIntervalMin;
    if (interval <= 0) {
      _service.stopAutoCapture();
      return;
    }
    _service.startAutoCapture(
      intervalMinutes: interval,
      onCaptured: (item) async {
        // auto captures follow the same options as manual ones
        if (appState.screenshotAutoOcr) {
          final text = await _runOcr(item.path);
          if (text != null && text.trim().isNotEmpty) {
            _service.setOcrText(item.id, text.trim());
            if (appState.screenshotCopyOcrText) {
              await Clipboard.setData(ClipboardData(text: text.trim()));
            }
          }
        }
      },
    );
  }
}

/// Full detail sheet for one screenshot: preview, OCR text,
/// copy actions, delete.
class _ItemSheet extends StatelessWidget {
  final ScreenshotItem item;
  final ScrollController scrollController;
  final VoidCallback? onCopyText;
  final VoidCallback onCopyImage;
  final VoidCallback onDelete;

  const _ItemSheet({
    required this.item,
    required this.scrollController,
    required this.onCopyText,
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
            child: Image.file(
              File(item.path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMd().add_jms().format(item.time),
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.ocrText != null && item.ocrText!.isNotEmpty) ...[
                  SelectableText(
                    item.ocrText!,
                    style: TextStyle(fontSize: fs(context, 13)),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCopyText != null)
                      TextButton.icon(
                        onPressed: onCopyText,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy text'),
                      ),
                    TextButton.icon(
                      onPressed: onCopyImage,
                      icon: const Icon(Icons.image, size: 16),
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
