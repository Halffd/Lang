import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/audio_service.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/speech_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Speech-to-text tab for the reader screen: live mic recording in
/// chunks or one-shot file transcription through whisper-cli /
/// parakeet-cli, with language selection, auto translate,
/// side-by-side original/translation view, copy, sensitivity and a
/// session log.
class SpeechTab extends StatefulWidget {
  const SpeechTab({super.key, this.service});

  /// Override for tests.
  final SpeechService? service;

  @override
  State<SpeechTab> createState() => _SpeechTabState();
}

class _SpeechTabState extends State<SpeechTab> {
  SpeechService get _service => widget.service ?? SpeechService.instance;

  final List<SpeechSegment> _segments = [];
  bool _transcribing = false;
  bool _modelLoading = false;
  String? _error;
  SpeechEngine? _engine;
  String? _modelPath;

  // live mic sensitivity meter (mimiuchi-style test)
  bool _meterActive = false;
  double _meterLevel = 0;
  StreamSubscription<Duration>? _meterTimer;
  String _activeDevice = '';

  // searchable language list
  String _languageSearch = '';
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _langSearchCtrl = TextEditingController();

  // fade-out timers per segment index
  final Map<int, Timer> _fadeTimers = {};
  final Set<int> _fadedSegments = {};

  // TTS readback
  dynamic _tts; // AudioService lazily created

  AudioService get _audio => _tts ??= AudioService();

  final FocusNode _focusNode = FocusNode();

  // language list for whisper ('auto' + common codes)
  static const Map<String, String> _languages = {
    'auto': '',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'en': 'English',
    'ru': 'Russian',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
  };

  @override
  void initState() {
    super.initState();
    _resolveEngine();
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _langSearchCtrl.dispose();
    _apiKeyCtrl.dispose();
    _focusNode.dispose();
    _meterTimer?.cancel();
    if (_service.isRecording) {
      _service.stopLive(
        engine: _engine ?? SpeechEngine.whisper,
        modelPath: _modelPath ?? '',
        language: 'auto',
        onSegment: (_) {},
      );
    }
    super.dispose();
  }

  // ----------------------------------------------------------
  // live mic sensitivity meter (mimiuchi-style)
  // ----------------------------------------------------------

  Future<void> _toggleMeter() async {
    if (_meterActive) {
      await _stopMeter();
      return;
    }
    final ok = await _service.startMeter((level, device) {
      if (!mounted) return;
      setState(() {
        _meterLevel = level;
        if (device.isNotEmpty) _activeDevice = device;
      });
    });
    if (ok && mounted) setState(() => _meterActive = true);
  }

  Future<void> _stopMeter() async {
    await _service.stopMeter();
    if (mounted) {
      setState(() {
        _meterActive = false;
        _meterLevel = 0;
        _activeDevice = '';
      });
    }
  }

  // ----------------------------------------------------------
  // pinnable language helpers
  // ----------------------------------------------------------

  bool _isPinned(String code) =>
      context.read<AppState>().pinnedSpeechLanguages.contains(code);

