import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> loadWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final storage = StorageService();
    await storage.init();
    return AppState(storage);
  }

  Map<String, dynamic> entry(String source, {int watchedMs = 0}) => {
    'kind': 'file',
    'source': source,
    'label': source,
    'lastPositionMs': 0,
    'watchedMs': watchedMs,
    'lastWatchedAt': 1,
  };

  group('recent videos', () {
    test('empty by default', () async {
      final state = await loadWith({});
      expect(state.recentVideos, isEmpty);
    });

    test('newest first, deduped by source', () async {
      final state = await loadWith({});
      state.recordRecentVideo(entry('/a'));
      state.recordRecentVideo(entry('/b'));
      state.recordRecentVideo(entry('/a'));
      expect(state.recentVideos.map((e) => e['source']), ['/a', '/b']);
    });

    test('capped at 20 entries', () async {
      final state = await loadWith({});
      for (var i = 0; i < 30; i++) {
        state.recordRecentVideo(entry('/v$i'));
      }
      expect(state.recentVideos, hasLength(20));
      expect(state.recentVideos.first['source'], '/v29');
      expect(state.recentVideos.last['source'], '/v10');
    });

    test('progress updates in place without reordering', () async {
      final state = await loadWith({});
      state.recordRecentVideo(entry('/a'));
      state.recordRecentVideo(entry('/b'));
      state.updateRecentVideoProgress('/a', 90_000, 120_000);
      expect(state.recentVideos.first['source'], '/b');
      final updated = state.recentVideos
          .where((e) => e['source'] == '/a')
          .single;
      expect(updated['lastPositionMs'], 90_000);
      expect(updated['watchedMs'], 120_000);
      // updating an unknown source is a no-op, not a crash
      state.updateRecentVideoProgress('/missing', 1, 1);
    });

    test('entries survive a reload', () async {
      final state = await loadWith({});
      state.recordRecentVideo(entry('/a', watchedMs: 60_000));
      final reloaded = await loadWith({
        'recent_videos': jsonEncode([
          {
            'kind': 'file',
            'source': '/a',
            'label': '/a',
            'lastPositionMs': 5000,
            'watchedMs': 60_000,
            'lastWatchedAt': 42,
          },
        ]),
      });
      expect(reloaded.recentVideos, hasLength(1));
      expect(reloaded.recentVideos.single['watchedMs'], 60_000);
      expect(reloaded.recentVideos.single['lastPositionMs'], 5000);
    });

    test('corrupt stored payload falls back to empty', () async {
      final reloaded = await loadWith({'recent_videos': 'not json['});
      expect(reloaded.recentVideos, isEmpty);
    });
  });

  group('recent subtitles', () {
    test('deduped by key, capped at 10, removable', () async {
      final state = await loadWith({});
      for (var i = 0; i < 14; i++) {
        state.recordRecentSubtitle({'key': 'k$i', 'name': 'n$i'});
      }
      expect(state.recentSubtitles, hasLength(10));
      expect(state.recentSubtitles.first['key'], 'k13');

      state.recordRecentSubtitle({'key': 'k1', 'name': 'again'});
      expect(state.recentSubtitles.first['key'], 'k1');
      // moved up, not duplicated
      expect(
        state.recentSubtitles.where((e) => e['key'] == 'k1'),
        hasLength(1),
      );

      state.removeRecentSubtitle('k1');
      expect(state.recentSubtitles.where((e) => e['key'] == 'k1'), isEmpty);
    });
  });
}
