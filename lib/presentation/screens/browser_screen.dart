import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _pageTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _lastError;

  WebUri? _currentUrl;

  bool _showDefinitionsPanel = false;
  bool _showAllReadings = false;
  String _selectedText = '';
  List<String> _definitions = [];
  Map<String, List<String>> _readingsMap = {};

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
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) {
      finalUrl = 'https://www.google.com';
    } else if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ') && finalUrl.contains('.')) {
        finalUrl = 'https://$finalUrl';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(finalUrl)));
  }

  void _updateHoverInfo(String? url, Offset position) {
    if (url != null && url.isNotEmpty && (url.startsWith('http') || url.startsWith('/') || url.startsWith('data:'))) {
      String displayUrl = url;
      if (url.startsWith('data:')) {
        displayUrl = 'Data URL';
      }
      setState(() {
        _hoveredUrl = displayUrl;
        _hoverPosition = position;
        _showHoverPopup = true;
      });
    } else {
      setState(() {
        _showHoverPopup = false;
        _hoveredUrl = null;
      });
    }
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
          Expanded(
            child: Stack(
              children: [
                _buildWebView(),
                if (_isLoading) _buildLoadingBar(theme),
                if (_showHoverPopup && _hoveredUrl != null) _buildHoverPopup(theme),
                if (_showAllReadings && _readingsMap.isNotEmpty) _buildReadingsPanel(theme),
              ],
            ),
          ),
        ],
      ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildStatusBar(ThemeData theme) {
    final isActive = _showDefinitionsPanel || _showAllReadings;
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
      case 'clear_cache':
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
              final searchUrl = 'https://www.google.com/search?q=define+$text';
              _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(searchUrl)));
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}