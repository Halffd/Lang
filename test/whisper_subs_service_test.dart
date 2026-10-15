// WhisperSubsService against a fake http.Client: request shape, polling
// flow, subtitle discovery by before/after diff, error propagation.
// No real server needed.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:lang/core/services/whisper_subs_service.dart';

/// Routes every request through [handler]; records requests.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  final List<http.BaseRequest> requests = [];
  final List<String> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    bodies.add(await request.finalize().bytesToString());
    return handler(request);
  }

  void clear() {
    requests.clear();
    bodies.clear();
  }
}

http.StreamedResponse _jsonResponse(Object body, {int status = 200}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: bytes.length,
    headers: {'content-type': 'application/json'},
  );
}

http.StreamedResponse _textResponse(String body, {int status = 200}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: bytes.length,
    headers: {'content-type': 'text/plain'},
  );
}

void main() {
  test('models parses a bare list', () async {
    final client = _FakeClient(
      (req) async => _jsonResponse(['tiny', 'base', 'large-v3']),
    );
    final service = WhisperSubsService(
      baseUrl: 'http://ws.test',
      apiKey: 'key1',
      client: client,
    );
    expect(await service.models(), ['tiny', 'base', 'large-v3']);
    expect(client.requests.single.url.toString(), 'http://ws.test/models');
    expect(client.requests.single.headers['X-API-Key'], 'key1');
  });

  test('transcribeForSrt polls, diffs and fetches the new SRT', () async {
    var listCalls = 0;
    var polls = 0;
    final statuses = <String>[];
    final client = _FakeClient((req) async {
      final path = req.url.path;
      if (path == '/subtitles/list') {
        listCalls++;
        if (listCalls == 1) {
          return _jsonResponse([
            {
              'filename': 'old.srt',
              'path': 'chan/old.srt',
              'created': '2026-01-01T00:00:00',
            },
          ]);
        }
        return _jsonResponse([
          {
            'filename': 'new.srt',
            'path': 'chan/new.srt',
            'created': '2026-10-14T00:00:00',
          },
          {
            'filename': 'old.srt',
            'path': 'chan/old.srt',
            'created': '2026-01-01T00:00:00',
          },
        ]);
      }
      if (path == '/transcribe' && req.method == 'POST') {
        return _jsonResponse({
          'task_id': 'task_1',
          'status': 'pending',
          'source': 'https://youtu.be/x',
          'model_name': 'large-v3',
          'created_at': 'now',
        });
      }
      if (path == '/tasks/task_1') {
        polls++;
        return _jsonResponse(
          polls == 1
              ? {'status': 'processing', 'progress': '42%'}
              : {'status': 'completed'},
        );
      }
      if (path == '/subtitles/chan/new.srt') {
        return _textResponse('1\n00:00:01,000 --> 00:00:02,000\nhello\n');
      }
      fail('unexpected request: ${req.method} $path');
    });

    final service = WhisperSubsService(
      baseUrl: 'http://ws.test/',
      apiKey: 'key1',
      client: client,
    );
    final srt = await service.transcribeForSrt(
      'https://youtu.be/x',
      pollInterval: Duration.zero,
      onStatus: statuses.add,
    );

    expect(srt, contains('hello'));
    expect(listCalls, 2); // before/after diff
    expect(polls, 2);
    expect(statuses, ['queued', 'processing · 42%', 'completed']);
    // submit shape
    final submit = jsonDecode(client.bodies[1]) as Map<String, dynamic>;
    expect(submit['source'], 'https://youtu.be/x');
    expect(submit['model_name'], 'large-v3');
    expect(submit['run_mpv'], false);
    // trailing slash on baseUrl was trimmed
    expect(
      client.requests.first.url.toString(),
      'http://ws.test/subtitles/list',
    );
  });

  test('unauthorized surfaces a clear message', () async {
    final client = _FakeClient(
      (req) async => _jsonResponse({'detail': 'nope'}, status: 401),
    );
    final service = WhisperSubsService(
      baseUrl: 'http://ws.test',
      apiKey: 'bad',
      client: client,
    );
    await expectLater(
      service.startTranscription('https://youtu.be/x'),
      throwsA(
        isA<WhisperSubsException>().having(
          (e) => e.toString(),
          'message',
          contains('unauthorized'),
        ),
      ),
    );
  });

  test('task failure propagates the server error', () async {
    var listCalls = 0;
    var polls = 0;
    final client = _FakeClient((req) async {
      final path = req.url.path;
      if (path == '/subtitles/list') {
        listCalls++;
        return _jsonResponse([]);
      }
      if (path == '/transcribe') {
        return _jsonResponse({
          'task_id': 'task_2',
          'status': 'pending',
          'source': '',
          'model_name': 'large-v3',
          'created_at': 'now',
        });
      }
      if (path == '/tasks/task_2') {
        polls++;
        return _jsonResponse({
          'status': 'failed',
          'error': 'model download failed',
        });
      }
      fail('unexpected request: $path');
    });
    final service = WhisperSubsService(
      baseUrl: 'http://ws.test',
      apiKey: 'key1',
      client: client,
    );
    await expectLater(
      service.transcribeForSrt(
        'https://youtu.be/x',
        pollInterval: Duration.zero,
      ),
      throwsA(
        isA<WhisperSubsException>().having(
          (e) => e.message,
          'message',
          contains('model download failed'),
        ),
      ),
    );
    expect(listCalls, 1); // the after-list never happens on failure
    expect(polls, 1);
  });

  test('completion without a new subtitle file is an error', () async {
    var listCalls = 0;
    final client = _FakeClient((req) async {
      final path = req.url.path;
      if (path == '/subtitles/list') {
        listCalls++;
        return _jsonResponse([
          {
            'filename': 'old.srt',
            'path': 'chan/old.srt',
            'created': '2026-01-01T00:00:00',
          },
        ]);
      }
      if (path == '/transcribe') {
        return _jsonResponse({
          'task_id': 'task_3',
          'status': 'pending',
          'source': '',
          'model_name': 'large-v3',
          'created_at': 'now',
        });
      }
      if (path == '/tasks/task_3') {
        return _jsonResponse({'status': 'completed'});
      }
      fail('unexpected request: $path');
    });
    final service = WhisperSubsService(
      baseUrl: 'http://ws.test',
      apiKey: 'key1',
      client: client,
    );
    await expectLater(
      service.transcribeForSrt(
        'https://youtu.be/x',
        pollInterval: Duration.zero,
      ),
      throwsA(
        isA<WhisperSubsException>().having(
          (e) => e.message,
          'message',
          contains('no new subtitle'),
        ),
      ),
    );
    expect(listCalls, 2);
  });
}
