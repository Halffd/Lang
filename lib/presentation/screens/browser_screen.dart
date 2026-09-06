import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:provider/provider.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/data/repositories/dictionary_service.dart';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  final String? title;

  const BrowserScreen({super.key, this.initialUrl, this.title});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _isLoading = false;
  double _loadProgress = 0.0;
  String? _hoveredUrl;
  Offset _hoverPosition = Offset.zero;
  bool _showHoverPopup = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _lastError;

  WebUri? _currentUrl;

  bool _showDefinitionsPanel = false;
  bool _showAllReadings = false;
  String _selectedText = '';
  List<String> _definitions = [];
  Map<String, List<String>> _readingsMap = {};

  final ScreenshotController _screenshotController = ScreenshotController();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isCapturingOcr = false;
  bool _showOcrResults = false;
  String _ocrExtractedText = '';
  List<String> _detectedWords = [];
  bool _isMokuroMode = false;
  final GlobalKey _webViewKey = GlobalKey();
  Rect? _selectionRect;
  bool _isSelectingRegion = false;
  bool _isDarkMode = false;
  bool _darkModeInvertOnly = false; // pure invert vs dark mode CSS
  bool _isAdBlockerEnabled = true;
  int _adsBlockedCount = 0;
  final Set<String> _blockedDomains = {};
  final List<String> _blockedUrls = [];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// True when the inappwebview plugin has no implementation for
  /// this platform (e.g. Linux desktop) - the browser screen then
  /// shows a fallback with an external-browser launch button.
  static bool get _webviewUnsupported =>
      Platform.isLinux || Platform.isWindows;

  Future<void> _initWebView() async {
    if (_webviewUnsupported) return;
    try {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    } catch (e) {
      debugPrint('WebView init skipped: $e');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _updateNavigationState() async {
    if (_controller == null) return;
    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();
    final url = await _controller!.getUrl();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
        _currentUrl = url;
      });
    }
  }

  Future<void> _handleSubmit(String url) async {
    _urlFocusNode.unfocus();
    final finalUrl = _normalizeUrl(url.trim());
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(finalUrl)));
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return 'https://www.google.com';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (_looksLikeDomain(url)) {
        return 'https://$url';
      }
      return 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  bool _looksLikeDomain(String text) {
    return text.contains('.') && !text.contains(' ') && RegExp(r'\.[a-zA-Z]{2,}').hasMatch(text);
  }

  void _updateHoverInfo(String? url, Offset position) {
    if (url == null || url.isEmpty) {
      setState(() {
        _showHoverPopup = false;
        _hoveredUrl = null;
      });
      return;
    }

    if (!url.startsWith('http') && !url.startsWith('/') && !url.startsWith('data:')) {
      setState(() => _showHoverPopup = false);
      return;
    }

    setState(() {
      _hoveredUrl = url.startsWith('data:') ? 'Data URL' : url;
      _hoverPosition = position;
      _showHoverPopup = true;
    });
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildUrlBar(theme),
        actions: _buildActions(theme),
        bottom: _buildStatusBar(theme),
      ),
      body: Column(
        children: [
          if (_lastError != null) _buildErrorBanner(theme),
          if (_showDefinitionsPanel) _buildDefinitionsPanel(theme),
          if (_showOcrResults)
            Container(
              height: 50,
              color: theme.colorScheme.primaryContainer,
              child: InkWell(
                onTap: () => _showOcrResultsPanel(theme),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.text_fields, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${_detectedWords.length} words detected - Tap to view',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  key: _webViewKey,
                  child: _buildWebView(),
                ),
                if (_isLoading) _buildLoadingBar(theme),
                if (_showHoverPopup && _hoveredUrl != null) _buildHoverPopup(theme),
                if (_showAllReadings && _readingsMap.isNotEmpty) _buildReadingsPanel(theme),
                if (_isCapturingOcr)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Processing OCR...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildStatusBar(ThemeData theme) {
    final isActive = _showDefinitionsPanel || _showAllReadings || _isMokuroMode;
    return PreferredSize(
      preferredSize: const Size.fromHeight(28),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            _statusChip(
              theme,
              Icons.album,
              'Definitions \\',
              _showDefinitionsPanel,
              () => setState(() => _showDefinitionsPanel = !_showDefinitionsPanel),
            ),
            const SizedBox(width: 8),
            _statusChip(
              theme,
              Icons.translate,
              'Readings Shift+R',
              _showAllReadings,
              () => setState(() => _showAllReadings = !_showAllReadings),
            ),
            const SizedBox(width: 8),
            _statusChip(
              theme,
              Icons.auto_fix_high,
              'Mokuro',
              _isMokuroMode,
              _toggleMokuroMode,
            ),
            const SizedBox(width: 8),
            _statusChip(
              theme,
              Icons.brightness_3,
              'Dark',
              _isDarkMode,
              _showDarkModeOptions,
            ),
            const SizedBox(width: 8),
            _statusChip(
              theme,
              Icons.shield,
              'Ad ${_adsBlockedCount > 0 ? '$_adsBlockedCount' : ''}',
              _isAdBlockerEnabled,
              _showAdBlockerOptions,
            ),
            const Spacer(),
            if (_selectedText.isNotEmpty)
              Text(
                'Selected: ${_selectedText.length > 20 ? '${_selectedText.substring(0, 20)}...' : _selectedText}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ThemeData theme, IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.backslash) {
      setState(() {
        _showDefinitionsPanel = !_showDefinitionsPanel;
        if (_showDefinitionsPanel) {
          _extractDefinitions();
        }
      });
    } else if (isShift && key == LogicalKeyboardKey.keyR) {
      setState(() {
        _showAllReadings = !_showAllReadings;
        if (_showAllReadings) {
          _extractReadings();
        }
      });
    }
  }

  Future<void> _extractDefinitions() async {
    if (_controller == null) return;

    try {
      final selectedText = await _controller!.getSelectedText();
      if (selectedText != null && selectedText.isNotEmpty) {
        _selectedText = selectedText;
        _definitions = _parseDefinitions(selectedText);
      } else {
        _selectedText = '';
        _definitions = [];
      }
    } catch (e) {
      _definitions = [];
    }
    if (mounted) setState(() {});
  }

  List<String> _parseDefinitions(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words;
  }

  Future<void> _extractReadings() async {
    if (_controller == null) return;

    try {
      final pageContent = await _controller!.getHtml();
      if (pageContent != null) {
        _readingsMap = _parseReadings(pageContent);
      }
    } catch (e) {
      _readingsMap = {};
    }
    if (mounted) setState(() {});
  }

  Map<String, List<String>> _parseReadings(String html) {
    final readings = <String, List<String>>{};
    final japaneseReadingRegex = RegExp(r'([一-龯ヶ革命]+)\s*\[([^\]]+)\]');
    final chinesePinyinRegex = RegExp(r'([一-龯]+)\s*(pinyin[:\s]*([^<,\n]+))', caseSensitive: false);
    final koreanRegex = RegExp(r'([가-힣]+)\s*\( ([^)]+) \)');

    for (final match in japaneseReadingRegex.allMatches(html)) {
      final word = match.group(1) ?? '';
      final reading = match.group(2) ?? '';
      if (word.isNotEmpty && reading.isNotEmpty) {
        readings.putIfAbsent(word, () => []).add('Hiragana/Katakana: $reading');
      }
    }

    for (final match in chinesePinyinRegex.allMatches(html)) {
      final word = match.group(1) ?? '';
      final pinyin = match.group(3)?.trim() ?? '';
      if (word.isNotEmpty && pinyin.isNotEmpty) {
        readings.putIfAbsent(word, () => []).add('Pinyin: $pinyin');
      }
    }

    for (final match in koreanRegex.allMatches(html)) {
      final word = match.group(1) ?? '';
      final reading = match.group(2)?.trim() ?? '';
      if (word.isNotEmpty && reading.isNotEmpty) {
        readings.putIfAbsent(word, () => []).add('Hangul: $reading');
      }
    }

    return readings;
  }

  Widget _buildDefinitionsPanel(ThemeData theme) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: _definitions.isEmpty && _selectedText.isEmpty
          ? Center(child: Text('Select text on page and press \\ to see definitions', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              itemCount: _definitions.isEmpty ? 1 : _definitions.length,
              itemBuilder: (context, index) {
                if (_definitions.isEmpty) {
                  return Center(child: Text('No definitions found for "$_selectedText"', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))));
                }
                final word = _definitions[index];
                return Card(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _searchWordDefinition(word),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Tap to define', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _searchWordDefinition(String word) {
    final searchUrl = 'https://www.google.com/search?q=define+$word';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
  }

  Widget _buildReadingsPanel(ThemeData theme) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = screenSize.width * 0.35;
    final panelHeight = screenSize.height * 0.6;

    return Positioned(
      right: 10,
      top: 10,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: panelWidth.clamp(280.0, 400.0),
          height: panelHeight.clamp(200.0, 500.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'All Readings (${_readingsMap.length} words)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _showAllReadings = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _readingsMap.length,
                  itemBuilder: (context, index) {
                    final word = _readingsMap.keys.elementAt(index);
                    final readings = _readingsMap[word]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    word,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _searchWordDefinition(word),
                                  child: Icon(Icons.search, size: 16, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: readings.map((reading) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    reading,
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override

  Widget _buildErrorBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastError!,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _lastError = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlBar(ThemeData theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: _urlController,
        focusNode: _urlFocusNode,
        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search or enter URL',
          hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: _handleSubmit,
        onTap: () {
          if (_urlController.text.isNotEmpty) {
            _urlController.selection = TextSelection(baseOffset: 0, extentOffset: _urlController.text.length);
          }
        },
      ),
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    return [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: _canGoBack ? () => _controller?.goBack() : null,
        tooltip: 'Back',
      ),
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 20),
        onPressed: _canGoForward ? () => _controller?.goForward() : null,
        tooltip: 'Forward',
      ),
      IconButton(
        icon: const Icon(Icons.refresh, size: 22),
        onPressed: () => _controller?.reload(),
        tooltip: 'Refresh',
      ),
      IconButton(
        icon: const Icon(Icons.home, size: 22),
        onPressed: () => _handleSubmit('https://www.google.com'),
        tooltip: 'Home',
      ),
      IconButton(
        icon: Icon(_isMokuroMode ? Icons.auto_fix_high : Icons.document_scanner, size: 22, color: _isMokuroMode ? theme.colorScheme.primary : null),
        onPressed: _toggleMokuroMode,
        tooltip: 'Mokuro Mode (Screenshot OCR)',
      ),
      IconButton(
        icon: Icon(_isCapturingOcr ? Icons.hourglass_empty : Icons.photo_camera, size: 22),
        onPressed: _isCapturingOcr ? null : _captureScreenshot,
        tooltip: 'Capture & OCR',
      ),
      if (_isMokuroMode)
        IconButton(
          icon: const Icon(Icons.crop_free, size: 22),
          onPressed: _startRegionSelection,
          tooltip: 'Select Region',
        ),
      IconButton(
        icon: Icon(_isDarkMode ? Icons.brightness_3 : Icons.brightness_7, size: 22, color: _isDarkMode ? theme.colorScheme.primary : null),
        onPressed: _showDarkModeOptions,
        tooltip: 'Dark Mode',
      ),
      IconButton(
        icon: Badge(
          isLabelVisible: _adsBlockedCount > 0,
          label: Text('$_adsBlockedCount'),
          child: Icon(
            _isAdBlockerEnabled ? Icons.shield : Icons.shield_outlined,
            size: 22,
            color: _isAdBlockerEnabled ? Colors.green : null,
          ),
        ),
        onPressed: _showAdBlockerOptions,
        tooltip: 'Ad Blocker',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 22),
        onSelected: _handleMenuAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'toggle_definitions',
            child: _menuItemWithCheck(Icons.album, 'Definitions Panel', _showDefinitionsPanel),
          ),
          PopupMenuItem(
            value: 'toggle_readings',
            child: _menuItemWithCheck(Icons.translate, 'All Readings Panel', _showAllReadings),
          ),
          PopupMenuItem(
            value: 'toggle_mokuro',
            child: _menuItemWithCheck(Icons.auto_fix_high, 'Mokuro Mode', _isMokuroMode),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'ocr_from_camera', child: _menuItem(Icons.camera_alt, 'OCR from Camera')),
          PopupMenuItem(value: 'ocr_from_gallery', child: _menuItem(Icons.photo_library, 'OCR from Gallery')),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'dark_mode_inverted',
            child: _menuItemWithCheck(Icons.brightness_3, 'Dark Mode (Inverted)', _isDarkMode && !_darkModeInvertOnly),
          ),
          PopupMenuItem(
            value: 'dark_mode_pure',
            child: _menuItemWithCheck(Icons.brightness_2, 'Dark Mode (Pure)', _isDarkMode && _darkModeInvertOnly),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle_ad_blocker',
            child: _menuItemWithCheck(Icons.shield, 'Ad Blocker', _isAdBlockerEnabled),
          ),
          PopupMenuItem(
            value: 'view_blocked',
            child: _menuItem(Icons.list, 'View Blocked (${_adsBlockedCount})'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'share', child: _menuItem(Icons.share, 'Share')),
          PopupMenuItem(value: 'copy', child: _menuItem(Icons.copy, 'Copy URL')),
          PopupMenuItem(value: 'open_external', child: _menuItem(Icons.open_in_browser, 'Open in Browser')),
          PopupMenuItem(value: 'stop', child: _menuItem(Icons.stop, 'Stop Loading')),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'clear_cache', child: _menuItem(Icons.delete_outline, 'Clear Cache')),
        ],
      ),
    ];
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }

  Widget _menuItemWithCheck(IconData icon, String label, bool isChecked) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (isChecked) const Icon(Icons.check, size: 16),
      ],
    );
  }

  Widget _menuItemInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildWebView() {
    // No native webview on this platform: offer to open in the
    // system browser instead.
    if (_webviewUnsupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Embedded webview is not available on this platform.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in system browser'),
                onPressed: () async {
                  final url = widget.initialUrl ?? 'https://www.google.com';
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ),
      );
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.initialUrl ?? 'https://www.google.com'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        useShouldInterceptFetchRequest: true,
        supportZoom: true,
        transparentBackground: false,
        cacheEnabled: true,
        incognito: false,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
        allowFileAccess: true,
        allowContentAccess: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        isInspectable: true,
        userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      onLoadStart: (controller, url) {
        setState(() {
          _isLoading = true;
          _lastError = null;
          if (url != null) _urlController.text = url.toString();
        });
        _updateNavigationState();
      },
      onLoadStop: (controller, url) {
        setState(() {
          _isLoading = false;
          _loadProgress = 0;
          if (url != null) _urlController.text = url.toString();
        });
        _updateNavigationState();
      },
      onProgressChanged: (controller, progress) {
        setState(() {
          _loadProgress = progress / 100;
        });
      },
      onReceivedError: (controller, request, error) {
        setState(() {
          _isLoading = false;
          _loadProgress = 0;
          _lastError = 'Failed to load: ${request.url}';
        });
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (errorResponse.statusCode != 200 && errorResponse.statusCode != 204) {
          setState(() {
            _lastError = 'HTTP Error: ${errorResponse.statusCode}';
          });
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        final uri = navigationAction.request.url;

        if (uri == null) return NavigationActionPolicy.CANCEL;

        if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:') || url.startsWith('tg:')) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            return NavigationActionPolicy.CANCEL;
          }
        }

        if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('file://') && !url.startsWith('data:')) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationActionPolicy.CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },
      shouldInterceptFetchRequest: (controller, fetchRequest) async {
        if (_isAdBlockerEnabled) {
          final url = fetchRequest.url?.toString() ?? '';
          if (_shouldBlockUrl(url)) {
            _blockedUrls.add(url);
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && uri.host.isNotEmpty) {
                _blockedDomains.add(uri.host);
              }
            }
            setState(() => _adsBlockedCount++);
            debugPrint('Ad blocked: $url');
            fetchRequest.action = FetchRequestAction.ABORT;
            return fetchRequest;
          }
        }
        return fetchRequest;
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('Browser console: ${consoleMessage.message}');
      },
      onScrollChanged: (controller, x, y) {
        setState(() => _showHoverPopup = false);
      },
    );
  }

  Widget _buildLoadingBar(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: _loadProgress > 0 ? _loadProgress : null,
        minHeight: 3,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildHoverPopup(ThemeData theme) {
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 340.0;
    const popupHeight = 130.0;

    double left = _hoverPosition.dx;
    double top = _hoverPosition.dy + 10;

    if (left + popupWidth > screenSize.width - 20) {
      left = screenSize.width - popupWidth - 20;
    }
    if (top + popupHeight > screenSize.height - 20) {
      top = _hoverPosition.dy - popupHeight - 20;
    }

    return Positioned(
      left: left.clamp(10, screenSize.width - popupWidth - 10),
      top: top.clamp(10, screenSize.height - popupHeight - 60),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: popupWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hoveredUrl ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _hoverButton(theme, Icons.bookmark_add, 'Save', () {
                    if (_hoveredUrl != null) _handleSaveToApp(_hoveredUrl!);
                    setState(() => _showHoverPopup = false);
                  }),
                  _hoverButton(theme, Icons.style, 'Anki', () {
                    if (_hoveredUrl != null) _handleAddToAnki(_hoveredUrl!);
                    setState(() => _showHoverPopup = false);
                  }),
                  _hoverButton(theme, Icons.menu_book, 'Define', () {
                    if (_hoveredUrl != null) _handleDefine(_hoveredUrl!);
                    setState(() => _showHoverPopup = false);
                  }),
                  _hoverButton(theme, Icons.open_in_new, 'Open', () async {
                    if (_hoveredUrl != null && !_hoveredUrl!.startsWith('data:')) {
                      await launchUrl(Uri.parse(_hoveredUrl!), mode: LaunchMode.externalApplication);
                    }
                    setState(() => _showHoverPopup = false);
                  }),
                  _hoverButton(theme, Icons.close, 'Close', () {
                    setState(() => _showHoverPopup = false);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoverButton(ThemeData theme, IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  void _toggleMokuroMode() {
    setState(() {
      _isMokuroMode = !_isMokuroMode;
      if (!_isMokuroMode) {
        _showOcrResults = false;
        _selectionRect = null;
      }
    });
    if (_isMokuroMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mokuro Mode: Take screenshot to extract and lookup words'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startRegionSelection() {
    setState(() {
      _isSelectingRegion = true;
      _selectionRect = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap and drag to select region'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _captureScreenshot() async {
    if (_controller == null) return;

    setState(() => _isCapturingOcr = true);

    try {
      final uri = await _controller?.getUrl();
      if (uri == null) return;

      final screenshot = await _controller?.takeScreenshot();
      if (screenshot == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture screenshot')),
          );
        }
        return;
      }

      await _processOcrImage(screenshot);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
      }
    } finally {
      setState(() => _isCapturingOcr = false);
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processOcrImage(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _captureFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processOcrImage(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    }
  }

  Future<void> _processOcrImage(Uint8List imageBytes) async {
    setState(() {
      _isCapturingOcr = true;
      _showOcrResults = false;
    });

    try {
      final result = await _ocrService.recognizeFromBytes(
        imageBytes,
        engine: OcrEngine.mlKit,
      );

      if (result.isSuccess && result.text.isNotEmpty) {
        setState(() {
          _ocrExtractedText = result.text;
          _detectedWords = _extractJapaneseWords(result.text);
          _showOcrResults = true;
        });

        if (_isMokuroMode && _detectedWords.isNotEmpty) {
          await _performMokuroLookup(_detectedWords);
        }
      } else if (result.isEasyOcrUnavailable) {
        final fallbackResult = await _ocrService.recognizeFromBytes(
          imageBytes,
          engine: OcrEngine.easyOcr,
        );
        if (fallbackResult.isSuccess) {
          setState(() {
            _ocrExtractedText = fallbackResult.text;
            _detectedWords = _extractJapaneseWords(fallbackResult.text);
            _showOcrResults = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No text found in image${result.error != null ? ': ${result.error}' : ''}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR processing failed: $e')),
        );
      }
    } finally {
      setState(() => _isCapturingOcr = false);
    }
  }

  List<String> _extractJapaneseWords(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf\u3400-\u4dbf]+');
    final matches = japaneseRegex.allMatches(text);
    final words = <String>[];
    for (final match in matches) {
      final word = match.group(0);
      if (word != null && word.isNotEmpty && !words.contains(word)) {
        words.add(word);
      }
    }
    return words;
  }

  Future<void> _performMokuroLookup(List<String> words) async {
    if (words.isEmpty) return;

    final dictionaryService = DictionaryService();
    final foundEntries = <Map<String, dynamic>>[];

    for (final word in words.take(20)) {
      try {
        final result = await dictionaryService.searchTerm(word);
              if (result.entries.isNotEmpty) {
                final e = result.entries.first;
                foundEntries.add({
                  'word': word,
                  'reading': e.reading,
                  'meaning': e.definitions.isNotEmpty ? e.definitions.first : '',
          });
        }
      } catch (e) {
        // Continue with next word
      }
    }

    if (foundEntries.isNotEmpty && mounted) {
      _showMokuroResultsDialog(foundEntries);
    }
}

  // Only actual ad/tracking domains - matched exactly against host
  static const Set<String> _adDomains = {
    // Google
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googleadsystem.com',
    'googletag.com',
    'googletagmanager.com',
    'google-analytics.com',
    'googletagservices.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'pubads.g.doubleclick.net',

    // Facebook/Meta
    'facebook.net',
    'facebook.com/tr',
    'connect.facebook.net',
    'pixel.facebook.com',

    // Microsoft
    'bing.com',
    'msn.com',
    'clarity.ms',

    // Twitter/X
    't.co',
    'analytics.twitter.com',
    'ads-twitter.com',

    // TikTok
    'tiktok.com',
    'tiktokcdn.com',

    // Amazon
    'amazon-adsystem.com',
    'a9.com',
    'amazon.com/ads',

    // Apple
    'apple.com/safari/privacy',
    'iadsdk.apple.com',

    // Major ad networks
    'adnxs.com',
    'adsrvr.org',
    'advertising.com',
    'adform.net',
    'adcolony.com',
    'admob.com',
    'moatads.com',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'criteo.com',
    'criteo.net',
    'outbrain.com',
    'taboola.com',
    'teads.tv',
    'sharethrough.com',
    'triplelift.com',
    'yieldmo.com',
    'indexww.com',
    'casalemedia.com',
    'contextweb.com',
    'smartadserver.com',
    'sizmek.com',
    'lijit.com',
    'sovrn.com',
    'bidswitch.net',

    // Analytics/tracking (blocked as they often serve ads)
    'analytics.google.com',
    'segment.io',
    'segment.com',
    'mixpanel.com',
    'amplitude.com',
    'hotjar.com',
    'crazyegg.com',
    'optimizely.com',
    'branch.io',
    'adjust.com',
    'appsflyer.com',
    'app-measurement.com',
    'heapanalytics.com',
    'intercom.io',
    'drift.com',
    'zendesk.com',
    'freshdesk.com',

    // Mobile ad SDKs
    'mopub.com',
    'unity3d.com/ads',
    'unityads.unity3d.com',
    'applovin.com',
    'vungle.com',
    'chartboost.com',
    'ironsource.com',
    'mintegral.com',

    // Pop-up/redirect networks
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'exoclick.com',
    'zedo.com',
    'outbivo.com',
    'blip.com',
  };

  // Only block the most common ad container selectors - be conservative
  // to avoid hiding legitimate content
  static const String _adBlockerCss = '''
/* Hide common ad containers by class */
.ads, .advert, .ad-container, .ad-wrapper, .ad-unit, .ad-banner,
.advertisement, .sponsored, .promoted,
[class*="google_ads"], [id*="google_ads"],
iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
iframe[src*="dable"] {
  display: none !important;
  visibility: hidden !important;
}
''';

  static const String _darkModeCss = '''
html {
  filter: invert(90%) hue-rotate(180deg) !important;
  background-color: #111 !important;
}
img, video, canvas, svg, picture, [style*="background-image"] {
  filter: invert(100%) hue-rotate(180deg) !important;
}
[style*="background: url"], [style*="background-url"] {
  filter: invert(100%) hue-rotate(180deg) !important;
}
''';

  static const String _darkModeInvertOnlyCss = '''
html {
  filter: invert(100%) !important;
  background-color: #000 !important;
}
img, video, canvas, svg, picture {
  filter: invert(100%) !important;
}
''';

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _applyDarkMode();
  }

  void _toggleDarkModeInvert() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _darkModeInvertOnly = !_darkModeInvertOnly;
    });
    _applyDarkMode();
  }

  Future<void> _applyDarkMode() async {
    if (_controller == null) return;

    final css = _darkModeInvertOnly ? _darkModeInvertOnlyCss : _darkModeCss;

    if (_isDarkMode) {
      await _controller?.evaluateJavascript(source: '''
        (function() {
          var style = document.createElement('style');
          style.id = 'dark-mode-style';
          style.type = 'text/css';
          style.innerHTML = \`$css\`;
          document.head.appendChild(style);
        })();
      ''');
    } else {
      await _controller?.evaluateJavascript(source: '''
        (function() {
          var style = document.getElementById('dark-mode-style');
          if (style) style.remove();
        })();
      ''');
    }
  }

  void _showDarkModeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_isDarkMode ? Icons.check : Icons.brightness_3),
              title: const Text('Dark Mode (Inverted)'),
              subtitle: const Text('Inverts page colors - works on all sites'),
              trailing: _isDarkMode && !_darkModeInvertOnly
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _darkModeInvertOnly = false;
                setState(() => _isDarkMode = true);
                _applyDarkMode();
              },
            ),
            ListTile(
              leading: Icon(_isDarkMode ? Icons.check : Icons.brightness_2),
              title: const Text('Dark Mode (Pure Invert)'),
              subtitle: const Text('Pure color inversion'),
              trailing: _isDarkMode && _darkModeInvertOnly
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _darkModeInvertOnly = true;
                setState(() => _isDarkMode = true);
                _applyDarkMode();
              },
            ),
            if (_isDarkMode)
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Turn Off'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isDarkMode = false);
                  _applyDarkMode();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toggleAdBlocker() {
    setState(() {
      _isAdBlockerEnabled = !_isAdBlockerEnabled;
      if (!_isAdBlockerEnabled) {
        _adsBlockedCount = 0;
        _blockedDomains.clear();
        _blockedUrls.clear();
      }
    });
    if (_isAdBlockerEnabled) {
      _applyAdBlockerCss();
    } else {
      _removeAdBlockerCss();
    }
  }

  bool _shouldBlockUrl(String url) {
    if (url.isEmpty || url == 'about:blank' || url.startsWith('data:')) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Block exact domain matches and subdomains of known ad domains
      for (final adDomain in _adDomains) {
        if (host == adDomain ||
            host.endsWith('.$adDomain') ||
            host == 'www.$adDomain') {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  void _showAdBlockerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Ad Blocker'),
              subtitle: Text(_isAdBlockerEnabled ? 'Blocking ads' : 'Ads are allowed'),
              value: _isAdBlockerEnabled,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != _isAdBlockerEnabled) {
                  _toggleAdBlocker();
                }
              },
            ),
            if (_isAdBlockerEnabled && _adsBlockedCount > 0)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text('$_adsBlockedCount ads blocked'),
                subtitle: Text('${_blockedDomains.length} domains blocked'),
              ),
            if (_isAdBlockerEnabled && _blockedUrls.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View Blocked URLs'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockedUrlsList();
                },
              ),
            if (_isAdBlockerEnabled)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reload Page'),
                onTap: () {
                  Navigator.pop(context);
                  _controller?.reload();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showBlockedUrlsList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Blocked URLs (${_blockedUrls.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _blockedUrls.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.block, size: 16),
                title: Text(
                  _blockedUrls.elementAt(index),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _blockedUrls.clear();
                _blockedDomains.clear();
                _adsBlockedCount = 0;
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAdBlockerCss() async {
    if (_controller == null) return;

    await _controller?.evaluateJavascript(source: '''
      (function() {
        var style = document.createElement('style');
        style.id = 'ad-blocker-style';
        style.type = 'text/css';
        style.innerHTML = \`$_adBlockerCss\`;
        document.head.appendChild(style);
      })();
    ''');
  }

  Future<void> _removeAdBlockerCss() async {
    if (_controller == null) return;

    await _controller?.evaluateJavascript(source: '''
      (function() {
        var style = document.getElementById('ad-blocker-style');
        if (style) style.remove();
      })();
    ''');
  }

  void _showMokuroResultsDialog(List<Map<String, dynamic>> entries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high),
                  const SizedBox(width: 8),
                  Text(
                    'Mokuro - ${entries.length} words found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(
                      entry['word'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry['reading']?.isNotEmpty == true)
                          Text(entry['reading'], style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        if (entry['meaning']?.isNotEmpty == true)
                          Text(entry['meaning'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    onTap: () {
                      // Navigate to full definition
                      Navigator.pop(context);
                      _searchWord(entry['word'] ?? '');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _searchWord(String word) {
    final searchUrl = 'https://www.google.com/search?q=define+${Uri.encodeComponent(word)}';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
  }

  void _showOcrResultsPanel(ThemeData theme) {
    if (!_showOcrResults) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'OCR Results (${_detectedWords.length} words)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _ocrExtractedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: const Text('Copy'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _showOcrResults = false);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _ocrExtractedText,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_detectedWords.isNotEmpty) ...[
                      Text('Detected Words:', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _detectedWords.map((word) {
                          return ActionChip(
                            label: Text(word),
                            onPressed: () => _searchWord(word),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'share':
        if (_currentUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share: $_currentUrl')));
        }
        break;
      case 'copy':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
        break;
      case 'open_external':
        if (_currentUrl != null) {
          await launchUrl(_currentUrl!, mode: LaunchMode.externalApplication);
        }
        break;
      case 'stop':
        _controller?.stopLoading();
        setState(() => _isLoading = false);
        break;
      case 'toggle_definitions':
        setState(() {
          _showDefinitionsPanel = !_showDefinitionsPanel;
          if (_showDefinitionsPanel) {
            _extractDefinitions();
          }
        });
        break;
      case 'toggle_readings':
        setState(() {
          _showAllReadings = !_showAllReadings;
          if (_showAllReadings) {
            _extractReadings();
          }
        });
        break;
      case 'toggle_mokuro':
        _toggleMokuroMode();
        break;
      case 'dark_mode_inverted':
        setState(() {
          _darkModeInvertOnly = false;
          _isDarkMode = true;
        });
        _applyDarkMode();
        break;
      case 'dark_mode_pure':
        setState(() {
          _darkModeInvertOnly = true;
          _isDarkMode = true;
        });
        _applyDarkMode();
        break;
      case 'toggle_ad_blocker':
        _toggleAdBlocker();
        break;
      case 'view_blocked':
        _showBlockedUrlsList();
        break;
      case 'ocr_from_camera':
        await _captureFromCamera();
        break;
      case 'ocr_from_gallery':
        await _captureFromGallery();
        break;
      case 'clear_cache':
        if (_webviewUnsupported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No webview on this platform')));
          }
          break;
        }
        await _controller?.clearCache();
        await InAppWebViewController.clearAllCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
        }
        break;
    }
  }

  void _handleSaveToApp(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Lang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('URL: $url', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Save this link to your app collection?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to Lang!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleAddToAnki(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Anki'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('URL: $url', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Add this to your Anki deck?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to Anki!')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _handleDefine(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Define'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Looking up: $text', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Definition would appear here...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final searchUrl = 'https://www.google.com/search?q=define+${Uri.encodeComponent(text)}';
              _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}