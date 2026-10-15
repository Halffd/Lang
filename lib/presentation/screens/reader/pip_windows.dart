/// Secondary-window apps for the video tab: the desktop PiP mini-player
/// and the popup captions window.
///
/// Launched through desktop_multi_window; the child engine's main()
/// detects its role from the window arguments (JSON) and runs one of
/// these apps instead of the main shell.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:video_player/video_player.dart';
import 'package:window_manager/window_manager.dart';

/// Well-known temp-file paths for cross-window state.
String pipSessionPath() => '${Directory.systemTemp.path}/lang_pip_session.json';
String captionStatePath() =>
    '${Directory.systemTemp.path}/lang_captions_state.json';

/// Serialized handoff from the main window to the PiP mini-player.
class PipSession {
  final String url;
  final bool isFile;
  final Duration position;
  final String title;
  final double speed;

  const PipSession({
    required this.url,
    required this.isFile,
    required this.position,
    required this.title,
    required this.speed,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'isFile': isFile,
    'positionMs': position.inMilliseconds,
    'title': title,
    'speed': speed,
  };

  factory PipSession.fromJson(Map<String, dynamic> json) => PipSession(
    url: json['url']?.toString() ?? '',
    isFile: json['isFile'] == true,
    position: Duration(
      milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
    ),
    title: json['title']?.toString() ?? 'Lang',
    speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
  );

  String serialize() => jsonEncode(toJson());

  static PipSession? load(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final raw = f.readAsStringSync();
      if (raw.trim().isEmpty) return null;
      return PipSession.fromJson(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist the live position so the main window can resume here.
  static void savePosition(String path, Duration position) {
    try {
      final session = load(path);
      if (session == null) return;
      final f = File(path);
      f.writeAsStringSync(
        jsonEncode({
          ...session.toJson(),
          'positionMs': position.inMilliseconds,
        }),
        flush: true,
      );
    } catch (_) {}
  }
}

/// Compact always-on-top video player for the desktop PiP window.
class PipPlayerApp extends StatelessWidget {
  final PipSession session;

  const PipPlayerApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _PipPlayerBody(session: session),
    );
  }
}

class _PipPlayerBody extends StatefulWidget {
  final PipSession session;

  const _PipPlayerBody({required this.session});

  @override
  State<_PipPlayerBody> createState() => _PipPlayerBodyState();
}

class _PipPlayerBodyState extends State<_PipPlayerBody> with WindowListener {
  VideoPlayerController? _video;
  String? _error;
  Timer? _positionSave;

  @override
  void initState() {
    super.initState();
    windowManager.ensureInitialized().then((_) async {
      // the PiP window floats above everything while it plays
      await windowManager.setTitle(widget.session.title);
      try {
        await windowManager.setAlwaysOnTop(true);
      } catch (_) {}
    });
    _init();
    _positionSave = Timer.periodic(const Duration(seconds: 5), (_) {
      final v = _video;
      if (v != null && v.value.isInitialized) {
        PipSession.savePosition(pipSessionPath(), v.value.position);
      }
    });
  }

  Future<void> _init() async {
    final controller = widget.session.isFile
        ? VideoPlayerController.file(File(widget.session.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.session.url));
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(widget.session.speed);
      if (widget.session.position > Duration.zero) {
        await controller.seekTo(widget.session.position);
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  @override
  void dispose() {
    _positionSave?.cancel();
    final v = _video;
    if (v != null && v.value.isInitialized) {
      PipSession.savePosition(pipSessionPath(), v.value.position);
    }
    v?.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // ensure the position lands in the session file before the engine dies
    final v = _video;
    if (v != null && v.value.isInitialized) {
      PipSession.savePosition(pipSessionPath(), v.value.position);
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _video != null && _video!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _video!.value.aspectRatio == 0
                        ? 16 / 9
                        : _video!.value.aspectRatio,
                    child: VideoPlayer(_video!),
                  )
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                : const CircularProgressIndicator(strokeWidth: 2),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              tooltip: 'Close PiP',
              onPressed: () async {
                final v = _video;
                if (v != null && v.value.isInitialized) {
                  PipSession.savePosition(pipSessionPath(), v.value.position);
                }
                await windowManager.destroy();
              },
            ),
          ),
          if (_video != null && _video!.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(
                children: [
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _video!,
                    builder: (context, state, _) => IconButton(
                      color: Colors.white70,
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () =>
                          state.isPlaying ? _video!.pause() : _video!.play(),
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _video!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF7C3AED),
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
}

/// Popup captions window: shows the current subtitle/STT cue pushed
/// from the main window, in a large always-readable face.
class CaptionsWindowApp extends StatelessWidget {
  const CaptionsWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _CaptionsWindowBody(),
    );
  }
}

class _CaptionsWindowBody extends StatefulWidget {
  @override
  State<_CaptionsWindowBody> createState() => _CaptionsWindowBodyState();
}

class _CaptionsWindowBodyState extends State<_CaptionsWindowBody> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    windowManager.ensureInitialized().then((_) async {
      try {
        await windowManager.setTitle('Lang captions');
        await windowManager.setAlwaysOnTop(true);
      } catch (_) {}
    });
    // restore the last cue so the window isn't blank before the next push
    _restore();
    // the parent pushes cues through the window method channel
    _installHandler();
  }

  Future<void> _restore() async {
    try {
      final f = File(captionStatePath());
      if (f.existsSync()) {
        final raw = f.readAsStringSync();
        if (raw.trim().isNotEmpty && mounted) {
          setState(() => _text = raw);
        }
      }
    } catch (_) {}
  }

  void _installHandler() async {
    final controller = await WindowController.fromCurrentEngine();
    controller.setWindowMethodHandler((call) async {
      if (call.method == 'updateCaption') {
        final text = call.arguments?['text']?.toString() ?? '';
        if (mounted) setState(() => _text = text);
        // persist so a reopened window isn't blank
        try {
          File(captionStatePath()).writeAsStringSync(text, flush: true);
        } catch (_) {}
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _text.isEmpty ? '(captions)' : _text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              height: 1.4,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
