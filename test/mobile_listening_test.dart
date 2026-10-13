import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/mobile_listening_service.dart';

/// Scripted fake player: records calls, plays a position that advances
/// with the fake clock supplied by the test.
class FakeListeningPlayer implements ListeningPlayer {
  FakeListeningPlayer({this.initialPosition = Duration.zero});

  final List<String> calls = [];
  Duration initialPosition;
  Duration _pos = Duration.zero;
  bool _playing = false;
  bool hasLoaded = false;
  String? loadedUrl;

  final _controller = StreamController<Duration>.broadcast();

  void advance(Duration d) {
    _pos += d;
    _controller.add(_pos);
  }

  @override
  Future<void> loadUrl(
    String url, {
    Duration? initialPosition,
    String? title,
  }) async {
    calls.add('load:$url@${initialPosition?.inMilliseconds ?? 0}');
    loadedUrl = url;
    _pos = initialPosition ?? Duration.zero;
    hasLoaded = true;
    _playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _playing = true;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playing = false;
    hasLoaded = false;
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    _pos = position;
  }

  @override
  Duration get position => _pos;

  @override
  Stream<Duration> get positionStream => _controller.stream;

  @override
  bool get playing => _playing;

  @override
  bool get loaded => hasLoaded;
}

void main() {
  group('ListeningHandoff', () {
    test('audio starts where the video was', () {
      expect(
        ListeningHandoff.audioStartFromVideo(
          const Duration(minutes: 3, seconds: 12),
        ),
        const Duration(minutes: 3, seconds: 12),
      );
    });

    test('negative video position clamps to zero', () {
      expect(
        ListeningHandoff.audioStartFromVideo(const Duration(seconds: -5)),
        Duration.zero,
      );
    });

    test('video resumes where the audio stopped', () {
      expect(
        ListeningHandoff.videoResumeFromAudio(const Duration(minutes: 7)),
        const Duration(minutes: 7),
      );
    });

    test('videoEnded true only at/past the end', () {
      expect(
        ListeningHandoff.videoEnded(
          const Duration(minutes: 10),
          const Duration(minutes: 10),
        ),
        isTrue,
      );
      expect(
        ListeningHandoff.videoEnded(
          const Duration(minutes: 9, seconds: 59),
          const Duration(minutes: 10),
        ),
        isFalse,
      );
      // unknown duration: never "ended"
      expect(
        ListeningHandoff.videoEnded(const Duration(hours: 2), Duration.zero),
        isFalse,
      );
    });
  });

  group('MobileListeningService (fake player)', () {
    late MobileListeningService service;
    late FakeListeningPlayer fake;

    setUp(() {
      fake = FakeListeningPlayer();
      service = MobileListeningService.forTest(fake);
    });

    tearDown(() {
      service.dispose();
    });

    test('start loads the url at the video position and activates', () async {
      await service.start(
        url: 'https://example.com/stream.m3u8',
        videoPosition: const Duration(seconds: 42),
        title: 'My video',
      );
      expect(service.isActive, isTrue);
      expect(service.activeUrl, 'https://example.com/stream.m3u8');
      expect(
        fake.calls.first,
        contains('load:https://example.com/stream.m3u8'),
      );
      expect(fake.calls.first, contains('@42000'));
      expect(fake.playing, isTrue);
    });

    test('restarting the same media seeks instead of reloading', () async {
      await service.start(
        url: 'https://example.com/stream.m3u8',
        videoPosition: const Duration(seconds: 42),
      );
      await service.start(
        url: 'https://example.com/stream.m3u8',
        videoPosition: const Duration(seconds: 90),
      );
      final loadCalls = fake.calls.where((c) => c.startsWith('load:')).length;
      expect(loadCalls, 1, reason: 'same url must not reload');
      expect(fake.calls, contains('seek:90000'));
      expect(service.isActive, isTrue);
    });

    test('switching media reloads with the new url', () async {
      await service.start(url: 'a.mp4', videoPosition: Duration.zero);
      await service.start(
        url: 'b.mp4',
        videoPosition: const Duration(seconds: 5),
      );
      final loadCalls = fake.calls
          .where((c) => c.startsWith('load:'))
          .map((c) => c.split('@')[0])
          .toList();
      expect(loadCalls, ['load:a.mp4', 'load:b.mp4']);
      expect(service.activeUrl, 'b.mp4');
    });

    test('stop returns the last audio position for video resume', () async {
      await service.start(url: 'a.mp4', videoPosition: Duration.zero);
      fake.advance(const Duration(seconds: 30));
      final resumeAt = await service.stop();
      expect(resumeAt, const Duration(seconds: 30));
      expect(service.isActive, isFalse);
      expect(fake.calls, contains('stop'));
    });

    test('togglePause flips the playing state', () async {
      await service.start(url: 'a.mp4', videoPosition: Duration.zero);
      expect(fake.playing, isTrue);
      await service.togglePause();
      expect(fake.playing, isFalse);
      await service.togglePause();
      expect(fake.playing, isTrue);
    });

    test('seekBy moves position and clamps at zero', () async {
      await service.start(url: 'a.mp4', videoPosition: Duration.zero);
      fake.advance(const Duration(seconds: 10));
      await service.seekBy(const Duration(seconds: 5));
      expect(fake.position, const Duration(seconds: 15));
      await service.seekBy(const Duration(seconds: -60));
      expect(fake.position, Duration.zero, reason: 'clamped at zero');
    });

    test('isSupported is false on the test (desktop) platform', () {
      // flutter test runs on the host; CI/desktop has no mobile platform
      expect(MobileListeningService.isSupported, isFalse);
    });
  });
}
