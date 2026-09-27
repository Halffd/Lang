import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web browser tab: opens URLs in a native webview window
/// (WebKitGTK on Linux, WebView2 on Windows — the embedded webview
/// packages have no desktop implementation, so a native window is the
/// supported path). Falls back to url_launcher when the runtime is
/// unavailable. Keeps a recents list of visited URLs.
class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  final _urlCtrl = TextEditingController();
  List<String> _recents = [];
  bool _opening = false;
  String? _error;

  static const _kRecentsKey = 'browser_recents';
  static const _quickLinks = [
    ('NHK Easy News', 'https://www3.nhk.or.jp/news/easy/'),
    ('Wikipedia', 'https://www.wikipedia.org/'),
    ('Tatoeba', 'https://tatoeba.org/'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _recents = p.getStringList(_kRecentsKey) ?? []);
  }

  Future<void> _remember(String url) async {
    final next = [url, ..._recents.where((r) => r != url)].take(20).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kRecentsKey, next);
    if (mounted) setState(() => _recents = next);
  }

  String? _normalizeUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      // bare query: treat as a search
      if (s.contains(' ') || !s.contains('.')) {
        s = 'https://www.wikipedia.org/wiki/Special:Search?search=${Uri.encodeComponent(s)}';
      } else {
        s = 'https://$s';
      }
    }
    final uri = Uri.tryParse(s);
    return uri?.toString();
  }

  Future<void> _open() async {
    final url = _normalizeUrl(_urlCtrl.text);
    if (url == null) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final available = await WebviewWindow.isWebviewAvailable();
      if (available) {
        final webview = await WebviewWindow.create(
          configuration: const CreateConfiguration(
            title: 'Lang Browser',
            titleBarHeight: 36,
          ),
        );
        webview.launch(url);
      } else {
        // fallback: external browser
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await _remember(url);
    } catch (e) {
      // webkit2gtk missing / runtime broken — fall back to url_launcher
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        await _remember(url);
      } catch (e2) {
        if (mounted) setState(() => _error = 'No browser available: $e2');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // URL bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    hintText: 'URL or search…',
                    prefixIcon: const Icon(Icons.language),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _open(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: const Text('Open'),
                onPressed: _opening ? null : _open,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          // quick links
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final (label, url) in _quickLinks)
                  ActionChip(
                    label: Text(label),
                    onPressed: () {
                      _urlCtrl.text = url;
                      _open();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_recents.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent', style: theme.textTheme.titleSmall),
            ),
          Expanded(
            child: _recents.isEmpty
                ? Center(
                    child: Text(
                      'Open a page — it opens in a native browser window.\n'
                      'URLs you visit show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _recents.length,
                    itemBuilder: (context, i) {
                      final url = _recents[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () async {
                            final next = [..._recents]..removeAt(i);
                            final p = await SharedPreferences.getInstance();
                            await p.setStringList(_kRecentsKey, next);
                            if (mounted) setState(() => _recents = next);
                          },
                        ),
                        onTap: () {
                          _urlCtrl.text = url;
                          _open();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
