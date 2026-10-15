import 'dart:convert';
import 'dart:io' show Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lang/core/services/scraper_service.dart';
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
/// Every desktop and mobile target gets an embedded webview:
/// flutter_inappwebview 6.2.0-beta.3 endorses flutter_inappwebview_linux
/// (webkit2gtk-4.1), so Linux is no longer the system-browser fallback.
/// [BrowserOpenMode.external] remains available as an explicit user
/// action (open-in-system-browser button). Kept public and
/// platform-parameterised so the policy is unit testable without a device.
BrowserOpenMode browserOpenModeFor({
  required bool isLinux,
  required bool isMobile,
}) {
  if (isMobile) return BrowserOpenMode.embedded;
  // Linux builds made without WPE WebKit (e.g. CI) ship a stub plugin:
  // the Dart platform implementation never registers, so the embedded
  // webview would throw at runtime. Fall back to the system browser.
  if (isLinux &&
      // no registered platform implementation => stub build without WPE
      InAppWebViewPlatform.instance == null) {
    return BrowserOpenMode.external;
  }
  return BrowserOpenMode.embedded;
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

  // ---- scraping (issue 3) ----
  final ScraperService _scraper = ScraperService();
  ScraperConfig _scraperConfig = ScraperConfig();
  List<MethodAvailability> _availability = const [];
  bool _scraping = false;

  /// Open scraped-page tabs; clicking a link inside a scraped page
  /// scrapes the target into a NEW tab here.
  final List<_ScrapeTab> _scrapeTabs = [];
  int _activeScrapeTab = -1;

  static const _kRecentsKey = 'browser_recents';
  static const _kScraperConfigKey = 'scraper_config';
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
    _loadScraperConfig();
    _probeAvailability();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScraperConfig() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kScraperConfigKey);
    if (!mounted) return;
    if (raw == null || raw.isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(
        const JsonDecoder().convert(raw) as Map,
      );
      setState(() => _scraperConfig = ScraperConfig.fromJson(json));
    } catch (_) {
      // corrupt config: keep defaults
    }
  }

  Future<void> _saveScraperConfig() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kScraperConfigKey, jsonEncode(_scraperConfig.toJson()));
  }

  Future<void> _probeAvailability() async {
    final list = await _scraper.probeAvailability();
    if (!mounted) return;
    setState(() => _availability = list);
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

  // ------------------------------------------------------------
  // scraping (issue 3)
  // ------------------------------------------------------------

  /// Scrape the address-bar URL into a new scrape tab.
  Future<void> _scrape() async {
    final url = normalizeBrowserUrl(_embeddedUrl ?? _urlCtrl.text);
    if (url == null) return;
    setState(() => _scraping = true);
    try {
      final result = await _scraper.scrape(url, _scraperConfig);
      if (!mounted) return;
      setState(() {
        _scrapeTabs.add(_ScrapeTab(url: url, result: result));
        _activeScrapeTab = _scrapeTabs.length - 1;
      });
    } finally {
      if (mounted) setState(() => _scraping = false);
    }
  }

  /// Scrape [url] into its own tab (link click inside a scraped page).
  Future<void> _scrapeIntoNewTab(String url) async {
    final base = _activeScrapeTab >= 0
        ? _scrapeTabs[_activeScrapeTab].url
        : (_embeddedUrl ?? _urlCtrl.text);
    final absolute = _absoluteUrl(base, url);
    if (absolute == null) return;
    final result = await _scraper.scrape(absolute, _scraperConfig);
    if (!mounted) return;
    setState(() {
      _scrapeTabs.add(_ScrapeTab(url: absolute, result: result));
      _activeScrapeTab = _scrapeTabs.length - 1;
    });
  }

  /// Resolve [href] against [base] (relative link support).
  static String? _absoluteUrl(String base, String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    try {
      return Uri.parse(base).resolve(trimmed).toString();
    } catch (_) {
      return null;
    }
  }

  void _closeScrapeTab(int index) {
    setState(() {
      _scrapeTabs.removeAt(index);
      if (_scrapeTabs.isEmpty) {
        _activeScrapeTab = -1;
      } else {
        _activeScrapeTab = (_activeScrapeTab - 1).clamp(
          0,
          _scrapeTabs.length - 1,
        );
      }
    });
  }

  static String _methodLabel(ScraperMethod m) => switch (m) {
    ScraperMethod.dartHttp => 'Dart HTTP',
    ScraperMethod.curl => 'curl',
    ScraperMethod.pythonRequests => 'Python requests',
    ScraperMethod.selenium => 'Selenium',
    ScraperMethod.puppeteer => 'Puppeteer',
  };

  /// Settings sheet: method availability + headers/retry/proxy/
  /// max-size/format/filters (issue 1+3).
  void _showScraperSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        var cfg = _scraperConfig.copy();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scraper settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Methods (green = available)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in _availability)
                          Tooltip(
                            message: a.detail.isEmpty
                                ? (a.available ? 'available' : 'not found')
                                : a.detail,
                            child: ChoiceChip(
                              label: Text(
                                _methodLabel(a.method),
                                style: TextStyle(
                                  color: a.available
                                      ? null
                                      : Theme.of(context).disabledColor,
                                ),
                              ),
                              selected: cfg.method == a.method,
                              avatar: Icon(
                                a.available ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color: a.available
                                    ? Colors.green
                                    : Theme.of(context).disabledColor,
                              ),
                              onSelected: a.available
                                  ? (_) => setSheetState(
                                      () => cfg.method = a.method,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Output format',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in ScraperOutputFormat.values)
                          ChoiceChip(
                            label: Text(f.name),
                            selected: cfg.format == f,
                            onSelected: (_) =>
                                setSheetState(() => cfg.format = f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Retries: ${cfg.retries}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: cfg.retries.toDouble(),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: '${cfg.retries}',
                      onChanged: (v) =>
                          setSheetState(() => cfg.retries = v.round()),
                    ),
                    Text(
                      'Timeout: ${cfg.timeout.inSeconds}s',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: cfg.timeout.inSeconds.clamp(5, 120).toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      label: '${cfg.timeout.inSeconds}s',
                      onChanged: (v) => setSheetState(
                        () => cfg.timeout = Duration(seconds: v.round()),
                      ),
                    ),
                    Text(
                      'Max size: ${(cfg.maxBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: cfg.maxBytes
                          .clamp(65536, 20 * 1024 * 1024)
                          .toDouble(),
                      min: 65536,
                      max: 20 * 1024 * 1024,
                      divisions: 19,
                      label:
                          '${(cfg.maxBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                      onChanged: (v) =>
                          setSheetState(() => cfg.maxBytes = v.round()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Proxy (http://host:port, blank = none)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: TextEditingController(text: cfg.proxy ?? ''),
                      onChanged: (v) => cfg.proxy = v.isEmpty ? null : v,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Headers',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final entry in cfg.headers.entries)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setSheetState(
                              () => cfg.headers.remove(entry.key),
                            ),
                          ),
                        ],
                      ),
                    _HeaderAddRow(
                      onAdd: (k, v) => setSheetState(() => cfg.headers[k] = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Element filter (table, div.class, #id)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: TextEditingController(
                        text: cfg.elementFilter,
                      ),
                      onChanged: (v) => cfg.elementFilter = v,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Text filter (regex per line)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: TextEditingController(text: cfg.textFilter),
                      onChanged: (v) => cfg.textFilter = v,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() => _scraperConfig = cfg);
                            _saveScraperConfig();
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Scrape-result tab strip + content with clickable links.
  Widget _buildScrapeArea(ThemeData theme) {
    final tab = _scrapeTabs[_activeScrapeTab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _scrapeTabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InputChip(
                    label: Text(
                      Uri.tryParse(_scrapeTabs[i].url)?.host ?? '?',
                      style: TextStyle(
                        fontSize: 11,
                        color: i == _activeScrapeTab
                            ? theme.colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    selected: i == _activeScrapeTab,
                    onSelected: (_) => setState(() => _activeScrapeTab = i),
                    onDeleted: () => _closeScrapeTab(i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildScrapeContent(theme, tab)),
      ],
    );
  }

  Widget _buildScrapeContent(ThemeData theme, _ScrapeTab tab) {
    final result = tab.result;
    if (!result.success) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 8),
            Text('Scrape failed', style: theme.textTheme.titleSmall),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                result.error ?? 'unknown error',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    // extract links; clicking one scrapes the target into a NEW tab
    final linkRe = RegExp(
      r'''<a[^>]*href=["']([^"'#]+)["']''',
      caseSensitive: false,
    );
    final links = <(String, String)>[];
    for (final m in linkRe.allMatches(result.content)) {
      final href = m.group(1)!;
      if (href.startsWith('javascript:') || href.startsWith('mailto:')) {
        continue;
      }
      final absolute = _absoluteUrl(result.url, href);
      if (absolute == null) continue;
      if (links.any((l) => l.$1 == absolute)) continue;
      links.add((absolute, _linkText(result.content, m.end)));
      if (links.length >= 100) break;
    }

    final bodyText = result.format == ScraperOutputFormat.html
        ? ScraperService.htmlToText(result.content)
        : result.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _metaChip(theme, Icons.link, '${links.length} links'),
              _metaChip(theme, Icons.data_object, result.format.name),
              _metaChip(
                theme,
                Icons.save,
                '${(result.bytes / 1024).toStringAsFixed(0)} KB',
              ),
              _metaChip(theme, Icons.timer, '${result.elapsedMs} ms'),
              _metaChip(theme, Icons.build, _methodLabel(result.method)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      bodyText,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: links.length,
                    itemBuilder: (context, i) {
                      final (url, text) = links[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          text.isEmpty ? url : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        onTap: () => _scrapeIntoNewTab(url),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grab the anchor's inner text (up to the closing tag, tags stripped).
  static String _linkText(String html, int from) {
    final end = html.indexOf('</a>', from);
    if (end < 0) return '';
    final inner = html.substring(from, end).replaceAll(RegExp(r'<[^>]+>'), '');
    final t = inner.trim();
    return t.length > 60 ? '${t.substring(0, 60)}…' : t;
  }

  Widget _metaChip(ThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: _scraping
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: const Text('Scrape'),
                onPressed: _scraping ? null : _scrape,
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Scraper settings',
                onPressed: _showScraperSettings,
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
          // scraped-page tabs: clicking a link inside a scraped page
          // opens the target as another tab here (issue 3)
          if (_scrapeTabs.isNotEmpty)
            Expanded(child: _buildScrapeArea(theme))
          else ...[
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
                            'Open a page, or Scrape it into a tab here.\n'
                                'Visited URLs show up below.',
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.download_for_offline_outlined,
                                  size: 16,
                                ),
                                tooltip: 'Scrape into tab',
                                onPressed: () {
                                  _urlCtrl.text = url;
                                  _scrape();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _saveRecents([..._recents]..removeAt(i));
                                },
                              ),
                            ],
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

/// One open scraped page in the scrape-tab strip.
class _ScrapeTab {
  final String url;
  final ScrapeResult result;

  const _ScrapeTab({required this.url, required this.result});
}

/// One-row key/value editor for adding an HTTP header in the settings
/// sheet.
class _HeaderAddRow extends StatefulWidget {
  final void Function(String key, String value) onAdd;

  const _HeaderAddRow({required this.onAdd});

  @override
  State<_HeaderAddRow> createState() => _HeaderAddRowState();
}

class _HeaderAddRowState extends State<_HeaderAddRow> {
  final _keyCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(
              hintText: 'Header name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _valueCtrl,
            decoration: const InputDecoration(
              hintText: 'Value',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Add header',
          onPressed: () {
            final k = _keyCtrl.text.trim();
            final v = _valueCtrl.text.trim();
            if (k.isEmpty || v.isEmpty) return;
            widget.onAdd(k, v);
            _keyCtrl.clear();
            _valueCtrl.clear();
          },
        ),
      ],
    );
  }
}
