import 'dart:io' show Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

/// How a page gets opened on this platform.
enum BrowserOpenMode {
  /// Full in-app webview, with address bar and navigation controls.
  embedded,

  /// A separate native webview window (WebView2 / WKWebView).
  nativeWindow,

  /// Handed off to the system browser.
  external,
}

/// Pick the strongest browser this platform can offer.
///
/// Linux has no webkit2gtk binding, so it is the only target that falls back
/// to the system browser; everything else gets an embedded webview. Kept
/// public and platform-parameterised so the policy is unit testable without
/// a device.
BrowserOpenMode browserOpenModeFor({
  required bool isLinux,
  required bool isMobile,
}) {
  if (isLinux) return BrowserOpenMode.external;
  if (isMobile) return BrowserOpenMode.embedded;
  return BrowserOpenMode.nativeWindow;
}

/// Web browser tab.
///
/// Android and iOS get an embedded webview with an address bar and
/// navigation controls. Windows and macOS open a native webview window
/// (WebView2 / WKWebView, both part of the OS). Linux has no webkit2gtk
/// binding, so the page is handed to the system browser. Keeps a recents
/// list of visited URLs.
class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  final _urlCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  InAppWebViewController? _webview;
  List<String> _recents = [];
  bool _opening = false;
  String? _error;

  /// The page currently displayed in the embedded webview, if any.
  String? _embeddedUrl;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

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
    _addressCtrl.dispose();
    super.dispose();
  }

  BrowserOpenMode get _mode => browserOpenModeFor(
    isLinux: Platform.isLinux,
    isMobile: Platform.isAndroid || Platform.isIOS,
  );

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
      switch (_mode) {
        case BrowserOpenMode.embedded:
          // same tab: swap the launcher UI for the webview itself
          setState(() {
            _embeddedUrl = url;
            _addressCtrl.text = url;
            _progress = 0;
          });
          await _remember(url);
          return;
        case BrowserOpenMode.nativeWindow:
          if (!await WebviewWindow.isWebviewAvailable()) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            await _remember(url);
            return;
          }
          final webview = await WebviewWindow.create(
            configuration: const CreateConfiguration(
              title: 'Lang Browser',
              titleBarHeight: 36,
            ),
          );
          webview.launch(url);
          await _remember(url);
          return;
        case BrowserOpenMode.external:
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          await _remember(url);
          return;
      }
    } catch (e) {
      // no system browser, or the webview runtime failed to come up
      if (mounted) setState(() => _error = '${l10n?.browserNoRuntime}: $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _closeEmbedded() {
    setState(() {
      _embeddedUrl = null;
      _progress = 0;
      _canGoBack = false;
      _canGoForward = false;
    });
  }

  Future<void> _syncHistoryState() async {
    final controller = _webview;
    if (controller == null || !mounted) return;
    final canBack = await controller.canGoBack();
    final canForward = await controller.canGoForward();
    if (!mounted) return;
    if (canBack == _canGoBack && canForward == _canGoForward) return;
    setState(() {
      _canGoBack = canBack;
      _canGoForward = canForward;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // embedded mode replaces the launcher with the page itself
    if (_embeddedUrl != null) {
      return _buildEmbedded(theme, l10n);
    }
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
                          'Open a page and it opens in your browser.\n'
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

  /// Full-screen in-app browser: address bar, back/forward/reload, page.
  Widget _buildEmbedded(ThemeData theme, AppLocalizations? l10n) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n?.browserBack ?? 'Back',
              onPressed: _canGoBack
                  ? () async {
                      await _webview?.goBack();
                      _syncHistoryState();
                    }
                  : null,
            ),
            Expanded(
              child: TextField(
                controller: _addressCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.language, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (raw) {
                  final url = normalizeBrowserUrl(raw);
                  if (url == null) return;
                  setState(() {
                    _embeddedUrl = url;
                    _addressCtrl.text = url;
                  });
                  _webview?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                  _remember(url);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n?.browserReload ?? 'Reload',
              onPressed: () => _webview?.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: l10n?.browserForward ?? 'Forward',
              onPressed: _canGoForward
                  ? () async {
                      await _webview?.goForward();
                      _syncHistoryState();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n?.browserClose ?? 'Close',
              onPressed: _closeEmbedded,
            ),
          ],
        ),
        if (_progress > 0 && _progress < 100)
          LinearProgressIndicator(value: _progress / 100),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_embeddedUrl!)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              // language learners read sites with a dark reader installed
              // or a mobile UA, so keep the stock UA and let sites decide
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
            ),
            onWebViewCreated: (controller) => _webview = controller,
            onProgressChanged: (controller, progress) {
              if (!mounted) return;
              setState(() => _progress = progress);
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
              setState(() {
                _embeddedUrl = url.toString();
                _addressCtrl.text = _embeddedUrl!;
                _progress = 0;
              });
            },
            onLoadStop: (controller, url) {
              if (!mounted) return;
              setState(() {
                _embeddedUrl = url.toString();
                _addressCtrl.text = _embeddedUrl!;
                _progress = 100;
              });
              _remember(_embeddedUrl!);
              _syncHistoryState();
            },
            onReceivedError: (controller, request, error) {
              // only surface a failure for the main document, not for an
              // image or a failed third-party script on the page
              if (!mounted) return;
              if (request.isForMainFrame ?? true) {
                setState(() => _error = error.description);
              }
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
