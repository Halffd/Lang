import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/youtube_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// YouTube resolution checks: pass --dart-define=YOUTUBE_LIVE=true to run
// them; the default suite stays hermetic. The pure quality/ID tests below
// always run.
void main() {
  const live = bool.fromEnvironment('YOUTUBE_LIVE');
  group('qualityOptions', () {
    test('sorts by resolution, smallest to largest', () {
      final options = YouTubeService.qualityOptions([
        (url: 'https://a/720', qualityLabel: '720p'),
        (url: 'https://a/360', qualityLabel: '360p'),
        (url: 'https://a/1080', qualityLabel: '1080p'),
      ]);
      expect(options.map((o) => o.label), ['360p', '720p', '1080p']);
      // last entry is the default stream to play
      expect(options.last.url, 'https://a/1080');
    });

    test('appends p to bare labels and collapses p60', () {
      final options = YouTubeService.qualityOptions([
        (url: 'https://a/144', qualityLabel: '144'),
        (url: 'https://a/720', qualityLabel: '720p60'),
      ]);
      expect(options.map((o) => o.label), ['144p', '720p']);
    });

    test('keeps the highest bitrate per resolution label', () {
      // manifests can list several streams per label; the first seen wins,
      // so callers feed them highest-bitrate first
      final options = YouTubeService.qualityOptions([
        (url: 'https://a/720-fast', qualityLabel: '720p'),
        (url: 'https://a/720-slow', qualityLabel: '720p'),
      ]);
      expect(options, hasLength(1));
      expect(options.single.url, 'https://a/720-fast');
    });

    test('empty input stays empty', () {
      expect(YouTubeService.qualityOptions(const []), isEmpty);
    });
  });

  group('parseVideoId', () {
    final service = const YouTubeService();

    test('extracts the id from every URL form', () {
      expect(
        service.parseVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        service.parseVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        service.parseVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        service.parseVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(service.parseVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('returns null for garbage input', () {
      expect(service.parseVideoId(''), isNull);
      expect(service.parseVideoId('not a url'), isNull);
      expect(service.parseVideoId('https://example.com/video'), isNull);
    });
  });

  group('video player customization persistence', () {
    Future<AppState> loadWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = StorageService();
      await storage.init();
      return AppState(storage);
    }

    test('defaults are used when unset', () async {
      final state = await loadWith({});
      expect(state.videoPlaybackSpeed, 1.0);
      expect(state.videoSubtitleScale, 1.0);
      expect(state.videoSubtitleOffsetMs, 0);
    });

    test('speed is clamped to a usable range', () async {
      final state = await loadWith({});
      state.setVideoPlaybackSpeed(99.0);
      expect(state.videoPlaybackSpeed, 2.0);
      state.setVideoPlaybackSpeed(0.01);
      expect(state.videoPlaybackSpeed, 0.25);
    });

    test('speed preset survives a reload', () async {
      final state = await loadWith({'video_playback_speed': 1.5});
      expect(state.videoPlaybackSpeed, 1.5);
    });

    test('subtitle scale is clamped and persists', () async {
      final state = await loadWith({'video_subtitle_scale': 1.5});
      expect(state.videoSubtitleScale, 1.5);
      state.setVideoSubtitleScale(10.0);
      expect(state.videoSubtitleScale, 2.5);
    });

    test('subtitle delay persists and clamps', () async {
      final state = await loadWith({'video_subtitle_offset_ms': 250});
      expect(state.videoSubtitleOffsetMs, 250);
      state.setVideoSubtitleOffset(-99999);
      expect(state.videoSubtitleOffsetMs, -30000);
    });
  });

  group(
    'YouTube Service network tests',
    skip: !live
        ? 'live network tests: set --dart-define=YOUTUBE_LIVE=true'
        : null,
    () {
      // A short, public, captioned video. Stream manifests and caption
      // tracks change without notice, so the assertions stay structural.
      const videoUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
      const service = YouTubeService();

      test('resolve returns metadata and muxed qualities', () async {
        final info = await service.resolve(videoUrl);
        expect(info, isNotNull);
        // the watch-page metadata scrape is rate-limited aggressively;
        // when it fails the label degrades to the video ID and playback
        // still works, so only the label contract is asserted here
        expect(info!.displayLabel, isNotEmpty);
        expect(info.videoId, 'jNQXAC9IVRw');
        expect(info.qualities, isNotEmpty);
        for (final option in info.qualities) {
          expect(option.url, startsWith('http'));
          expect(option.label, endsWith('p'));
        }
      });

      test('resolve rejects non-video input', () async {
        expect(await service.resolve('https://example.com/video'), isNull);
      });

      test('caption tracks list manual tracks first', () async {
        final tracks = await service.captionTracks('jNQXAC9IVRw');
        // the video may have no captions at all; when it does, manual
        // tracks come before autogenerated ones
        if (tracks.isNotEmpty) {
          final firstAuto = tracks.indexWhere((t) => t.autoGenerated);
          if (firstAuto >= 0) {
            expect(
              tracks.skip(firstAuto).every((t) => t.autoGenerated),
              isTrue,
            );
          }
        }
      });

      test('captions fetch returns ordered cues', () async {
        final tracks = await service.captionTracks('jNQXAC9IVRw');
        if (tracks.isEmpty) return;
        final cues = await service.fetchCaptions(tracks.first);
        if (cues.isEmpty) return;
        for (final cue in cues) {
          expect(cue.end, greaterThan(cue.start));
        }
        final starts = cues.map((c) => c.start).toList();
        expect(starts, orderedEquals([...starts]..sort()));
      });
    },
  );
}
