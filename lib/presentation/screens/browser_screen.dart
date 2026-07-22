import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:provider/provider.dart';
import 'package:lang/data/services/ocr_service.dart';
import '../providers/analyzer_provider.dart'
import '../../data/repositories/dictionary_service.dart';
import 'browser/panels/definitions_panel.dart';
import 'browser/panels/readings_panel.dart';
import 'browser/panels/ocr_results_panel.dart';
import 'browser/panels/hover_popup.dart';
import 'browser/panels/status_bar.dart';
import 'browser/widgets/web_view_widget.dart';
import 'browser/widgets/url_bar.dart';
import 'browser/widgets/loading_bar.dart';
import 'browser/sheets/dark_mode_sheet.dart';
import 'browser/sheets/ad_blocker_sheet.dart';
import 'browser/sheets/blocked_urls_dialog.dart';
import 'browser/sheets/mokuro_results_dialog.dart';
import 'browser/sheets/menu_actions.dart';

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
  bool _darkModeInvertOnly = false;
  bool _isAdBlockerEnabled = true;
  int _adsBlockedCount = 0;
  final Set<String> _blockedDomains = {};
  final List<String> _blockedUrls = [];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
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

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: UrlBar(
            controller: _urlController,
            focusNode: _urlFocusNode,
            onSubmitted: _handleSubmit,
            isLoading: _isLoading,
          ),
          actions: _buildActions(theme),
          bottom: StatusBar(
            showDefinitionsPanel: _showDefinitionsPanel,
            showAllReadings: _showAllReadings,
            isMokuroMode: _isMokuroMode,
            isDarkMode: _isDarkMode,
            isAdBlockerEnabled: _isAdBlockerEnabled,
            adsBlockedCount: _adsBlockedCount,
            selectedText: _selectedText,
            onToggleDefinitions: () => setState(() {
              _showDefinitionsPanel = !_showDefinitionsPanel;
              if (_showDefinitionsPanel) _extractDefinitions();
            }),
            onToggleReadings: () => setState(() {
              _showAllReadings = !_showAllReadings;
              if (_showAllReadings) _extractReadings();
            }),
            onToggleMokuro: _toggleMokuroMode,
            onToggleDarkMode: _showDarkModeOptions,
            onToggleAdBlocker: _showAdBlockerOptions,
          ),
        ),
        body: Column(
          children: [
            if (_lastError != null) _buildErrorBanner(theme),
            if (_showDefinitionsPanel) DefinitionsPanel(
              definitions: _definitions,
              selectedText: _selectedText,
              onSearchDefinition: _searchWordDefinition,
            ),
            if (_showOcrResults) OcrResultsPanel(
              detectedWords: _detectedWords,
              onTap: _showOcrResultsPanel,
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(
                    key: _webViewKey,
                    controller: _controller,
                    initialUrl: widget.initialUrl,
                    onWebViewCreated: (controller) => _controller = controller,
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
                      setState(() => _loadProgress = progress / 100);
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
                        setState(() => _lastError = 'HTTP Error: ${errorResponse.statusCode}');
                      }
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      return _shouldOverrideUrlLoading(navigationAction);
                    },
                    shouldInterceptFetchRequest: (controller, fetchRequest) async {
                      return _shouldInterceptFetchRequest(fetchRequest);
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      debugPrint('Browser console: ${consoleMessage.message}');
                    },
                    onScrollChanged: (controller, x, y) {
                      setState(() => _showHoverPopup = false);
                    },
                  ),
                  if (_isLoading) LoadingBar(progress: _loadProgress),
                  if (_showHoverPopup && _hoveredUrl != null) HoverPopup(
                    hoveredUrl: _hoveredUrl!,
                    hoverPosition: _hoverPosition,
                    onSave: (url) => _handleSaveToApp(url),
                    onAnki: (url) => _handleAddToAnki(url),
                    onDefine: (url) => _handleDefine(url),
                    onOpen: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    onClose: () => setState(() => _showHoverPopup = false),
                  ),
                  if (_showAllReadings) ReadingsPanel(
                    readingsMap: _readingsMap,
                    onSearch: _searchWordDefinition,
                    onClose: () => setState(() => _showAllReadings = false),
                  ),
                  if (_isCapturingOcr) _buildOcrLoadingOverlay(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildStatusBar(ThemeData theme) {
    return StatusBar(
      showDefinitionsPanel: _showDefinitionsPanel,
      showAllReadings: _showAllReadings,
      isMokuroMode: _isMokuroMode,
      isDarkMode: _isDarkMode,
      isAdBlockerEnabled: _isAdBlockerEnabled,
      adsBlockedCount: _adsBlockedCount,
      selectedText: _selectedText,
      onToggleDefinitions: () => setState(() {
        _showDefinitionsPanel = !_showDefinitionsPanel;
        if (_showDefinitionsPanel) _extractDefinitions();
      }),
      onToggleReadings: () => setState(() {
        _showAllReadings = !_showAllReadings;
        if (_showAllReadings) _extractReadings();
      }),
      onToggleMokuro: _toggleMokuroMode,
      onToggleDarkMode: _showDarkModeOptions,
      onToggleAdBlocker: _showAdBlockerOptions,
    );
  }

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

  Widget _buildOcrLoadingOverlay(ThemeData theme) {
    return Container(
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
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.backslash) {
      setState(() {
        _showDefinitionsPanel = !_showDefinitionsPanel;
        if (_showDefinitionsPanel) _extractDefinitions();
      });
    } else if (isShift && key == LogicalKeyboardKey.keyR) {
      setState(() {
        _showAllReadings = !_showAllReadings;
        if (_showAllReadings) _extractReadings();
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
    final koreanRegex = RegExp(r'([가-힣]+)\s*\(([^)]+)\)');

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

  void _searchWordDefinition(String word) {
    final searchUrl = 'https://www.google.com/search?q=define+$word';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
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

  void _showDarkModeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => DarkModeSheet(
        isDarkMode: _isDarkMode,
        darkModeInvertOnly: _darkModeInvertOnly,
        onChanged: (enabled, invertOnly) {
          setState(() {
            _isDarkMode = enabled;
            _darkModeInvertOnly = invertOnly;
          });
          _applyDarkMode();
        },
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

  void _showAdBlockerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AdBlockerSheet(
        isAdBlockerEnabled: _isAdBlockerEnabled,
        adsBlockedCount: _adsBlockedCount,
        blockedDomainsCount: _blockedDomains.length,
        blockedUrls: _blockedUrls,
        onToggle: _toggleAdBlocker,
        onViewBlocked: _showBlockedUrlsList,
        onReload: () => _controller?.reload(),
      ),
    );
  }

  void _showBlockedUrlsList() {
    showDialog(
      context: context,
      builder: (context) => BlockedUrlsDialog(
        blockedUrls: _blockedUrls,
        onClear: () {
          setState(() {
            _blockedUrls.clear();
            _blockedDomains.clear();
            _adsBlockedCount = 0;
          });
        },
      ),
    );
  }

  NavigationActionPolicy _shouldOverrideUrlLoading(NavigationAction navigationAction) {
    final url = navigationAction.request.url?.toString() ?? '';
    final uri = navigationAction.request.url;

    if (uri == null) return NavigationActionPolicy.CANCEL;

    if (url.startsWith('tel:') || url.startsWith('mailto:') || url.startsWith('sms:') || url.startsWith('tg:')) {
      if (canLaunchUrl(uri)) {
        launchUrl(uri);
        return NavigationActionPolicy.CANCEL;
      }
    }

    if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('file://') && !url.startsWith('data:')) {
      if (canLaunchUrl(uri)) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationActionPolicy.CANCEL;
      }
    }

    return NavigationActionPolicy.ALLOW;
  }

  FetchRequest _shouldInterceptFetchRequest(FetchRequest fetchRequest) {
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
  }

  bool _shouldBlockUrl(String url) {
    if (url.isEmpty || url == 'about:blank' || url.startsWith('data:')) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

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

  static const Set<String> _adDomains = {
    // Google
    'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
    'googleadsystem.com', 'googletag.com', 'googletagmanager.com',
    'google-analytics.com', 'googletagservices.com', 'adservice.google.com',
    'pagead2.googlesyndication.com', 'pubads.g.doubleclick.net',

    // Facebook/Meta
    'facebook.net', 'facebook.com/tr', 'connect.facebook.net', 'pixel.facebook.com',

    // Microsoft
    'bing.com', 'msn.com', 'clarity.ms',

    // Twitter/X
    't.co', 'analytics.twitter.com', 'ads-twitter.com',

    // TikTok
    'tiktok.com', 'tiktokcdn.com',

    // Amazon
    'amazon-adsystem.com', 'a9.com', 'amazon.com/ads',

    // Apple
    'apple.com/safari/privacy', 'iadsdk.apple.com',

    // Major ad networks
    'adnxs.com', 'adsrvr.org', 'advertising.com', 'adform.net', 'adcolony.com',
    'admob.com', 'moatads.com', 'rubiconproject.com', 'pubmatic.com', 'openx.net',
    'criteo.com', 'criteo.net', 'outbrain.com', 'taboola.com', 'teads.tv',
    'sharethrough.com', 'triplelift.com', 'yieldmo.com', 'indexww.com',
    'casalemedia.com', 'contextweb.com', 'smartadserver.com', 'sizmek.com',
    'lijit.com', 'sovrn.com', 'bidswitch.net',

    // Analytics/tracking
    'analytics.google.com', 'segment.io', 'segment.com', 'mixpanel.com',
    'amplitude.com', 'hotjar.com', 'crazyegg.com', 'optimizely.com',
    'branch.io', 'adjust.com', 'appsflyer.com', 'app-measurement.com',
    'heapanalytics.com', 'intercom.io', 'drift.com', 'zendesk.com', 'freshdesk.com',

    // Mobile ad SDKs
    'mopub.com', 'unity3d.com/ads', 'unityads.unity3d.com', 'applovin.com',
    'vungle.com', 'chartboost.com', 'ironsource.com', 'mintegral.com',

    // Pop-up/redirect
    'popads.net', 'popcash.net', 'propellerads.com', 'exoclick.com',
    'zedo.com', 'outbivo.com', 'blip.com',
  };

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

  Future<void> _applyAdBlockerCss() async {
    if (_controller == null) return;
    await _controller?.evaluateJavascript(source: '''
      (function() {
        var style = document.createElement('style');
        style.id = 'ad-blocker-style';
        style.type = 'text/css';
        style.innerHTML = `$_adBlockerCss`;
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

  void _showMokuroResultsDialog(List<Map<String, dynamic>> entries) {
    showDialog(
      context: context,
      builder: (context) => MokuroResultsDialog(entries: entries),
    );
  }

  Future<void> _handleSaveToApp(String url) async {
    // Handle saving URL to app
  }

  Future<void> _handleAddToAnki(String url) async {
    // Handle adding to Anki
  }

  Future<void> _handleDefine(String url) async {
    // Handle definition lookup
  }

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

  static const Set<String> _adDomains = {
    // Google
    'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
    'googleadsystem.com', 'googletag.com', 'googletagmanager.com',
    'google-analytics.com', 'googletagservices.com', 'adservice.google.com',
    'pagead2.googlesyndication.com', 'pubads.g.doubleclick.net',

    // Facebook/Meta
    'facebook.net', 'facebook.com/tr', 'connect.facebook.net', 'pixel.facebook.com',

    // Microsoft
    'bing.com', 'msn.com', 'clarity.ms',

    // Twitter/X
    't.co', 'analytics.twitter.com', 'ads-twitter.com',

    // TikTok
    'tiktok.com', 'tiktokcdn.com',

    // Amazon
    'amazon-adsystem.com', 'a9.com', 'amazon.com/ads',

    // Apple
    'apple.com/safari/privacy', 'iadsdk.apple.com',

    // Major ad networks
    'adnxs.com', 'adsrvr.org', 'advertising.com', 'adform.net', 'adcolony.com',
    'admob.com', 'moatads.com', 'rubiconproject.com', 'pubmatic.com', 'openx.net',
    'criteo.com', 'criteo.net', 'outbrain.com', 'taboola.com', 'teads.tv',
    'sharethrough.com', 'triplelift.com', 'yieldmo.com', 'indexww.com',
    'casalemedia.com', 'contextweb.com', 'smartadserver.com', 'sizmek.com',
    'lijit.com', 'sovrn.com', 'bidswitch.net',

    // Analytics/tracking
    'analytics.google.com', 'segment.io', 'segment.com', 'mixpanel.com',
    'amplitude.com', 'hotjar.com', 'crazyegg.com', 'optimizely.com',
    'branch.io', 'adjust.com', 'appsflyer.com', 'app-measurement.com',
    'heapanalytics.com', 'intercom.io', 'drift.com', 'zendesk.com', 'freshdesk.com',

    // Mobile ad SDKs
    'mopub.com', 'unity3d.com/ads', 'unityads.unity3d.com', 'applovin.com',
    'vungle.com', 'chartboost.com', 'ironsource.com', 'mintegral.com',

    // Pop-up/redirect
    'popads.net', 'popcash.net', 'propellerads.com', 'exoclick.com',
    'zedo.com', 'outbivo.com', 'blip.com',
  };
}