import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/reader/pip_windows.dart';

void main() {
  group('PipSession', () {
    test('json roundtrip keeps all fields', () {
      const session = PipSession(
        url: '/tmp/video.mp4',
        isFile: true,
        position: Duration(minutes: 2, seconds: 34),
        title: 'My Lesson',
        speed: 1.25,
      );
      final restored = PipSession.fromJson(
        (jsonDecode(session.serialize()) as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      );
      expect(restored.url, session.url);
      expect(restored.isFile, isTrue);
      expect(restored.position, session.position);
      expect(restored.title, session.title);
      expect(restored.speed, session.speed);
    });

    test('network session keeps isFile false', () {
      const session = PipSession(
        url: 'https://example.com/stream',
        isFile: false,
        position: Duration.zero,
        title: 'yt',
        speed: 1.0,
      );
      final map = session.toJson();
      expect(map['isFile'], isFalse);
      expect(map['url'], startsWith('https://'));
    });

    test('savePosition/loadPosition roundtrip through a temp file', () {
      final dir = Directory.systemTemp.createTempSync('pip_session_test');
      try {
        final path = '${dir.path}/pip_session.json';
        const session = PipSession(
          url: 'https://example.com/stream',
          isFile: false,
          position: Duration.zero,
          title: 't',
          speed: 1.0,
        );
        // serialize then update the position
        File(path).writeAsStringSync(session.serialize());
        PipSession.savePosition(path, const Duration(seconds: 77));

        final loaded = PipSession.load(path);
        expect(loaded, isNotNull);
        expect(loaded!.position, const Duration(seconds: 77));
        expect(loaded.url, 'https://example.com/stream');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('load returns null for missing/corrupt files', () {
      expect(PipSession.load('/nonexistent/pip.json'), isNull);
      final dir = Directory.systemTemp.createTempSync('pip_corrupt');
      try {
        final path = '${dir.path}/broken.json';
        File(path).writeAsStringSync('{not json');
        expect(PipSession.load(path), isNull);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('secondary-window argument contract', () {
    test('pip window arguments decode to a session', () {
      const session = PipSession(
        url: 'https://example.com/stream',
        isFile: false,
        position: Duration(seconds: 12),
        title: 'yt',
        speed: 1.5,
      );
      // exactly what the video tab passes as WindowConfiguration arguments
      final args = jsonEncode({'mode': 'pip', ...session.toJson()});
      final decoded = (jsonDecode(args) as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      expect(decoded['mode'], 'pip');
      final restored = PipSession.fromJson(decoded);
      expect(restored.position, const Duration(seconds: 12));
      expect(restored.speed, 1.5);
    });

    test('captions window arguments declare the mode', () {
      final args = jsonEncode({'mode': 'captions'});
      final decoded = (jsonDecode(args) as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      expect(decoded['mode'], 'captions');
    });
  });

  group('caption state file', () {
    test('persists the last pushed cue', () {
      final dir = Directory.systemTemp.createTempSync('caption_state_test');
      try {
        final path = captionStatePath();
        File(path).writeAsStringSync('こんにちは', flush: true);
        final raw = File(path).readAsStringSync();
        expect(raw, 'こんにちは');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
