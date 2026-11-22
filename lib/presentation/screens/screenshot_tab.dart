import 'dart:async';
import 'dart:io';

import 'package:lang/presentation/widgets/app_context_menu.dart';
import 'package:lang/presentation/widgets/screenshot_manager.dart';
import 'package:lang/presentation/widgets/screenshot_ref_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/image_clipboard_service.dart';
import 'package:lang/core/services/live_ocr/live_ocr_controller.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/data/datasources/local_translation_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';
import 'package:lang/presentation/screens/settings_screen.dart';
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

/// One OCR result the screen produced.
///
/// The transcription history keeps these: the text, the engine that
/// produced it, when it was produced and the screenshot it belongs to
/// (null for a screen-content search, which is not stored).
class OcrTranscript {
  final String text;

  /// The engine that produced the text (its enum name).
  final String engine;

  /// The language the text was recognized in.
  final String language;

  final DateTime time;

  /// The screenshot this came from, when there is one.
  final String? itemId;

  const OcrTranscript({
    required this.text,
    required this.engine,
    required this.language,
    required this.time,
    this.itemId,
  });
}

/// The OCR details of a screenshot: which backend read it, in which
/// language, and when.
class OcrDetails {
  final String engine;
  final String language;
  final DateTime time;

  const OcrDetails({
    required this.engine,
    required this.language,
    required this.time,
  });
}

