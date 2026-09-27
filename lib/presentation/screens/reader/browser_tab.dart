import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resolves what the user typed in the address bar into a URL.
///
/// A bare query ("、暗算" or "Nihongo lesson 3") becomes a Wikipedia
/// search, anything that looks like a host gets an https scheme, and
/// input that is already a full URL is passed through untouched.
String? normalizeBrowserUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    final looksLikeHost = !s.contains(' ') && s.contains('.');
    s = looksLikeHost
        ? 'https://$s'
        : 'https://www.wikipedia.org/wiki/Special:Search'
              '?search=${Uri.encodeComponent(s)}';
  }
  return Uri.tryParse(s)?.toString();
}

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
  static const _maxRecents = 20;
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

  Future<void> _saveRecents(List<String> next) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kRecentsKey, next);
    if (mounted) setState(() => _recents = next);
  }

  Future<void> _remember(String url) => _saveRecents(
    [url, ..._recents.where((r) => r != url)].take(_maxRecents).toList(),
  );

  Future<void> _open() async {
    final url = normalizeBrowserUrl(_urlCtrl.text);
    if (url == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (await WebviewWindow.isWebviewAvailable()) {
        final webview = await WebviewWindow.create(
          configuration: const CreateConfiguration(
            title: 'Lang Browser',
            titleBarHeight: 36,
          ),
        );
        webview.launch(url);
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      await _remember(url);
    } catch (_) {
      // webview runtime missing or broken: fall back to the system browser
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        await _remember(url);
      } catch (e) {
        if (mounted) {
          setState(() => _error = '${l10n?.browserNoRuntime}: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    hintText: l10n?.browserUrlHint,
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
                label: Text(l10n?.browserOpen ?? 'Open'),
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
              child: Text(
                l10n?.browserRecents ?? 'Recent',
                style: theme.textTheme.titleSmall,
              ),
            ),
          Expanded(
            child: _recents.isEmpty
                ? Center(
                    child: Text(
                      l10n?.browserEmpty ??
                          'Open a page and it appears in a browser window.\n'
                              'Visited URLs show up here.',
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
                          onPressed: () {
                            _saveRecents([..._recents]..removeAt(i));
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