  // ----------------------------------------------------------
  // hotkeys (mimiuchi keymap)
  // ----------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (event.logicalKey == LogicalKeyboardKey.enter && !ctrl) {
      _toggleRecord();
      return KeyEventResult.handled;
    }
    if (!ctrl) return KeyEventResult.ignored;

    final langKeys = {
      LogicalKeyboardKey.keyA: 'ja',
      LogicalKeyboardKey.keyS: 'en',
      LogicalKeyboardKey.keyD: 'id',
      LogicalKeyboardKey.keyF: 'zh',
      LogicalKeyboardKey.keyG: 'ko',
      LogicalKeyboardKey.keyH: 'pt',
      LogicalKeyboardKey.keyJ: 'es',
      LogicalKeyboardKey.keyK: 'fr',
      LogicalKeyboardKey.keyL: 'it',
    };
    if (langKeys.containsKey(event.logicalKey)) {
      final code = langKeys[event.logicalKey]!;
      context.read<AppState>().setSpeechLanguage(code);
      return KeyEventResult.handled;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyC:
        _copyAll();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyX:
        setState(_segments.clear);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyT:
        final appState = context.read<AppState>();
        appState.setSpeechAutoTranslate(!appState.speechAutoTranslate);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Searchable + pinnable language picker sheet (mimiuchi-style).
  void _showLanguagePicker() {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final pinned = appState.pinnedSpeechLanguages
              .where(_languages.containsKey)
              .map((c) => MapEntry(c, _languages[c]!))
              .toList();
          final search = _languageSearch.toLowerCase();
          final filtered = _languages.entries
              .where(
                (e) =>
                    !pinned.any((p) => p.key == e.key) &&
                    '${e.value} ${e.key}'.toLowerCase().contains(search),
              )
              .toList();

          Widget langTile(MapEntry<String, String> entry) {
            final selected = appState.speechLanguage == entry.key;
            final isPinned = pinned.any((p) => p.key == entry.key);
            return Card(
              color: selected
                  ? Theme.of(ctx).colorScheme.primaryContainer
                  : Theme.of(ctx).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () {
                  appState.setSpeechLanguage(entry.key);
                  Navigator.pop(ctx);
                },
                title: Row(
                  children: [
                    Expanded(child: Text(entry.value)),
                    IconButton(
                      icon: Icon(
                        isPinned ? Icons.star : Icons.star_outline,
                        size: 18,
                        color: isPinned ? Colors.amber : null,
                      ),
                      onPressed: () {
                        appState.togglePinnedSpeechLanguage(entry.key);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _langSearchCtrl,
                  onChanged: (v) => setSheet(() => _languageSearch = v),
                  decoration: const InputDecoration(
                    hintText: 'Search language',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                if (pinned.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pinned',
                      style: TextStyle(
                        fontSize: fs(context, 11),
                        color: Theme.of(ctx).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [for (final e in pinned) langTile(e)],
                    ),
                  ),
                  const Divider(),
                ],
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [for (final e in filtered) langTile(e)],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _resolveEngine() async {
    final appState = context.read<AppState>();
    final preferred = appState.speechEngine == 'parakeet'
        ? SpeechEngine.parakeet
        : SpeechEngine.whisper;
    final engine = await _service.detectEngine(preferred);
    if (!mounted) return;
    setState(() => _engine = engine);
    if (engine == null) return;

    // model download happens lazily on first use; pre-warm so the
    // record button is instant when engine + network allow
    _modelPath = await _service.ensureModel(
      engine,
      modelSize: appState.speechModelSize,
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecord() async {
    final appState = context.read<AppState>();
    final engine = _engine;
    final model = _modelPath;
    if (engine == null || model == null) {
      await _prepareEngine(appState);
      return;
    }
    final language = appState.speechLanguage;

    if (_service.isRecording) {
      setState(() => _transcribing = true);
      await _service.stopLive(
        engine: engine,
        modelPath: model,
        language: language,
        onSegment: (seg) =>
            _onSegment(seg, translate: appState.speechAutoTranslate),
      );
      if (mounted) setState(() => _transcribing = false);
      return;
    }

    final ok = await _service.startLive(
      engine: engine,
      modelPath: model,
      language: language,
      onSegment: (seg) =>
          _onSegment(seg, translate: appState.speechAutoTranslate),
    );
    if (!ok && mounted) {
      setState(() => _error = 'microphone unavailable');
    }
    if (mounted) setState(() {});
  }

  Future<void> _prepareEngine(AppState appState) async {
    setState(() => _modelLoading = true);
    try {
      final preferred = appState.speechEngine == 'parakeet'
          ? SpeechEngine.parakeet
          : SpeechEngine.whisper;
      final engine = await _service.detectEngine(preferred);
      if (engine == null) {
        if (mounted) setState(() => _error = 'no engine');
        return;
      }
      final model = await _service.ensureModel(
        engine,
        modelSize: appState.speechModelSize,
      );
      if (model == null) {
        if (mounted) setState(() => _error = 'model download failed');
        return;
      }
      if (mounted) {
        setState(() {
          _engine = engine;
          _modelPath = model;
          _error = null;
        });
      }
    } finally {
      if (mounted) setState(() => _modelLoading = false);
    }
  }

  Future<void> _onSegment(SpeechSegment seg, {required bool translate}) async {
    if (!mounted) return;
    setState(() => _segments.add(seg));
    HistoryService.instance.record(
      HistoryCategory.speech,
      seg.text.length > 80 ? seg.text.substring(0, 80) : seg.text,
      subtitle: seg.text,
    );

    final appState = context.read<AppState>();

    // TTS readback of the finalized segment (mimiuchi tts.enabled)
    if (appState.speechTtsReadback && seg.text.trim().isNotEmpty) {
      _audio.play(seg.text, seg.language ?? appState.speechLanguage);
    }

    // fade out old rows once new ones arrive (mimiuchi text.enable_fade)
    if (appState.speechFadeOut && _segments.length > 1) {
      final prevIdx = _segments.length - 2;
      _fadeTimers[prevIdx]?.cancel();
      _fadeTimers[prevIdx] = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _fadedSegments.add(prevIdx));
      });
    }

    if (translate) {
      try {
        final result = await _translate(seg.text);
        if (!mounted) return;
        final i = _segments.indexOf(seg);
        if (i != -1) {
          setState(() => _segments[i] = seg.copyWith(translation: result));
        }
      } catch (_) {
        // translation is best-effort
      }
    }
  }

  Future<String> _translate(String text) async {
    final appState = context.read<AppState>();
    final service = TranslationService();
    final request = TranslationRequest(
      sourceText: text,
      // 'auto' is not a valid source for the translation api; use
      // the detected segment language when present
      sourceLanguage: 'auto',
      targetLanguage: appState.language.isEmpty ? 'en' : appState.language,
    );
    final result = await service.translate(request);
    return result.fullTranslation;
  }

  Future<void> _transcribeFile() async {
    final appState = context.read<AppState>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac', 'ogg', 'm4a'],
    );
    final file = picked?.files.single.path;
    if (file == null) return;

    var engine = _engine;
    var model = _modelPath;
    if (engine == null || model == null) {
      await _prepareEngine(appState);
      engine = _engine;
      model = _modelPath;
      if (engine == null || model == null) return;
    }

    setState(() {
      _transcribing = true;
      _error = null;
    });
    try {
      final language = appState.speechLanguage;
      final (text, lang) = await _service.transcribeFile(
        file,
        engine: engine,
        modelPath: model,
        language: language,
      );
      if (!mounted) return;
      await _onSegment(
        SpeechSegment(
          text: text,
          language: lang,
          startMs: 0,
          endMs: DateTime.now().millisecondsSinceEpoch,
        ),
        translate: appState.speechAutoTranslate,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _copyAll() async {
    final text = _segments.map((s) => s.text).join('\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.speechCopyAll)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final recording = _service.isRecording;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (_handleKey(_focusNode, event) == KeyEventResult.handled) {
          return;
        }
      },
      child: Column(
        children: [
          // controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                // record button
                FilledButton.icon(
                  onPressed: _engine == null || _modelLoading
                      ? null
                      : _toggleRecord,
                  style: FilledButton.styleFrom(
                    backgroundColor: recording
                        ? Colors.green
                        : theme.colorScheme.error.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                  ),
                  icon: _modelLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(recording ? Icons.mic : Icons.mic_off, size: 18),
                  label: Text(
                    recording ? l10n.speechStop : l10n.speechRecord,
                    style: TextStyle(fontSize: fs(context, 13)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _transcribing ? null : _transcribeFile,
                  icon: const Icon(Icons.audio_file, size: 18),
                  label: Text(
                    l10n.speechPickFile,
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: l10n.speechCopyAll,
                  onPressed: _segments.isEmpty ? null : _copyAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  tooltip: l10n.speechClear,
                  onPressed: _segments.isEmpty
                      ? null
                      : () => setState(() => _segments.clear()),
                ),
              ],
            ),
          ),

          // status line
          if (_transcribing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _engine == null ? l10n.speechNoEngine : _error!,
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.error,
                ),
              ),
            ),

          // settings stack (mimiuchi-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- STT engine type
                Row(
                  children: [
                    Text(
                      '${l10n.speechEngine}:',
                      style: TextStyle(fontSize: fs(context, 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'local', label: Text('Local')),
                          ButtonSegment(value: 'api', label: Text('STT API')),
                        ],
                        selected: {appState.sttType},
                        onSelectionChanged: (sel) {
                          appState.setSttType(sel.first);
                          setState(() {
                            _engine = null;
                            _modelPath = null;
                          });
                          _resolveEngine();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // --- API fields
                if (appState.sttType == 'api') ...[
                  TextField(
                    controller: _apiUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      hintText:
                          'https://api.openai.com/v1/audio/transcriptions',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: appState.setSttApiUrl,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: appState.setSttApiKey,
                  ),
                  const SizedBox(height: 10),
                ],

                // --- whisper model (local only)
                if (appState.sttType == 'local')
                  Row(
                    children: [
                      Text(
                        '${l10n.speechModel}:',
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: appState.speechModelSize,
                          isExpanded: true,
                          items: SpeechService.whisperModelTitles.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: TextStyle(fontSize: fs(context, 12)),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            appState.setSpeechModelSize(v);
                            setState(() => _modelPath = null);
                            _resolveEngine();
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // --- sensitivity meter with live mic test
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _toggleMeter,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _meterActive
                            ? theme.colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text(
                        _meterActive ? 'Stop mic test' : 'Test mic',
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _meterLevel,
                          minHeight: 14,
                          backgroundColor: _meterLevel == 0
                              ? theme.colorScheme.surfaceContainerHighest
                              : Colors.green.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _meterLevel > 0.5 ? Colors.orange : Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_activeDevice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _meterActive
                              ? Colors.redAccent
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'device: $_activeDevice',
                            style: TextStyle(
                              fontSize: fs(context, 10),
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                // --- language selector (search + pin)
                Row(
                  children: [
                    Text(
                      '${l10n.speechLanguage}:',
                      style: TextStyle(fontSize: fs(context, 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showLanguagePicker(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isPinned(appState.speechLanguage))
                              Icon(Icons.star, size: 14, color: Colors.amber)
                            else
                              const Icon(Icons.language, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              appState.speechLanguage == 'auto'
                                  ? 'Auto-detect'
                                  : '${appState.speechLanguage}  ·  ${_languages[appState.speechLanguage] ?? ''}',
                              style: TextStyle(fontSize: fs(context, 12)),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // --- auto translate + TTS readback + fade toggles
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.speechAutoTranslate,
                          style: TextStyle(fontSize: fs(context, 12)),
                        ),
                        Switch(
                          value: appState.speechAutoTranslate,
                          onChanged: appState.setSpeechAutoTranslate,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TTS readback',
                          style: TextStyle(fontSize: fs(context, 12)),
                        ),
                        Switch(
                          value: appState.speechTtsReadback,
                          onChanged: appState.setSpeechTtsReadback,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Side-by-side',
                          style: TextStyle(fontSize: fs(context, 12)),
                        ),
                        Switch(
                          value: appState.speechSideBySide,
                          onChanged: appState.setSpeechSideBySide,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 1),

          // transcript
          Expanded(
            child: _segments.isEmpty
                ? Center(
                    child: Text(
                      l10n.speechEmpty,
                      style: TextStyle(
                        fontSize: fs(context, 12),
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : appState.speechSideBySide
                ? _buildSideBySide(theme)
                : _buildStacked(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStacked(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final seg = _segments[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: _fadedSegments.contains(index) ? 0.35 : 1.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmtClock(seg.startMs),
                      style: TextStyle(
                        fontSize: fs(context, 10),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      seg.text,
                      style: TextStyle(
                        fontSize: fs(context, 14, 'sentences'),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (seg.translation != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 2),
                child: SelectableText(
                  seg.translation!,
                  style: TextStyle(
                    fontSize: fs(context, 12, 'translations'),
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildSideBySide(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth > 600;
        final left = _segments.map((s) => s.text).join('\n\n');
        final right = _segments.map((s) => s.translation ?? '…').join('\n\n');
        if (!twoCols) {
          // narrow: fall back to stacked view
          return _buildStacked(theme);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  left,
                  style: TextStyle(
                    fontSize: fs(context, 14, 'sentences'),
                    height: 1.6,
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  right,
                  style: TextStyle(
                    fontSize: fs(context, 12, 'translations'),
                    height: 2.05,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmtClock(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
