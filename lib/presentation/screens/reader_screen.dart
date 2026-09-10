import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';
import 'package:lang/presentation/screens/screenshot_tab.dart';
import 'package:lang/presentation/widgets/clipboard_settings.dart';
import 'package:lang/utils/font_scale.dart';

/// Reader hub: documents (pdf/epub/txt/cbz/manga), screenshots
/// (capture + OCR + album) and clipboard (monitor settings, live
/// history) in one screen with three tabs.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    HistoryService.instance.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.readerTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book, size: 18),
              text: l10n.readerTabDocuments,
            ),
            Tab(
              icon: const Icon(Icons.screenshot_monitor, size: 18),
              text: l10n.readerTabScreenshots,
            ),
            Tab(
              icon: const Icon(Icons.content_paste, size: 18),
              text: l10n.readerTabClipboard,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DocumentReaderScreen(),
          ScreenshotTab(),
          _ClipboardTab(),
        ],
      ),
    );
  }
}

/// Clipboard: live clipboard history (from the monitor) plus the
/// monitor settings themselves.
class _ClipboardTab extends StatefulWidget {
  const _ClipboardTab();

  @override
  State<_ClipboardTab> createState() => _ClipboardTabState();
}

class _ClipboardTabState extends State<_ClipboardTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final monitoring =
        appState.clipboardAutoSearchMode != ClipboardAutoSearchMode.off;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          l10n.clipboardLiveHistory,
          style: TextStyle(
            fontSize: fs(context, 14),
            fontWeight: FontWeight.w600,
          ),
        ),
        AnimatedBuilder(
          animation: HistoryService.instance,
          builder: (context, _) {
            if (!monitoring) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(l10n.clipboardMonitoringOff)),
              );
            }
            final items = HistoryService.instance.items
                .where((i) => i.category == HistoryCategory.clipboard)
                .toList();
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.noActivityYet,
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: items.map((item) {
                return ListTile(
                  dense: true,
                  leading: item.hasImage
                      ? const Icon(Icons.image)
                      : const Icon(Icons.text_fields),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fs(context, 13)),
                  ),
                  subtitle:
                      item.subtitle != null &&
                          item.subtitle!.length > item.title.length
                      ? Text(
                          item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: fs(context, 11)),
                        )
                      : null,
                );
              }).toList(),
            );
          },
        ),
        const Divider(),
        const ClipboardSettings(),
      ],
    );
  }
}