/// One labelled value in the OCR details block.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fs(context, 12),
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: fs(context, 12))),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotTabState extends State<ScreenshotTab> {
  /// Source languages offered for OCR. Empty in [AppState.ocrLanguage] means
  /// "follow the app learning language", which is what [_runOcr] passes to
  /// the recognizer.
  static const _ocrLanguages = <String>[
    'auto',
    'en',
    'ja',
    'zh',
    'ko',
    'fr',
    'de',
    'es',
  ];

  /// The stored engine name, or the platform default when unset/unknown
  /// so the dropdown always has a valid value.
  String _engineValue(String stored) =>
      OcrEngine.values.any((e) => e.name == stored)
      ? stored
      : OcrService.engineFromName(null).name;

  /// Whether [engine] can run here. ML Kit has no desktop build, so
  /// picking it there would silently produce no text.
  bool _engineAvailable(OcrEngine engine) {
    if (engine == OcrEngine.mlKit) return OcrService.isMlKitAvailable;
    // the ai engine needs the search screen's provider, which this
    // tab cannot reach
    if (engine == OcrEngine.ai) return false;
    return true;
  }

  /// The friendly name of an OCR backend.
  static String _backendLabel(AppLocalizations l10n, OcrEngine engine) {
    return switch (engine) {
      OcrEngine.mlKit => l10n.ocrBackendMlKit,
      OcrEngine.tesseract => l10n.ocrBackendTesseract,
      OcrEngine.easyOcr => l10n.ocrBackendEasyOcr,
      OcrEngine.transformers => l10n.ocrBackendTransformers,
      OcrEngine.huggingFace => l10n.ocrBackendHuggingFace,
      OcrEngine.ai => l10n.ocrBackendAi,
      OcrEngine.api => l10n.ocrBackendApi,
    };
  }

  /// What an OCR backend does, so the dropdown explains the choice
  /// instead of only naming it.
  static String _backendDescription(
    AppLocalizations l10n,
    OcrEngine engine,
  ) {
    final desc = switch (engine) {
      OcrEngine.mlKit => l10n.ocrBackendMlKitDesc,
      OcrEngine.tesseract => l10n.ocrBackendTesseractDesc,
      OcrEngine.easyOcr => l10n.ocrBackendEasyOcrDesc,
      OcrEngine.transformers => l10n.ocrBackendTransformersDesc,
      OcrEngine.huggingFace => l10n.ocrBackendHuggingFaceDesc,
      OcrEngine.ai => l10n.ocrBackendAiDesc,
      OcrEngine.api => l10n.ocrBackendApiDesc,
    };
    // the unavailable ones say why, in the same line
    final reason = _unavailableReason(l10n, engine);
    return reason == null ? desc : '$desc ($reason)';
  }

  /// Why an OCR backend cannot run here, or null when it can.
  static String? _unavailableReason(
    AppLocalizations l10n,
    OcrEngine engine,
  ) {
    if (engine == OcrEngine.ai) return l10n.ocrEngineAiUnavailable;
    if (engine == OcrEngine.mlKit && !OcrService.isMlKitAvailable) {
      return l10n.ocrEngineMlKitUnavailable;
    }
    return null;
  }

  ScreenshotService get _service =>
      widget.service ?? ScreenshotService.instance;
  bool _isCapturing = false;
  int _monitor = 0;
  int _monitorCount = 1;

  /// The monitors this machine has, for the monitor picker. Empty
  /// until the probe finishes.
  List<ScreenshotMonitor> _monitors = const [];

  /// The bytes of the live screen preview (a transient capture that is
  /// never stored in the album).
  Uint8List? _screenPreview;

  /// Whether the screen preview is being refreshed.
  bool _isPreviewing = false;

  /// The OCR text of each captured item, keyed by item id.
  ///
  /// The service holds the text too, but the tab keeps its own copy so
  /// the history list can show the OCR result and the details without
  /// an extra lookup per row.
  final Map<String, String> _ocrTexts = {};

  /// The engine each item was recognized with, keyed by item id.
  final Map<String, String> _ocrEngines = {};

  /// The transcription history: every OCR result the tab produced, in
  /// order. Each entry keeps the text, the item it came from (if any)
  /// and the time it was produced.
  final List<OcrTranscript> _transcripts = [];

  /// Whether the screen-content search is running: it captures the
  /// screen and reads it, which takes a moment.
  bool _isSearchingScreen = false;

  @override
  void initState() {
    super.initState();
    _service.load();
    _refreshMonitors();
    _refreshPreview();
  }

  /// Re-probe the monitors so the picker lists every connected output.
  Future<void> _refreshMonitors() async {
    final list = await _service.monitors();
    if (!mounted) return;
    setState(() {
      _monitors = list;
      _monitorCount = list.isEmpty ? 1 : list.length;
      // the selected monitor may have gone away
      if (_monitor >= _monitorCount) _monitor = 0;
    });
  }

  /// Capture the screen without storing it and show it as the preview.
  ///
  /// The preview is the current screen, so it is refreshed whenever
  /// the tab becomes visible; the second-to-last *captured* screenshot
  /// is shown next to it from the album.
  Future<void> _refreshPreview() async {
    if (_isPreviewing) return;
    setState(() => _isPreviewing = true);
    try {
      final bytes = await _service.captureTransient(ScreenshotKind.fullscreen);
      if (!mounted) return;
      setState(() => _screenPreview = bytes);
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
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
      ocrRunner: (path) => _runOcr(path),
      copyImageRunner: _copyImageToClipboard,
      copyTextRunner: (text) async {
        await Clipboard.setData(ClipboardData(text: text));
      },
      autoTranslate: appState.screenshotAutoTranslate,
      translateRunner: (text) => _translateOcr(text),
    );

    if (!mounted) return;
    setState(() => _isCapturing = false);
    // the capture pipeline stores the OCR text on the item; the tab
    // records it in its own history so the transcriptions tab and the
    // list's OCR details have it.
    if (item != null && item.ocrText != null && item.ocrText!.isNotEmpty) {
      _recordTranscript(item, appState);
    }
    // the preview shows the screen as it is now, which has changed
    // since the capture
    unawaited(_refreshPreview());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null ? l10n.screenshotFailed : l10n.screenshotCaptured,
        ),
      ),
    );
  }

  /// Record the OCR result of [item] in the tab's transcription
  /// history and remember which engine produced it.
  void _recordTranscript(ScreenshotItem item, AppState appState) {
    final text = item.ocrText;
    if (text == null || text.isEmpty) return;
    final engine = _resolveEngine(appState);
    setState(() {
      _ocrTexts[item.id] = text;
      _ocrEngines[item.id] = engine.name;
      _transcripts.insert(
        0,
        OcrTranscript(
          text: text,
          engine: engine.name,
          language: _ocrLanguage(appState),
          time: item.time,
          itemId: item.id,
        ),
      );
    });
  }

  Future<void> _copyImageToClipboard(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final ok = await ImageClipboardService.copyPng(bytes);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.copyFailed),
          ),
        );
      }
    } catch (_) {
      // clipboard write is best-effort
    }
  }

  /// The OCR engine this screen uses, with the unusable ones replaced
  /// by the platform default.
  ///
  /// The `ai` engine needs the AI provider from the search screen's
  /// context, which this tab cannot reach.
  OcrEngine _resolveEngine(AppState appState) {
    var engine = OcrService.engineFromName(appState.ocrEngine);
    if (engine == OcrEngine.ai) engine = OcrService.engineFromName(null);
    return OcrService.resolveEngine(engine);
  }

  /// The language the OCR runs in: 'auto'/empty follows the app
  /// learning language.
  String _ocrLanguage(AppState appState) {
    final lang = appState.ocrLanguage;
    return (lang.isEmpty || lang == 'auto') ? appState.learningLanguage : lang;
  }

  Future<String?> _runOcr(String path) async {
    final appState = context.read<AppState>();
    final engine = _resolveEngine(appState);
    final language = _ocrLanguage(appState);
    final ocrService = OcrService();
    try {
      if (appState.ocrApiEndpoint.isNotEmpty) {
        ocrService.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await ocrService.recognizeFromFile(
        path,
        engine: engine,
        language: language,
        apiKey: appState.ocrApiKey,
      );
      return result.isSuccess ? result.text : null;
    } catch (_) {
      return null;
    } finally {
      ocrService.dispose();
    }
  }

  /// Translate recognised text into the app learning language. Returns null
  /// on any failure so the caller keeps the untranslated OCR text.
  Future<String?> _translateOcr(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geminiKey = prefs.getString('geminiApiKey') ?? '';
      if (!mounted) return null;
      final appState = context.read<AppState>();
      final service = TranslationService(
        localService: LocalTranslationService(),
        geminiApiKey: geminiKey.isNotEmpty ? geminiKey : null,
        provider: appState.translationProvider,
      );
      final source = appState.ocrLanguage;
      final result = await service.translate(
        TranslationRequest(
          sourceText: text,
          sourceLanguage: (source.isEmpty || source == 'auto')
              ? appState.learningLanguage
              : source,
          targetLanguage: appState.learningLanguage,
        ),
      );
      return result.fullTranslation;
    } catch (_) {
      return null;
    }
  }

  /// OCR popup auto-lookup: called when auto-ocr toggle is on and OCR
  /// produced text. We pick the first token and open the popup.
  Future<void> _ocrAutoPopup(String text) async {
    final config = PopupDictionaryController.instance.config;
    if (!config.autoOcrPopup) return;
    if (text.trim().isEmpty) return;
    // First meaningful CJK word (>=2 chars), else the first token.
    final words = text
        .split(RegExp(r'\s+|\n'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .toList();
    if (words.isEmpty) return;
    final word = words.first;
    await PopupDictionaryController.instance.showLookupFor(word);
  }

  /// Capture the screen, read it with OCR and search the words it
  /// contains.
  ///
  /// The capture is transient: it is not added to the screenshot
  /// album, because the user asked for a search, not for a picture.
  /// The text is handed to the analyze screen, which splits it into
  /// words and looks each one up.
  Future<void> _searchScreenContent() async {
    if (_isSearchingScreen) return;
    final l10n = AppLocalizations.of(context)!;
    // read the settings before the first await: the context must not
    // be used across an async gap
    final appState = context.read<AppState>();
    setState(() => _isSearchingScreen = true);

    try {
      final bytes = await _service.captureTransient(ScreenshotKind.fullscreen);
      if (bytes == null) {
        if (mounted) _showMessage(l10n.searchScreenContentFailed);
        return;
      }

      var engine = OcrService.engineFromName(appState.ocrEngine);
      // the ai engine needs the AI provider, which this tab cannot
      // reach; fall back to the platform default engine
      if (engine == OcrEngine.ai) engine = OcrService.engineFromName(null);

      final lang = appState.ocrLanguage;
      final language = (lang.isEmpty || lang == 'auto')
          ? appState.learningLanguage
          : lang;

      final ocrService = OcrService();
      final String text;
      try {
        if (appState.ocrApiEndpoint.isNotEmpty) {
          ocrService.apiEndpoint = appState.ocrApiEndpoint;
        }
        final result = await ocrService.recognizeFromBytes(
          bytes,
          engine: engine,
          language: language,
          apiKey: appState.ocrApiKey,
        );
        text = result.isSuccess ? result.text : '';
      } finally {
        ocrService.dispose();
      }

      if (!mounted) return;
      if (text.trim().isEmpty) {
        _showMessage(l10n.searchScreenContentEmpty);
        return;
      }

      final query = text.trim();
      AnalyzeScreen.pendingText = query;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AnalyzeScreen()),
      );
    } catch (e) {
      if (mounted) _showMessage(l10n.searchScreenContentFailed);
    } finally {
      if (mounted) setState(() => _isSearchingScreen = false);
    }
  }

  /// Show a short message at the bottom of the screen.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// The OCR details of [item], or null when it has no OCR text.
  ///
  /// The engine comes from what the tab recorded when the item was
  /// captured; for an item captured in an earlier session there is no
  /// record, so the current setting stands in for it.
  OcrDetails? _ocrDetailsFor(ScreenshotItem item, AppState appState) {
    final text = item.ocrText;
    if (text == null || text.isEmpty) return null;
    final engineName = _ocrEngines[item.id];
    final engine = engineName == null
        ? _resolveEngine(appState)
        : OcrService.engineFromName(engineName);
    return OcrDetails(
      engine: _backendLabel(AppLocalizations.of(context)!, engine),
      language: _ocrLanguage(appState),
      time: item.time,
    );
  }

  Future<void> _showItem(ScreenshotItem item) async {
    final appState = context.read<AppState>();
    final details = _ocrDetailsFor(item, appState);
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
          ocrDetails: details,
          onCopyText: item.ocrText != null
              ? () async {
                  await Clipboard.setData(ClipboardData(text: item.ocrText!));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              : null,
          onCopyImage: () async {
            // blob-stored screenshots have no file path: materialize
            // one before handing it to the clipboard writer
            final path = await _service.materializePath(item);
            if (path != null) await _copyImageToClipboard(path);
            if (context.mounted) Navigator.pop(context);
          },
          onDelete: () {
            _service.remove(item.id);
            Navigator.pop(context);
          },
          onCopyPath: () {
            Clipboard.setData(ClipboardData(text: item.path));
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
        // The controls above the history take a fixed amount of space.
        // They are scrollable so a short window cannot squeeze the
        // history list down to nothing: the options would push the
        // tab bar out of view and the list would overflow.
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
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
            child: Row(
              children: [
                Icon(
                  Icons.desktop_windows,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    key: const Key('monitorDropdown'),
                    isExpanded: true,
                    value: _monitor.clamp(0, _monitorCount - 1),
                    items: List.generate(_monitorCount, (i) {
                      final m = i < _monitors.length ? _monitors[i] : null;
                      return DropdownMenuItem(
                        value: i,
                        child: Text(m?.label ?? 'Monitor $i'),
                      );
                    }),
                    onChanged: (v) => setState(() => _monitor = v ?? 0),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (_isCapturing) const LinearProgressIndicator(),

        // the current screen, so the user sees what a capture will
        // take before taking it, and the capture before the latest one
        const SizedBox(height: 8),
        _buildPreviewPanel(context, l10n, theme),
        const SizedBox(height: 8),

        // live OCR: the continuous read-the-screen loop. Its state has
        // to be visible here — the toggle lives in the settings screen,
        // and this is the screen the user comes to when the OCR is not
        // doing what they expect.
        _buildLiveOcrSection(context, appState, theme),
        const SizedBox(height: 8),

        // search the screen: capture it, read it, look the words up
        _buildSearchScreenContentButton(context, l10n, theme),
        const SizedBox(height: 8),

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
        ListTile(
          dense: true,
          title: Text(
            l10n.ocrEngine,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                key: const Key('ocrEngineDropdown'),
                value: _engineValue(appState.ocrEngine),
                // the dropdown sits in the subtitle slot, which is
                // full-width: `isExpanded` makes the menu use it
                isExpanded: true,
                dropdownColor: theme.colorScheme.surfaceContainerHighest,
                underline: const SizedBox.shrink(),
                items: [
                  for (final e in OcrEngine.values)
                    DropdownMenuItem(
                      value: e.name,
                      enabled: _engineAvailable(e),
                      // one line only: the menu item has a fixed
                      // height that a second line would overflow
                      child: Text(
                        _engineAvailable(e)
                            ? _backendLabel(l10n, e)
                            : '${_backendLabel(l10n, e)} '
                                  '(${_unavailableReason(l10n, e)})',
                        style: TextStyle(fontSize: fs(context, 13)),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  appState.setOcrEngine(v);
                },
              ),
              // what the selected backend does, and why the ones that
              // cannot run here are marked
              Text(
                _backendDescription(
                  l10n,
                  OcrService.engineFromName(
                    _engineValue(appState.ocrEngine),
                  ),
                ),
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          dense: true,
          title: Text(
            l10n.ocrLanguage,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          trailing: DropdownButton<String>(
            value: _ocrLanguages.contains(appState.ocrLanguage)
                ? appState.ocrLanguage
                : '',
            items: [
              DropdownMenuItem(value: '', child: Text(l10n.ocrLanguageAuto)),
              for (final code in _ocrLanguages)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: (v) {
              if (v == null) return;
              appState.setOcrLanguage(v);
            },
          ),
        ),
        SwitchListTile(
          dense: true,
          title: Text(
            l10n.autoTranslateOcr,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          value: appState.screenshotAutoTranslate,
          onChanged: appState.screenshotAutoOcr
              ? (v) => appState.setScreenshotAutoTranslate(v)
              : null,
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
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // history + album
        Expanded(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final items = _service.items;
              return DefaultTabController(
                length: 4,
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
                              Tab(
                                icon: Icon(Icons.subject, size: 18),
                                text: l10n.screenshotTranscriptions,
                              ),
                              Tab(
                                icon: Icon(Icons.tune, size: 18),
                                text: l10n.screenshotManager,
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
                          // transcriptions: every OCR result, as text
                          _buildTranscriptionList(),
                          // manager: filter, sort and per-item actions
                          ScreenshotManager(service: _service),
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

  /// The live-OCR row: a running/stopped indicator with the toggle,
  /// so the OCR screen shows whether the continuous read is on.
  /// The live preview of the screen, with a refresh button.
  ///
  /// It shows the frame a full-screen capture would take right now.
  /// The capture itself is still what stores the screenshot; this only
  /// shows what is on screen.
  Widget _buildPreviewPanel(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final preview = _screenPreview;
    // the second-to-last capture: the list is newest-first, so the
    // one before the newest is at index 1
    final items = _service.items;
    final previous = items.length >= 2 ? items[1] : null;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.screenshotPreview,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('refreshPreviewButton'),
                  tooltip: l10n.screenshotPreviewRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _isPreviewing ? null : () => _refreshPreview(),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                // the preview is a glance, not the main content: it
                // must not push the capture buttons off the screen
                constraints: const BoxConstraints(maxHeight: 180),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: preview == null
                      ? ColoredBox(
                          color: Colors.black12,
                          child: Center(
                            // a static placeholder, not a spinner: an
                            // endless animation here would keep the
                            // screen from ever settling
                            child: Icon(
                              Icons.desktop_windows_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : Image.memory(
                          preview,
                          key: const Key('screenPreviewImage'),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            // the capture before the latest one, so the user can see
            // what they took last
            if (previous != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.screenshotPreviousCapture,
                      style: TextStyle(
                        fontSize: fs(context, 13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ScreenshotRefImage(
                      key: const Key('previousCaptureImage'),
                      ref: previous.path,
                      fit: BoxFit.contain,
                      cacheWidth: 640,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The live-OCR controller, or null when it is not in the tree.
  ///
  /// The lookup has to be for the non-nullable type: provider matches
  /// the requested type exactly, so `watch<LiveOcrController?>()` does
  /// not find a `LiveOcrController` and silently yields null. The
  /// null case is the one where the controller is absent (tests that
  /// pump the tab on their own).
  LiveOcrController? _liveOcrController(BuildContext context) {
    try {
      return context.watch<LiveOcrController>();
    } catch (_) {
      return null;
    }
  }

  Widget _buildLiveOcrSection(
    BuildContext context,
    AppState appState,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // The controller is registered as a non-nullable `LiveOcrController`.
    // Asking for `LiveOcrController?` looks up a *different* type, finds
    // nothing and yields null — which is why the switch did nothing.
    // The lookup is wrapped so tests that pump the tab without the app
    // still work.
    final controller = _liveOcrController(context);
    final unsupported = controller?.isUnsupported ?? false;
    // The switch shows the setting; the status line says whether the
    // loop is actually running. They differ while the loop waits for
    // the machine to be checked, so both are shown.
    final on = appState.liveOcrEnabled;
    final running = controller?.isRunning ?? false;
    final enabled = on && !unsupported;
    // the text the loop currently reads, so the user sees the result
    // here instead of having to find the floating overlay
    final liveText = controller?.stableText ?? '';

    final statusColor = running
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  running ? Icons.fiber_manual_record : Icons.circle_outlined,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.liveOcrSection,
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        unsupported
                            ? l10n.liveOcrUnsupported
                            : (running
                                  ? l10n.liveOcrRunning
                                  : l10n.liveOcrStopped),
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.liveOcrOpenSettings,
                  icon: const Icon(Icons.tune, size: 18),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                Switch(
                  key: const Key('liveOcrSwitch'),
                  value: enabled,
                  onChanged: unsupported
                      ? null
                      : (v) {
                          appState.setLiveOcrEnabled(v);
                          controller?.applyEnabledSetting();
                        },
                ),
              ],
            ),
            // the live text the loop reads: without it the toggle
            // looks like it does nothing
            if (running && liveText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: SelectableText(
                  liveText,
                  maxLines: 3,
                  style: TextStyle(fontSize: fs(context, 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The screen-content search button: capture the screen, read it
  /// with OCR and look the words up.
  Widget _buildSearchScreenContentButton(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isSearchingScreen ? null : _searchScreenContent,
          icon: _isSearchingScreen
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.manage_search, size: 18),
          label: Text(
            l10n.searchScreenContent,
            style: TextStyle(fontSize: fs(context, 12)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            l10n.searchScreenContentHint,
            style: TextStyle(
              fontSize: fs(context, 10),
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  /// The transcription history: every OCR result the tab produced, as
  /// plain text.
  ///
  /// It is the place to copy a result from, and to see which backend
  /// and language produced it.
  Widget _buildTranscriptionList() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (_transcripts.isEmpty) {
      return Center(
        child: Text(
          l10n.screenshotNoTranscriptions,
          style: TextStyle(
            fontSize: fs(context, 13),
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _transcripts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = _transcripts[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.subject),
          title: SelectableText(
            t.text,
            maxLines: 3,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
          subtitle: Text(
            '${_backendName(t.engine)} · ${t.language} · '
            '${DateFormat.Hms().format(t.time)}',
            style: TextStyle(
              fontSize: fs(context, 11),
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: IconButton(
            key: Key('copyTranscript_$index'),
            tooltip: l10n.screenshotCopyOcrResult,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: t.text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.copied)),
              );
            },
          ),
        );
      },
    );
  }

  /// The friendly name of an engine name recorded in a transcript.
  String _backendName(String engineName) {
    for (final e in OcrEngine.values) {
      if (e.name == engineName) {
        return _backendLabel(AppLocalizations.of(context)!, e);
      }
    }
    return engineName;
  }

  /// The right-click menu of a screenshot: copy the image, copy the
  /// path, copy the OCR text, and delete it.
  List<Widget> _itemMenuChildren(ScreenshotItem item) {
    final l10n = AppLocalizations.of(context)!;
    return [
      MenuItemButton(
        onPressed: () => _copyItemImage(item),
        leadingIcon: const Icon(Icons.image, size: 18),
        child: Text(l10n.screenshotCopyImageItem),
      ),
      MenuItemButton(
        onPressed: () => _copyItemPath(item),
        leadingIcon: const Icon(Icons.folder_outlined, size: 18),
        child: Text(l10n.screenshotCopyPathItem),
      ),
      if (item.ocrText != null && item.ocrText!.isNotEmpty)
        MenuItemButton(
          onPressed: () => _copyItemText(item),
          leadingIcon: const Icon(Icons.copy, size: 18),
          child: Text(l10n.screenshotCopyOcrResult),
        ),
      MenuItemButton(
        onPressed: () => _service.remove(item.id),
        leadingIcon: const Icon(Icons.delete_outline, size: 18),
        child: Text(l10n.delete),
      ),
    ];
  }

  /// Wrap [child] in a right-click menu with [menuChildren].
  ///
  /// The Flutter SDK in use has no `ContextMenuButton`, so the menu is
  /// a [MenuAnchor] opened by a secondary tap. The anchor is opened
  /// and closed through its controller.
  Widget _withItemMenu({
    required Widget child,
    required List<Widget> menuChildren,
  }) {
    return MenuAnchor(
      menuChildren: menuChildren,
      builder: (context, menuController, _) => GestureDetector(
        // the secondary tap opens the menu; the primary tap still
        // reaches the child
        onSecondaryTapDown: (details) {
          menuController.open(position: details.globalPosition);
        },
        child: child,
      ),
    );
  }

  /// Copy the screenshot's image to the clipboard.
  Future<void> _copyItemImage(ScreenshotItem item) async {
    // blob-stored screenshots have no file path: materialize one
    // before handing it to the clipboard writer
    final path = await _service.materializePath(item);
    if (path == null) return;
    await _copyImageToClipboard(path);
  }

  /// Copy the screenshot's path to the clipboard.
  Future<void> _copyItemPath(ScreenshotItem item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.copied)));
  }

  /// Copy the screenshot's recognized text to the clipboard.
  Future<void> _copyItemText(ScreenshotItem item) async {
    final text = item.ocrText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.copied)));
  }

  Widget _buildHistoryList(List<ScreenshotItem> items) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.noScreenshots,
          style: TextStyle(
            fontSize: fs(context, 13),
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
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
        final details = _ocrDetailsFor(item, appState);
        return _withItemMenu(
          menuChildren: _itemMenuChildren(item),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.image),
            title: Text(kindLabel, style: TextStyle(fontSize: fs(context, 13))),
            subtitle: _buildItemDescription(item, details),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _service.remove(item.id),
            ),
            onTap: () => _showItem(item),
          ),
        );
      },
    );
  }

  /// The description under each item in the list.
  ///
  /// It carries everything the user needs to identify the screenshot:
  /// the time, the recognized text, the OCR details, the file size and
  /// resolution, the file name and the full path.
  Widget _buildItemDescription(ScreenshotItem item, OcrDetails? details) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ocrText = item.ocrText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.yMd().add_jms().format(item.time),
          style: TextStyle(
            fontSize: fs(context, 11),
            color: theme.colorScheme.outline,
          ),
        ),
        if (ocrText != null && ocrText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            ocrText.length > 160 ? '${ocrText.substring(0, 160)}…' : ocrText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fs(context, 11)),
          ),
        ],
        if (details != null) ...[
          const SizedBox(height: 2),
          Text(
            '${l10n.screenshotOcrEngine}: ${details.engine} · '
            '${l10n.screenshotOcrLanguage}: ${details.language}',
            style: TextStyle(
              fontSize: fs(context, 10),
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        // the file facts: size, resolution and dimensions
        FutureBuilder<List<Object?>>(
          future: _itemFileFacts(item),
          builder: (context, snapshot) {
            final facts = snapshot.data;
            if (facts == null) return const SizedBox.shrink();
            final size = facts[0] as String;
            final resolution = facts[1] as String?;
            final dimensions = facts[2] as String?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Text(
                  [
                    size,
                    ?resolution,
                    ?dimensions,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: fs(context, 10),
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        // the file name and the full path
        Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fs(context, 10)),
        ),
        Text(
          item.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fs(context, 10),
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// The file size, the resolution and the pixel dimensions of
  /// [item], read from the stored file.
  Future<List<Object?>> _itemFileFacts(ScreenshotItem item) async {
    final sizeBytes = await _service.fileSize(item);
    final size = _formatBytes(sizeBytes);
    final dimensions = await _service.imageSize(item);
    if (dimensions == null) return [size, null, null];
    final width = dimensions.width;
    final height = dimensions.height;
    // the resolution is the megapixel count, the dimensions are the
    // exact pixel size
    final megapixels = (width * height) / 1000000;
    final resolution = '${megapixels.toStringAsFixed(1)} MP';
    final dimensionText = '$width×$height';
    return [size, resolution, dimensionText];
  }

  /// A human-readable file size.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  Widget _buildAlbumGrid(List<ScreenshotItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          // the history tab already shows "no screenshots"; the album
          // needs its own wording so the two are not the same sentence
          AppLocalizations.of(context)!.screenshotAlbumEmpty,
          style: TextStyle(
            fontSize: fs(context, 13),
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _withItemMenu(
          menuChildren: _itemMenuChildren(item),
          child: InkWell(
            onTap: () => _showItem(item),
            // cacheWidth decodes at thumbnail size: a 4K screenshot decoded
            // at full resolution is ~33 MB of pixels; at 320px it is ~0.4 MB.
            // Without this, a grid of screenshots consumes GBs of RAM.
            child: ScreenshotRefImage(
              ref: item.path,
              fit: BoxFit.cover,
              cacheWidth: 320,
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
          final ocrPath =
              await widget.service?.materializePath(item) ?? item.path;
          final text = await _runOcr(ocrPath);
          if (text != null && text.trim().isNotEmpty) {
            _service.setOcrText(item.id, text.trim());
            await _ocrAutoPopup(text);
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

  /// Copies the screenshot's path to the clipboard.
  final VoidCallback onCopyPath;

  /// The OCR details of this item: which backend produced the text,
  /// in which language, and when.
  final OcrDetails? ocrDetails;

  const _ItemSheet({
    required this.item,
    required this.scrollController,
    required this.onCopyText,
    required this.onCopyImage,
    required this.onDelete,
    required this.onCopyPath,
    this.ocrDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                  DateFormat.yMd().add_jms().format(item.time),
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.ocrText != null && item.ocrText!.isNotEmpty) ...[
                  SelectableText(
                    contextMenuBuilder: AppContextMenu.editable,
                    item.ocrText!,
                    style: TextStyle(fontSize: fs(context, 13)),
                  ),
                  const SizedBox(height: 8),
                ],
                // the OCR details: which backend read the image, in
                // which language, and when
                if (ocrDetails != null) ...[
                  Text(
                    l10n.screenshotOcrDetails,
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _DetailRow(
                    label: l10n.screenshotOcrEngine,
                    value: ocrDetails!.engine,
                  ),
                  _DetailRow(
                    label: l10n.screenshotOcrLanguage,
                    value: ocrDetails!.language,
                  ),
                  _DetailRow(
                    label: l10n.screenshotOcrTime,
                    value: DateFormat.yMd().add_jms().format(ocrDetails!.time),
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
                        label: Text(
                          l10n.screenshotCopyOcrResult,
                          style: TextStyle(fontSize: fs(context, 12)),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: onCopyImage,
                      icon: const Icon(Icons.image, size: 16),
                      label: Text(
                        l10n.screenshotCopyImageItem,
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onCopyPath,
                      icon: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(
                        l10n.screenshotCopyPathItem,
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(
                        l10n.delete,
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
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

