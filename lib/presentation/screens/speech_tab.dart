import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

    return Column(
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
                icon: _modelLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        recording ? Icons.stop : Icons.mic,
                        size: 18,
                        color: recording ? theme.colorScheme.error : null,
                      ),
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

        // settings row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // engine
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.speechEngine}:',
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: appState.speechEngine,
                    items: const [
                      DropdownMenuItem(
                        value: 'whisper',
                        child: Text('whisper'),
                      ),
                      DropdownMenuItem(
                        value: 'parakeet',
                        child: Text('parakeet'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      appState.setSpeechEngine(v);
                      setState(() {
                        _engine = null;
                        _modelPath = null;
                      });
                      _resolveEngine();
                    },
                  ),
                ],
              ),
              // model
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.speechModel}:',
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: appState.speechModelSize,
                    items: const [
                      DropdownMenuItem(value: 'tiny', child: Text('tiny')),
                      DropdownMenuItem(value: 'base', child: Text('base')),
                      DropdownMenuItem(value: 'small', child: Text('small')),
                      DropdownMenuItem(value: 'medium', child: Text('medium')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      appState.setSpeechModelSize(v);
                      setState(() {
                        _modelPath = null;
                      });
                      _resolveEngine();
                    },
                  ),
                ],
              ),
              // language
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.speechLanguage}:',
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: appState.speechLanguage,
                    items: _languages.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.key == 'auto' ? l10n.speechAuto : e.key,
                              style: TextStyle(fontSize: fs(context, 12)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => appState.setSpeechLanguage(v ?? 'auto'),
                  ),
                ],
              ),
              // sensitivity
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.speechSensitivity}:',
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                  SizedBox(
                    width: 110,
                    child: Slider(
                      value: appState.speechSensitivity.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${appState.speechSensitivity}',
                      onChanged: (v) =>
                          appState.setSpeechSensitivity(v.round()),
                    ),
                  ),
                ],
              ),
              // auto translate
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
              // side by side
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.speechSideBySide,
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
            Row(
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
