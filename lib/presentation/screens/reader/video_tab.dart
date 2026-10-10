import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/core/services/youtube_resolver.dart';
import 'package:lang/core/services/youtube_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/subtitle_parser.dart';

/// Video player tab.
///
/// Port of jidoujisho's player, trimmed to the media feature: local files
/// and YouTube playback with sidecar or closed-caption subtitle tracks.
/// The transcript doubles as the dictionary surface: tapping a line looks
/// it up through the shared popup dictionary, and the active line follows
/// the playhead.
///
/// Playback speed, subtitle size and subtitle delay persist through
/// AppState. YouTube playback resolves muxed streams, so quality tops out
/// at what YouTube muxes (typically 360p); auto-captions come from the
/// video's own caption tracks.
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

  /// What is loaded: a filename for local media, `title · author` for
  /// YouTube. Shown under the video.
  String? _mediaLabel;

  /// Non-null when the source is YouTube, enabling the captions picker.
  String? _youtubeVideoId;

  bool _loading = false;
  bool _showTranscript = false;
  int _activeIndex = -1;
  final _transcriptScroll = ScrollController();
  Timer? _ticker;

  /// yt-dlp when installed, youtube_explode otherwise.
  final _youtube = YouTubeResolver();

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

  /// Swap in a fully initialized controller, keeping the customization
  /// (speed) the user already set.
  Future<void> _adopt(VideoPlayerController controller) async {
    await controller.setLooping(false);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    final appState = context.read<AppState>();
    await controller.setPlaybackSpeed(appState.videoPlaybackSpeed);
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
  }

  Future<void> _openLocal() async {
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _adopt(controller);
      setState(() {
        _mediaLabel = file.name;
        _youtubeVideoId = null;
        _cues = const [];
        _subLabel = null;
        _showTranscript = false;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openYouTube() async {
    final l10n = AppLocalizations.of(context);
    final url = await _promptYouTubeUrl();
    if (url == null || url.trim().isEmpty || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await _youtube.resolve(url.trim());
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _loading = false;
          _error = l10n?.videoInvalidUrl ?? 'Not a YouTube video.';
        });
        return;
      }
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(info.best.url),
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _adopt(controller);
      setState(() {
        _mediaLabel = info.displayLabel;
        _youtubeVideoId = info.videoId;
        _cues = const [];
        _subLabel = null;
        _showTranscript = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Ask for a YouTube URL. Returns the trimmed input, or null on cancel.
  Future<String?> _promptYouTubeUrl() async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.videoYouTube ?? 'YouTube'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: l10n?.videoYouTubeHint ?? 'Paste a YouTube URL',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: Text(l10n?.videoLoad ?? 'Load'),
          ),
        ],
      ),
    );
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

  /// Load one of the YouTube video's own caption tracks as the subtitle
  /// source. Only offered for YouTube media.
  Future<void> _pickCaptions() async {
    final videoId = _youtubeVideoId;
    if (videoId == null || _loading) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await _youtube.captionTracks(videoId);
      if (!mounted) return;
      if (tracks.isEmpty) {
        setState(() {
          _loading = false;
          _error = l10n?.videoNoCaptions ?? 'No caption tracks available.';
        });
        return;
      }
      final track = await _promptCaptionTrack(tracks);
      if (!mounted) return;
      if (track == null) {
        setState(() => _loading = false);
        return;
      }
      final cues = await _youtube.fetchCaptions(track);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cues = cues;
        _subLabel = track.label;
        _showTranscript = cues.isNotEmpty;
        _activeIndex = -1;
        _error = cues.isEmpty ? 'no cues found in ${track.label}' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Pick a caption track by language. Track lists arrive manual-first
  /// (from the service sort), which is the right default order.
  Future<YouTubeCaptionTrack?> _promptCaptionTrack(
    List<YouTubeCaptionTrack> tracks,
  ) {
    return showDialog<YouTubeCaptionTrack>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)?.videoCaptions ?? 'Captions'),
        children: [
          for (final track in tracks)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(track),
              child: Text(track.label),
            ),
        ],
      ),
    );
  }

  /// The playhead position the transcript should match: the video position
  /// shifted by the persisted subtitle delay (positive = subs later).
  Duration _subtitlePosition(AppState appState) =>
      _video!.value.position -
      Duration(milliseconds: appState.videoSubtitleOffsetMs);

  /// Poll the playhead for the active cue. video_player has no cue-change
  /// callback, and a listener per frame is wasteful for a list that only
  /// needs a few checks a second, so this ticks at 200ms.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final v = _video;
      if (v == null || !v.value.isInitialized || !mounted) return;
      final idx = SubtitleParser.indexAtOrBefore(
        _cues,
        _subtitlePosition(context.read<AppState>()),
      );
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
    final appState = context.read<AppState>();
    // cue times are subtitle-clock; the delay shifts them back onto the
    // video clock so seeking lands on the spoken line
    final start =
        cue.startDuration +
        Duration(milliseconds: appState.videoSubtitleOffsetMs);
    await _video?.seekTo(start);
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

  void _setSpeed(double value) {
    context.read<AppState>().setVideoPlaybackSpeed(value);
    _video?.setPlaybackSpeed(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final v = _video;
    final subScale = appState.videoSubtitleScale;

    if (v == null || !v.value.isInitialized) {
      return _buildNoMedia(l10n, theme);
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
                    scale: fs(context, 13) * subScale,
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
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                icon: Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => v.value.isPlaying ? v.pause() : v.play(),
              ),
              Text(
                '${_fmt(v.value.position)} / ${_fmt(v.value.duration)}',
                style: TextStyle(fontSize: fs(context, 12)),
              ),
              _speedMenu(appState, l10n),
              _subtitleSizeMenu(appState, l10n),
              _delayMenu(appState, l10n),
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
              if (_youtubeVideoId != null)
                TextButton.icon(
                  icon: const Icon(Icons.closed_caption, size: 18),
                  label: Text(l10n?.videoCaptions ?? 'Captions'),
                  onPressed: _loading ? null : _pickCaptions,
                ),
            ],
          ),
        ),
        if (_mediaLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _mediaLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.outline,
                ),
              ),
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
        if (_showTranscript) _buildTranscript(appState, l10n, theme),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _speedMenu(AppState appState, AppLocalizations? l10n) {
    return PopupMenuButton<double>(
      tooltip: l10n?.videoSpeed ?? 'Playback speed',
      onSelected: _setSpeed,
      itemBuilder: (context) => [
        for (final speed in const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
          CheckedPopupMenuItem(
            value: speed,
            checked: appState.videoPlaybackSpeed == speed,
            child: Text('${speed}x'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 4),
            Text(
              '${appState.videoPlaybackSpeed}x',
              style: TextStyle(fontSize: fs(context, 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtitleSizeMenu(AppState appState, AppLocalizations? l10n) {
    return PopupMenuButton<double>(
      tooltip: l10n?.videoSubtitleSize ?? 'Subtitle size',
      onSelected: appState.setVideoSubtitleScale,
      itemBuilder: (context) => [
        for (final scale in const [0.75, 1.0, 1.25, 1.5, 2.0])
          CheckedPopupMenuItem(
            value: scale,
            checked: appState.videoSubtitleScale == scale,
            child: Text('${scale}x'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_size,
              size: 18,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${appState.videoSubtitleScale}x',
              style: TextStyle(fontSize: fs(context, 12)),
            ),
          ],
        ),
      ),
    );
  }

  /// Subtitle delay presets, mirroring jidoujisho's subtitle-delay option.
  static const _delayPresets = [-5000, -1000, -250, 0, 250, 1000, 5000];

  Widget _delayMenu(AppState appState, AppLocalizations? l10n) {
    return PopupMenuButton<int>(
      tooltip: l10n?.videoDelay ?? 'Subtitle delay',
      onSelected: appState.setVideoSubtitleOffset,
      itemBuilder: (context) => [
        for (final ms in _delayPresets)
          CheckedPopupMenuItem(
            value: ms,
            checked: appState.videoSubtitleOffsetMs == ms,
            child: Text(ms == 0 ? '0 ms' : '${ms > 0 ? '+' : ''}$ms ms'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 4),
            Text(
              appState.videoSubtitleOffsetMs == 0
                  ? '0 ms'
                  : '${appState.videoSubtitleOffsetMs > 0 ? '+' : ''}'
                        '${appState.videoSubtitleOffsetMs} ms',
              style: TextStyle(fontSize: fs(context, 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMedia(AppLocalizations? l10n, ThemeData theme) {
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
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(l10n?.videoPickVideo ?? 'Pick video'),
                      onPressed: _loading ? null : _openLocal,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.ondemand_video, size: 18),
                      label: Text(l10n?.videoYouTube ?? 'YouTube'),
                      onPressed: _loading ? null : _openYouTube,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscript(
    AppState appState,
    AppLocalizations? l10n,
    ThemeData theme,
  ) {
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
    final subScale = appState.videoSubtitleScale;
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
                fontSize: fs(context, 13) * subScale,
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
