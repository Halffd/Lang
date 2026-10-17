import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:floating/floating.dart';
import 'package:video_player/video_player.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/core/services/whisper_subs_service.dart';
import 'package:lang/presentation/screens/reader/pip_windows.dart';
import 'package:lang/presentation/widgets/annotated_line.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/utils/pinyin_util.dart';
import 'package:lang/core/services/mobile_listening_service.dart';
import 'package:lang/core/services/youtube_resolver.dart';
import 'package:lang/core/services/youtube_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/chinese_util.dart';
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

  /// What is currently open: a file path or the canonical YouTube URL.
  String? _currentSource;

  /// Directly playable URL for the current media: local file path or
  /// the last resolved muxed stream (expires after hours — only good
  /// for this session). Handed to the mobile listening player.
  String? _activeStreamUrl;

  /// Mobile listening mode active (background audio, screen off).
  bool _listeningMode = false;

  /// Desktop popup windows: PiP mini-player and captions.
  WindowController? _pipWindow;
  WindowController? _captionWindow;
  int? _captionPushedIndex;

  /// Android PiP controller (floating package).
  final Floating _floating = Floating();

  /// In-app draggable caption overlay visibility.
  bool _showCaptionOverlay = false;

  /// Cumulative time actually spent playing the current video.
  int _watchedMs = 0;

  /// Ticks since the last progress persist (25 ticks = 5s).
  int _ticksSincePersist = 0;

  /// yt-dlp when installed, youtube_explode otherwise.
  final _youtube = YouTubeResolver();

  /// Captured when the current video was adopted; progress persists
  /// through this reference because [dispose] can no longer look up
  /// ancestors.
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    // The WhisperSubs browse tab hands videos over through AppState.
    _appState = context.read<AppState>();
    _appState!.videoLoadRequest.addListener(_onVideoLoadRequest);
  }

  @override
  void dispose() {
    _appState?.videoLoadRequest.removeListener(_onVideoLoadRequest);
    _persistProgress();
    _ticker?.cancel();
    _transcriptScroll.dispose();
    if (_listeningMode) {
      // leaving the tab ends the listening session (the notification
      // goes away with it; a proper background queue is out of scope)
      unawaited(MobileListeningService.instance.stop());
    }
    _video?.dispose();
    super.dispose();
  }

  /// Flush watch progress for the current source into the recents, if one
  /// is open. Called periodically from the ticker and on dispose.
  void _persistProgress() {
    final source = _currentSource;
    final v = _video;
    final appState = _appState;
    if (source == null || v == null || !v.value.isInitialized) return;
    appState?.updateRecentVideoProgress(
      source,
      v.value.position.inMilliseconds,
      _watchedMs,
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Swap in a fully initialized controller, keeping the customization
  /// (speed) the user already set and resuming from [resumeAt] when the
  /// video was watched before.
  Future<void> _adopt(
    VideoPlayerController controller, {
    Duration resumeAt = Duration.zero,
  }) async {
    // a new video takes the playhead back from the background player
    if (_listeningMode) {
      await _exitListeningMode();
    }
    await controller.setLooping(false);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    final appState = _appState = context.read<AppState>();
    await controller.setPlaybackSpeed(appState.videoPlaybackSpeed);
    if (resumeAt > Duration.zero) {
      final duration = controller.value.duration;
      // don't "resume" into the last seconds — that reads as finished
      if (resumeAt < duration - const Duration(seconds: 5)) {
        await controller.seekTo(resumeAt);
      }
    }
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
    if (file == null || path == null || !mounted) return;

    // resume from where this file was last watched, if it was
    final appState = context.read<AppState>();
    final previous = appState.recentVideos
        .where((e) => e['source'] == path)
        .toList();
    final resumeMs = previous.isEmpty
        ? 0
        : (previous.first['lastPositionMs'] as int? ?? 0);
    await _openFileSource(path, file.name, resumeMs);
  }

  /// Load a local video file: initialize, record in the recents, adopt.
  Future<void> _openFileSource(String path, String name, int resumeMs) async {
    if (!mounted) return;
    final appState = context.read<AppState>();
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
      await _adopt(controller, resumeAt: Duration(milliseconds: resumeMs));
      setState(() {
        _mediaLabel = name;
        _currentSource = path;
        _activeStreamUrl = path;
        _watchedMs = 0;
        _youtubeVideoId = null;
        _cues = const [];
        _subLabel = null;
        _showTranscript = false;
      });
      appState.recordRecentVideo({
        'kind': 'file',
        'source': path,
        'label': name,
        'lastPositionMs': resumeMs,
        'watchedMs': 0,
        'lastWatchedAt': DateTime.now().millisecondsSinceEpoch,
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

  /// Open a YouTube URL (from the prompt or a recents entry), resolve it,
  /// record it and adopt the stream.
  /// A video handed over by the WhisperSubs browse tab: either a
  /// YouTube URL (resolved through the usual flow) or server-hosted
  /// media with a side-loaded SRT.
  void _onVideoLoadRequest() {
    final appState = _appState;
    final request = appState?.videoLoadRequest.value;
    if (request == null) return;
    appState!.videoLoadRequest.value = null; // consume
    if (_loading) return;
    switch (request['kind']) {
      case 'youtube':
        final url = request['url'] as String?;
        if (url != null && url.isNotEmpty) _openYouTube(url);
      case 'direct':
        _openServerMedia(request);
    }
  }

  /// Load server-hosted media and side-load its SRT so the transcript
  /// doubles as the dictionary surface like every other source.
  Future<void> _openServerMedia(Map<String, dynamic> request) async {
    final mediaUrl = request['mediaUrl'] as String?;
    if (mediaUrl == null || mediaUrl.isEmpty) return;
    final appState = _appState;
    if (appState == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _adopt(controller);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _mediaLabel = (request['title'] as String?) ?? 'server media';
        _currentSource = mediaUrl;
        _watchedMs = 0;
        _youtubeVideoId = null;
        _cues = const [];
        _subLabel = null;
        _showTranscript = false;
      });
      final srtUrl = request['srtUrl'] as String?;
      if (srtUrl != null && srtUrl.isNotEmpty) {
        final service = WhisperSubsService(
          baseUrl: appState.whisperSubsUrl.trim(),
          apiKey: appState.whisperSubsApiKey,
        );
        final text = await service.fetchText(srtUrl);
        if (!mounted) return;
        _applySubtitleCues(SubtitleParser.parseSrt(text), 'WhisperSubs');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openYouTube([String? presetUrl]) async {
    final l10n = AppLocalizations.of(context);
    final url = presetUrl ?? await _promptYouTubeUrl();
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
      final canonical = 'https://www.youtube.com/watch?v=${info.videoId}';
      final appState = context.read<AppState>();
      final previous = appState.recentVideos
          .where((e) => e['source'] == canonical)
          .toList();
      final resumeMs = previous.isEmpty
          ? 0
          : (previous.first['lastPositionMs'] as int? ?? 0);
      await _adopt(controller, resumeAt: Duration(milliseconds: resumeMs));
      setState(() {
        _mediaLabel = info.displayLabel;
        _currentSource = canonical;
        _activeStreamUrl = info.best.url;
        _watchedMs = 0;
        _youtubeVideoId = info.videoId;
        _cues = const [];
        _subLabel = null;
        _showTranscript = false;
      });
      appState.recordRecentVideo({
        'kind': 'youtube',
        'source': canonical,
        'label': info.displayLabel,
        'videoId': info.videoId,
        'lastPositionMs': resumeMs,
        'watchedMs': 0,
        'lastWatchedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Reopen a recents entry: local files stream from disk, YouTube from a
  /// fresh stream resolution (old stream URLs expire within hours).
  Future<void> _reopenRecent(Map<String, dynamic> entry) async {
    final source = entry['source']?.toString();
    if (source == null || source.isEmpty) return;
    final kind = entry['kind']?.toString();
    final resumeMs = entry['lastPositionMs'] as int? ?? 0;
    if (kind == 'file') {
      if (!File(source).existsSync()) {
        if (!mounted) return;
        setState(() {
          _error =
              AppLocalizations.of(context)?.videoMissingFile ??
              'File no longer exists.';
        });
        return;
      }
      await _openFileSource(
        source,
        entry['label']?.toString() ?? source,
        resumeMs,
      );
    } else {
      await _openYouTube(source);
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
          decoration: InputDecoration(
            hintText:
                l10n?.videoYouTubeHint ?? 'Paste a YouTube URL or search…',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // search mode: pick a result, return its canonical URL
              Navigator.of(context).pop();
              final picked = await _searchYouTube();
              if (picked != null && mounted) await _openYouTube(picked);
            },
            child: const Text('Search…'),
          ),
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

  /// Search YouTube (yt-dlp `ytsearch` / explode fallback) and let the
  /// user pick a result. Returns the canonical watch URL of the pick.
  Future<String?> _searchYouTube() async {
    final field = TextEditingController();
    List<YouTubeSearchHit>? hits;
    String? error;
    var searching = false;

    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> runSearch() async {
            final q = field.text.trim();
            if (q.isEmpty) return;
            setDialog(() {
              searching = true;
              error = null;
              hits = null;
            });
            try {
              final results = await _youtube.search(q, limit: 12);
              if (!ctx.mounted) return;
              setDialog(() {
                hits = results;
                searching = false;
                if (results.isEmpty) error = 'No results for "$q"';
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setDialog(() {
                searching = false;
                error = '$e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Search YouTube'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: field,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search query or URL',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => runSearch(),
                  ),
                  const SizedBox(height: 8),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    )
                  else if (hits != null)
                    Flexible(
                      child: SizedBox(
                        height: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: hits!.length,
                          itemBuilder: (context, i) {
                            final hit = hits![i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(
                                hit.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                  if (hit.author.isNotEmpty) hit.author,
                                  if (hit.durationLabel.isNotEmpty)
                                    hit.durationLabel,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(ctx).pop(hit.watchUrl),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
                onPressed: searching ? null : runSearch,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Human watch time: minutes under an hour, `1h 05m` above.
  String _formatWatched(int ms) {
    final minutes = ms ~/ 60000;
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }

  /// Pick a subtitle source: sidecar file, pasted text, or one of the
  /// recent subtitle files/contents.
  Future<void> _pickSubtitles() async {
    if (_video == null) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(l10n?.videoLoadSubs ?? 'Load subs'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n?.videoPasteSubs ?? 'Paste subtitles'),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
            if (context.read<AppState>().recentSubtitles.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(l10n?.videoRecent ?? 'Recent'),
                onTap: () => Navigator.pop(context, 'recent'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'file':
        await _importSubtitleFile();
      case 'paste':
        await _importSubtitleText();
      case 'recent':
        await _pickRecentSubtitles();
    }
  }

  Future<void> _importSubtitleFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'json', 'txt'],
    );
    final file = picked?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;

    try {
      final raw = await File(path).readAsString();
      if (!mounted) return;
      final cues = SubtitleParser.parseAuto(raw, filename: file.name);
      _applySubtitleCues(cues, file.name);
      context.read<AppState>().recordRecentSubtitle({
        'key': path,
        'name': file.name,
        'path': path,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Manual subtitle import: paste the content of an SRT/VTT/JSON export
  /// into a dialog. Works on every platform, including mobile ones where
  /// the file picker may be restricted.
  Future<void> _importSubtitleText() async {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.videoPasteSubs ?? 'Paste subtitles'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: field,
            maxLines: 12,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '1\n00:00:01,000 --> 00:00:04,000\n…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(l10n?.videoLoad ?? 'Load'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final cues = SubtitleParser.parseAuto(text, filename: 'pasted.vtt');
    final label =
        '${AppLocalizations.of(context)?.videoPastedSubs ?? 'Pasted subtitles'}'
        ' · ${DateTime.now().toString().substring(5, 16)}';
    if (_applySubtitleCues(cues, label)) {
      context.read<AppState>().recordRecentSubtitle({
        'key': 'pasted:$label',
        'name': label,
        'text': text,
      });
    }
  }

  Future<void> _pickRecentSubtitles() async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final key = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n?.videoRecent ?? 'Recent'),
        children: [
          if (appState.recentSubtitles.isEmpty)
            SimpleDialogOption(
              child: Text(l10n?.videoNoRecent ?? 'Nothing watched yet.'),
            ),
          for (final entry in appState.recentSubtitles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry['key']?.toString()),
              child: Text(
                entry['name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    if (key == null || !mounted) return;
    final entry = appState.recentSubtitles
        .where((e) => e['key'] == key)
        .toList()
        .firstOrNull;
    if (entry == null) return;
    final path = entry['path']?.toString();
    final text = entry['text']?.toString();
    try {
      final raw = path != null ? await File(path).readAsString() : (text ?? '');
      if (!mounted) return;
      final name = entry['name']?.toString() ?? key;
      if (!_applySubtitleCues(
        SubtitleParser.parseAuto(raw, filename: name),
        name,
      )) {
        return;
      }
      // a file that vanished since it was recorded is removed from the
      // list instead of failing on every future open
      if (path != null && !File(path).existsSync()) {
        appState.removeRecentSubtitle(key);
      }
    } catch (e) {
      if (!mounted) return;
      appState.removeRecentSubtitle(key);
      setState(() => _error = '$e');
    }
  }

  /// Swap in loaded cues; returns false (and reports) when nothing parsed.
  bool _applySubtitleCues(List<SubtitleCue> cues, String label) {
    setState(() {
      _cues = cues;
      _subLabel = label;
      _showTranscript = cues.isNotEmpty;
      _activeIndex = -1;
      _error = cues.isEmpty ? 'no cues found in $label' : null;
    });
    return cues.isNotEmpty;
  }

  /// Ask the configured whisper-subs server to transcribe the loaded
  /// YouTube video and use the produced SRT as the subtitle track —
  /// the same API the WhisperSubs Android app talks to. Only offered for
  /// YouTube sources: the server downloads the video with yt-dlp, and it
  /// cannot see files picked on this device.
  Future<void> _transcribeWithServer() async {
    if (_loading || _currentSource == null) return;
    final appState = context.read<AppState>();
    final url = appState.whisperSubsUrl.trim();
    if (url.isEmpty) {
      setState(
        () => _error = 'Set the WhisperSubs server URL in Settings first.',
      );
      return;
    }
    final service = WhisperSubsService(
      baseUrl: url,
      apiKey: appState.whisperSubsApiKey,
    );
    final status = ValueNotifier<String>('submitting…');
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: status,
        builder: (ctx, line, _) => AlertDialog(
          title: const Text('WhisperSubs'),
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(line)),
            ],
          ),
        ),
      ),
    );
    try {
      final srt = await service.transcribeForSrt(
        _currentSource!,
        onStatus: (line) => status.value = line,
        onSrtUpdate: (text) {
          // Stream the growing subtitles into the transcript/overlay
          // while the server transcribes; the final parse below
          // replaces the partial state once the task completes.
          if (!mounted) return;
          _applySubtitleCues(
            SubtitleParser.parseSrt(text),
            'WhisperSubs (live)',
          );
        },
      );
      final cues = SubtitleParser.parseSrt(srt);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _applySubtitleCues(cues, 'WhisperSubs');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _error = 'WhisperSubs: $e');
    } finally {
      status.dispose();
      dialog.ignore();
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
  Duration _subtitlePosition(AppState appState) {
    // listening mode: the background audio owns the playhead (the video
    // is paused underneath)
    if (_listeningMode) {
      return MobileListeningService.instance.lastPosition -
          Duration(milliseconds: appState.videoSubtitleOffsetMs);
    }
    return _video!.value.position -
        Duration(milliseconds: appState.videoSubtitleOffsetMs);
  }

  /// Poll the playhead for the active cue. video_player has no cue-change
  /// callback, and a listener per frame is wasteful for a list that only
  /// needs a few checks a second, so this ticks at 200ms. While playing,
  /// the tick also accrues watch time and periodically flushes it into
  /// the recents.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final v = _video;
      if (v == null || !v.value.isInitialized || !mounted) return;
      if (_listeningMode) {
        // audio owns the playhead; accrue watch time from the audio
        // position delta and keep the transcript tracking
        final listening = MobileListeningService.instance;
        final audioPos = listening.lastPosition;
        _watchedMs += 200;
        _ticksSincePersist++;
        if (_ticksSincePersist >= 25) {
          _ticksSincePersist = 0;
          _persistProgress();
        }
        final idx = SubtitleParser.indexAtOrBefore(
          _cues,
          audioPos -
              Duration(
                milliseconds: context.read<AppState>().videoSubtitleOffsetMs,
              ),
        );
        if (idx == _activeIndex) return;
        final wasHidden = _activeIndex < 0 && idx >= 0;
        setState(() => _activeIndex = idx);
        _pushCaptionToWindow();
        if (wasHidden) _scrollTranscriptTo(idx);
        return;
      }
      if (v.value.isPlaying) {
        _watchedMs += 200;
        _ticksSincePersist++;
        if (_ticksSincePersist >= 25) {
          _ticksSincePersist = 0;
          _persistProgress();
        }
      }
      final idx = SubtitleParser.indexAtOrBefore(
        _cues,
        _subtitlePosition(context.read<AppState>()),
      );
      if (idx == _activeIndex) return;
      final wasHidden = _activeIndex < 0 && idx >= 0;
      setState(() => _activeIndex = idx);
      if (wasHidden) _scrollTranscriptTo(idx);
      _pushCaptionToWindow();
    });
  }

  // ------------------------------------------------------------
  // mobile listening mode (background audio, screen off)
  // ------------------------------------------------------------

  /// Enter listening mode: hand the current media to the background
  /// player at the video's current position, pause the video. The
  /// transcript ticker keeps tracking via the audio position.
  Future<void> _enterListeningMode() async {
    final url = _activeStreamUrl;
    if (url == null || !MobileListeningService.isSupported) return;
    final video = _video;
    final videoPos = video?.value.position ?? Duration.zero;
    final listening = MobileListeningService.instance;
    await listening.start(
      url: url,
      videoPosition: videoPos,
      title: _mediaLabel,
    );
    await video?.pause();
    if (mounted) setState(() => _listeningMode = true);
  }

  /// Leave listening mode: resume the video at the audio's last
  /// position.
  Future<void> _exitListeningMode() async {
    final listening = MobileListeningService.instance;
    final resumeAt = await listening.stop();
    final video = _video;
    if (video != null) {
      await video.seekTo(resumeAt);
      await video.play();
    }
    if (mounted) setState(() => _listeningMode = false);
  }

  /// Toggle listening mode; a no-op on desktop.
  Future<void> _toggleListeningMode() async {
    if (!MobileListeningService.isSupported) return;
    if (_listeningMode) {
      await _exitListeningMode();
    } else {
      await _enterListeningMode();
    }
  }

  // ------------------------------------------------------------
  // picture-in-picture (desktop mini window / Android native PiP)
  // ------------------------------------------------------------

  /// Desktop: detach playback into an always-on-top mini window. The
  /// main video pauses; the mini window owns the playhead and writes
  /// its position to the shared session file, which the main window
  /// reads back when the user presses play.
  Future<void> _enterDesktopPip() async {
    final v = _video;
    final url = _activeStreamUrl;
    if (v == null || url == null) return;
    final session = PipSession(
      url: url,
      isFile: _youtubeVideoId == null,
      position: v.value.position,
      title: _mediaLabel ?? 'Lang',
      speed: v.value.playbackSpeed,
    );
    // pause the main video; the PiP window takes over
    await v.pause();
    final controller = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({'mode': 'pip', ...session.toJson()}),
      ),
    );
    await controller.show();
    if (mounted) setState(() => _pipWindow = controller);
  }

  /// Mobile (Android): native picture-in-picture via the floating
  /// package. The video keeps playing in the system PiP window.
  Future<void> _enterMobilePip() async {
    try {
      final available = await _floating.isPipAvailable;
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PiP unavailable on this device')),
          );
        }
        return;
      }
      await _floating.enable(ImmediatePiP());
    } catch (_) {
      // PiP entry is best-effort
    }
  }

  Future<void> _togglePip() async {
    if (_isDesktopTarget) {
      await _enterDesktopPip();
    } else if (Platform.isAndroid) {
      await _enterMobilePip();
    }
  }

  static bool get _isDesktopTarget =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  // ------------------------------------------------------------
  // popup captions (desktop popup window / in-app draggable overlay)
  // ------------------------------------------------------------

  /// Open the desktop captions popup window (current cue pushed live).
  Future<void> _openCaptionsWindow() async {
    if (_captionWindow != null) {
      await _captionWindow!.show();
      return;
    }
    final controller = await WindowController.create(
      const WindowConfiguration(
        arguments: '{"mode":"captions"}',
        hiddenAtLaunch: false,
      ),
    );
    await controller.show();
    if (mounted) {
      setState(() => _captionWindow = controller);
      // push the current cue immediately
      await _pushCaptionToWindow();
    }
  }

  /// Push the active cue to the captions popup window (if open).
  Future<void> _pushCaptionToWindow() async {
    final win = _captionWindow;
    if (win == null) return;
    final text = _cues.isNotEmpty && _activeIndex >= 0
        ? _cues[_activeIndex.clamp(0, _cues.length - 1)].plainText
        : '';
    try {
      await win.invokeMethod('updateCaption', {'text': text});
    } catch (_) {
      // window closed
    }
  }

  /// Toggle the in-app draggable caption overlay (mobile + desktop).
  void _toggleCaptionOverlay() {
    setState(() => _showCaptionOverlay = !_showCaptionOverlay);
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

  /// Recent videos with their watch time; tapping reopens and resumes.
  Future<void> _showRecentVideos() async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final source = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n?.videoRecent ?? 'Recent'),
        children: [
          if (appState.recentVideos.isEmpty)
            SimpleDialogOption(
              child: Text(l10n?.videoNoRecent ?? 'Nothing watched yet.'),
            ),
          for (final entry in appState.recentVideos)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, entry['source']?.toString()),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  entry['kind'] == 'youtube'
                      ? Icons.ondemand_video
                      : Icons.movie_outlined,
                  size: 20,
                ),
                title: Text(
                  entry['label']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Builder(
                  builder: (context) {
                    final watched = _formatWatched(
                      entry['watchedMs'] as int? ?? 0,
                    );
                    return Text(
                      l10n?.videoWatchedFor(watched) ?? '$watched watched',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final entry = appState.recentVideos
        .where((e) => e['source'] == source)
        .toList()
        .firstOrNull;
    if (entry != null) await _reopenRecent(entry);
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
        if (_showCaptionOverlay && _cues.isNotEmpty)
          DraggableCaptionOverlay(
            text: _activeIndex >= 0
                ? _cues[_activeIndex.clamp(0, _cues.length - 1)].plainText
                : '',
            fontSize: fs(context, 13) * subScale * 1.4,
            onDismiss: () => setState(() => _showCaptionOverlay = false),
          ),
        AspectRatio(
          aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
          // Android PiP: when the system enters PiP, drop the controls and
          // show only the video surface (native PiP window shows it).
          child: PiPSwitcher(
            childWhenDisabled: Stack(
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
            // PiP: video only, no controls (system window owns it)
            childWhenEnabled: VideoPlayer(v),
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
              IconButton(
                icon: const Icon(Icons.history, size: 18),
                tooltip: l10n?.videoRecent ?? 'Recent',
                onPressed: _loading ? null : _showRecentVideos,
              ),
              // picture-in-picture: desktop mini window / Android native
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt, size: 18),
                tooltip: _isDesktopTarget
                    ? 'Pop out mini player'
                    : 'Picture-in-picture',
                onPressed: _togglePip,
              ),
              // popup captions: desktop popup window / in-app overlay
              IconButton(
                icon: Icon(
                  Icons.closed_caption,
                  size: 18,
                  color: (_showCaptionOverlay || _captionWindow != null)
                      ? theme.colorScheme.primary
                      : null,
                ),
                tooltip: 'Popup captions',
                onPressed: () {
                  if (_isDesktopTarget) {
                    _openCaptionsWindow();
                  } else {
                    _toggleCaptionOverlay();
                  }
                },
              ),
              // mobile listening mode: background audio, screen off
              if (MobileListeningService.isSupported &&
                  _activeStreamUrl != null)
                IconButton(
                  icon: Icon(
                    _listeningMode
                        ? Icons.headphones
                        : Icons.headphones_outlined,
                    size: 18,
                    color: _listeningMode ? theme.colorScheme.primary : null,
                  ),
                  tooltip: _listeningMode
                      ? 'Leave listening mode (back to video)'
                      : 'Listening mode (audio only, screen off)',
                  onPressed: _toggleListeningMode,
                ),
              if (_youtubeVideoId != null) ...[
                TextButton.icon(
                  icon: const Icon(Icons.closed_caption, size: 18),
                  label: Text(l10n?.videoCaptions ?? 'Captions'),
                  onPressed: _loading ? null : _pickCaptions,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.graphic_eq, size: 18),
                  label: const Text('WhisperSubs'),
                  onPressed: _loading ? null : _transcribeWithServer,
                ),
              ],
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
                    if (context.watch<AppState>().recentVideos.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.history, size: 18),
                        label: Text(l10n?.videoRecent ?? 'Recent'),
                        onPressed: _loading ? null : _showRecentVideos,
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
    final annotate = _needsAnnotation(appState);
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
            title: annotate
                ? AnnotatedLine(
                    text: cue.plainText,
                    appState: appState,
                    fontSize: fs(context, 13) * subScale,
                    weight: active ? FontWeight.w600 : FontWeight.normal,
                  )
                : Text(
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

  /// Whether the annotated path is on: either setting needs tokenizing.
  bool _needsAnnotation(AppState appState) =>
      appState.readingStyle != 'off' || appState.wordColoringEnabled;
}

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

/// Draggable floating caption bubble (in-app overlay for mobile and
/// desktop): shows the current subtitle/STT cue text above everything
/// else in the tab. Drag to reposition; double-tap to dismiss.
class DraggableCaptionOverlay extends StatefulWidget {
  final String text;
  final double fontSize;
  final VoidCallback? onDismiss;

  const DraggableCaptionOverlay({
    super.key,
    required this.text,
    required this.fontSize,
    this.onDismiss,
  });

  @override
  State<DraggableCaptionOverlay> createState() =>
      _DraggableCaptionOverlayState();
}

class _DraggableCaptionOverlayState extends State<DraggableCaptionOverlay> {
  Offset _offset = const Offset(16, 16);

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) =>
            setState(() => _offset += Offset(d.delta.dx, d.delta.dy)),
        onDoubleTap: () => widget.onDismiss?.call(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              height: 1.4,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
