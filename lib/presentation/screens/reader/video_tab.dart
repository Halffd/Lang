import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/subtitle_parser.dart';

/// Video player tab.
///
/// Loads a local video and, optionally, a sidecar subtitle track. The
/// transcript doubles as the dictionary surface: tapping a line looks it up
/// through the shared popup dictionary, and the active line follows the
/// playhead.
///
/// Sidecar subtitles only. Streaming needs a video source plugin this app
/// does not depend on, and auto-captions need a speech model that the speech
/// tab already owns, so neither is wired here.
class VideoTab extends StatefulWidget {
  const VideoTab({super.key});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  VideoPlayerController? _video;
  List<SubtitleCue> _cues = const [];
  String? _subLabel;
  String? _error;

  bool _loading = false;
  bool _showTranscript = false;
  int _activeIndex = -1;
  final _transcriptScroll = ScrollController();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _transcriptScroll.dispose();
    _video?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _pickVideo() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.video);
    final file = picked?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _video?.dispose();
        _video = controller;
        _loading = false;
        _activeIndex = -1;
      });
      _startTicker();
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _pickSubtitles() async {
    if (_video == null) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'json', 'txt'],
    );
    final file = picked?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;

    try {
      final raw = await File(path).readAsString();
      final cues = SubtitleParser.parseAuto(raw, filename: file.name);
      if (!mounted) return;
      setState(() {
        _cues = cues;
        _subLabel = file.name;
        _showTranscript = cues.isNotEmpty;
        _activeIndex = -1;
        _error = cues.isEmpty ? 'no cues found in ${file.name}' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Poll the playhead for the active cue. video_player has no cue-change
  /// callback, and a listener per frame is wasteful for a list that only
  /// needs a few checks a second, so this ticks at 200ms.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final v = _video;
      if (v == null || !v.value.isInitialized || !mounted) return;
      final idx = SubtitleParser.indexAtOrBefore(_cues, v.value.position);
      if (idx == _activeIndex) return;
      final wasHidden = _activeIndex < 0 && idx >= 0;
      setState(() => _activeIndex = idx);
      if (wasHidden) _scrollTranscriptTo(idx);
    });
  }

  void _scrollTranscriptTo(int index) {
    if (index < 0 || !_transcriptScroll.hasClients) return;
    // each row is a fixed-height list tile plus the divider, so an estimated
    // extent keeps this independent of text length
    final target = (index * 56.0).clamp(
      0.0,
      _transcriptScroll.position.maxScrollExtent,
    );
    _transcriptScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _seekTo(SubtitleCue cue) async {
    await _video?.seekTo(cue.startDuration);
  }

  /// Look a cue up in the shared popup dictionary. Tries the whole line
  /// first, then falls back to its first token, which is the actionable part
  /// when the line is a whole sentence.
  Future<void> _lookup(SubtitleCue cue) async {
    final text = cue.plainText;
    if (text.isEmpty) return;
    await PopupDictionaryController.instance.showLookupFor(text);
    final first = text
        .split(' ')
        .firstWhere((w) => w.length >= 2, orElse: () => '');
    if (first.isNotEmpty && first != text) {
      await PopupDictionaryController.instance.showLookupFor(first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = _video;

    if (v == null || !v.value.isInitialized) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loading
                        ? (l10n?.videoLoading ?? 'Loading...')
                        : (l10n?.videoNoMedia ??
                              'Pick a video to play with a subtitle track.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(l10n?.videoPickVideo ?? 'Pick video'),
                    onPressed: _loading ? null : _pickVideo,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(v),
              if (_cues.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _ActiveSubtitle(
                    cue: _cues.isNotEmpty && _activeIndex >= 0
                        ? _cues[_activeIndex.clamp(0, _cues.length - 1)]
                        : null,
                    scale: fs(context, 13),
                  ),
                ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: v,
                builder: (context, state, _) => state.isPlaying
                    ? const SizedBox.shrink()
                    : IconButton(
                        iconSize: 64,
                        color: Colors.white70,
                        icon: const Icon(Icons.play_circle_fill),
                        onPressed: () => v.play(),
                      ),
              ),
            ],
          ),
        ),
        VideoProgressIndicator(v, allowScrubbing: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => v.value.isPlaying ? v.pause() : v.play(),
              ),
              Text(
                '${_fmt(v.value.position)} / ${_fmt(v.value.duration)}',
                style: TextStyle(fontSize: fs(context, 12)),
              ),
              const Spacer(),
              if (_cues.isNotEmpty)
                TextButton.icon(
                  icon: Icon(
                    _showTranscript
                        ? Icons.view_list
                        : Icons.closed_caption_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _showTranscript
                        ? (l10n?.videoHideTranscript ?? 'Hide transcript')
                        : (l10n?.videoShowTranscript ?? 'Transcript'),
                  ),
                  onPressed: () =>
                      setState(() => _showTranscript = !_showTranscript),
                ),
              TextButton.icon(
                icon: const Icon(Icons.subtitles_outlined, size: 18),
                label: Text(_subLabel ?? (l10n?.videoLoadSubs ?? 'Load subs')),
                onPressed: _pickSubtitles,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: fs(context, 11),
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_showTranscript) _buildTranscript(l10n, theme),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTranscript(AppLocalizations? l10n, ThemeData theme) {
    if (_cues.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            l10n?.videoNoSubs ?? 'No subtitle track loaded.',
            style: TextStyle(
              fontSize: fs(context, 13),
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: ListView.separated(
        controller: _transcriptScroll,
        itemCount: _cues.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final cue = _cues[i];
          final active = i == _activeIndex;
          return ListTile(
            dense: true,
            selected: active,
            selectedTileColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.25,
            ),
            leading: SizedBox(
              width: 48,
              child: Text(
                _fmt(cue.startDuration),
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            title: Text(
              cue.plainText,
              style: TextStyle(
                fontSize: fs(context, 13),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onTap: () => _seekTo(cue),
            onLongPress: () => _lookup(cue),
          );
        },
      ),
    );
  }
}

/// The cue under the playhead, drawn over the video.
class _ActiveSubtitle extends StatelessWidget {
  const _ActiveSubtitle({required this.cue, required this.scale});

  final SubtitleCue? cue;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final text = cue?.plainText ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: scale),
      ),
    );
  }
}
