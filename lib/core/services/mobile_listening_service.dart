import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Abstract player surface so the handoff maths and mode switching are
/// testable without a device.
abstract class ListeningPlayer {
  Future<void> loadUrl(String url, {Duration? initialPosition, String? title});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Duration get position;
  Stream<Duration> get positionStream;
  bool get playing;
  bool get loaded;
}

/// Real implementation over just_audio + just_audio_background (media
/// notification, audio focus, screen-off playback).
class JustAudioListeningPlayer implements ListeningPlayer {
  JustAudioListeningPlayer();

  AudioPlayer? _player;
  bool _loaded = false;

  AudioPlayer get _p => _player ??= AudioPlayer();

  @override
  Future<void> loadUrl(
    String url, {
    Duration? initialPosition,
    String? title,
  }) async {
    await _p.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(id: url, title: title ?? 'Lang listening'),
      ),
      initialPosition: initialPosition,
    );
    _loaded = true;
    await _p.play();
  }

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> resume() async {
    if (!_loaded) return;
    await _p.play();
  }

  @override
  Future<void> stop() async {
    await _p.stop();
    _loaded = false;
  }

  @override
  Future<void> seek(Duration position) => _p.seek(position);

  @override
  Duration get position => _p.position;

  @override
  Stream<Duration> get positionStream => _p.positionStream;

  @override
  bool get playing => _p.playing;

  @override
  bool get loaded => _loaded;
}

/// Pure handoff maths: video ↔ audio mode switching for mobile
/// listening. Unit-testable without a player.
class ListeningHandoff {
  ListeningHandoff._();

  /// Where the audio player should start when switching from video:
  /// the video's current position, clamped to >= 0.
  static Duration audioStartFromVideo(Duration videoPosition) {
    if (videoPosition < Duration.zero) return Duration.zero;
    return videoPosition;
  }

  /// Where the video should resume when switching back: the audio's
  /// last position, clamped to >= 0.
  static Duration videoResumeFromAudio(Duration audioPosition) {
    if (audioPosition < Duration.zero) return Duration.zero;
    return audioPosition;
  }

  /// True when the [videoPosition] has passed [duration] (video ended
  /// while listening) — the listener should be stopped rather than
  /// resumed into a dead video.
  static bool videoEnded(Duration videoPosition, Duration duration) {
    if (duration <= Duration.zero) return false;
    return videoPosition >= duration;
  }
}

/// Mobile listening mode: background audio playback of the video tab's
/// current media with media-notification controls, so language
/// immersion continues with the screen off (jidoujisho-style).
///
/// Desktop is a no-op: video_player + fvp already play there, and the
/// media-notification stack is mobile-only.
class MobileListeningService extends ChangeNotifier {
  MobileListeningService._();
  static final MobileListeningService instance = MobileListeningService._();

  /// Test hook: construct with a fake player. Bypasses the platform
  /// gate — the fake never touches a real audio stack.
  @visibleForTesting
  factory MobileListeningService.forTest(ListeningPlayer player) {
    final s = MobileListeningService._();
    s._player = player;
    s._initialized = true;
    s._testBypass = true;
    s._wirePositionCache();
    return s;
  }

  /// Cache [lastPosition] from the player's position stream.
  void _wirePositionCache() {
    _positionSub?.cancel();
    _positionSub = _player?.positionStream.listen((p) {
      _lastPosition = p;
    });
  }

  /// Set by [forTest]: platform support checks short-circuit true.
  bool _testBypass = false;

  static const String _notificationChannelId = 'lang_listening';

  ListeningPlayer? _player;
  bool _initialized = false;
  bool _active = false;
  String? _activeUrl;
  String? _activeTitle;
  StreamSubscription<Duration>? _positionSub;

  /// True when the platform supports background listening (mobile).
  /// The instance getter honours the test bypass; call sites outside the
  /// service (the video tab) use the static.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _supported => _testBypass || isSupported;

  /// Whether listening mode is currently playing.
  bool get isActive => _active;

  /// The URL currently handed to the background player.
  String? get activeUrl => _activeUrl;

  /// Label shown in the UI while listening (mirrors the notification).
  String? get activeTitle => _activeTitle;

  /// Last known audio position (cached from the position stream).
  Duration _lastPosition = Duration.zero;
  Duration get lastPosition => _lastPosition;

  /// Live position stream while active.
  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();

  /// Initialize the background-audio stack. Safe to call multiple
  /// times; no-op on unsupported platforms.
  Future<void> init() async {
    if (_initialized || !_supported) return;
    _initialized = true;
    _player ??= JustAudioListeningPlayer();
    await JustAudioBackground.init(
      androidNotificationChannelId: _notificationChannelId,
      androidNotificationChannelName: 'Lang listening',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
    _wirePositionCache();
  }

  /// Switch the current media into background audio. [videoPosition]
  /// is where the video was when the toggle fired.
  Future<void> start({
    required String url,
    required Duration videoPosition,
    String? title,
  }) async {
    if (!_supported) return;
    await init();
    if (_active && _activeUrl == url) {
      // same media: just seek the background player to the video head
      final target = ListeningHandoff.audioStartFromVideo(videoPosition);
      await _player?.seek(target);
      await _player?.resume();
      notifyListeners();
      return;
    }
    // different media: stop the old session first
    if (_active) await stop();
    _activeUrl = url;
    _activeTitle = title;
    _lastPosition = ListeningHandoff.audioStartFromVideo(videoPosition);
    await _player?.loadUrl(url, initialPosition: _lastPosition, title: title);
    _active = true;
    notifyListeners();
  }

  /// Leave listening mode. Returns the last audio position so the video
  /// can resume where the listening session left off.
  Future<Duration> stop() async {
    // live position first (the stream cache can lag by one event)
    final live = _player?.position;
    if (live != null && live >= _lastPosition) _lastPosition = live;
    final pos = _lastPosition;
    await _player?.stop();
    _active = false;
    notifyListeners();
    return ListeningHandoff.videoResumeFromAudio(pos);
  }

  /// Pause/resume without leaving listening mode.
  Future<void> togglePause() async {
    final p = _player;
    if (p == null || !_active) return;
    if (p.playing) {
      await p.pause();
    } else {
      await p.resume();
    }
    notifyListeners();
  }

  /// Skip forward/backward by [d] while listening.
  Future<void> seekBy(Duration d) async {
    final p = _player;
    if (p == null || !_active) return;
    var target = p.position + d;
    if (target < Duration.zero) target = Duration.zero;
    await p.seek(target);
    _lastPosition = target;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _player?.stop();
    super.dispose();
  }
}
