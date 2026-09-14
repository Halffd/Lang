// AnkiConnectService against a fake http.Client: request shape,
// result unwrapping, error propagation, timeout handling. No real
// Anki needed.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:lang/data/services/anki_connect_service.dart';

/// Routes every request to [handler]; records the last request.
class _FakeClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  http.BaseRequest? lastRequest;
  String? lastBody;

  _FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    lastBody = await request.finalize().bytesToString();
    return handler(request);
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

void main() {
  group('AnkiConnectService', () {
    test('version call shape and result unwrap', () async {
      final client = _FakeClient(
        (req) async => _jsonResponse({'result': 6, 'error': null}),
      );
      final service = AnkiConnectService('http://anki.test', client);

      final ok = await service.testConnection();
      expect(ok, isTrue);
      // send() recorded the request body
      final sent = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(sent['action'], 'version');
      expect(sent['version'], 6);
      expect(client.lastRequest!.url.toString(), 'http://anki.test');
    });

    test('anki-side error propagates as AnkiConnectException', () async {
      final client = _FakeClient(
        (req) async =>
            _jsonResponse({'result': null, 'error': 'deck not found'}),
      );
      final service = AnkiConnectService('http://anki.test', client);

      expect(
        service.getDeckNames(),
        throwsA(
          isA<AnkiConnectException>().having(
            (e) => e.message,
            'message',
            contains('deck not found'),
          ),
        ),
      );
    });

    test('non-200 status becomes AnkiConnectException', () async {
      final client = _FakeClient((req) async => _jsonResponse({}, status: 500));
      final service = AnkiConnectService('http://anki.test', client);

      // getDeckNames does not swallow: the exception surfaces
      expect(
        service.getDeckNames(),
        throwsA(
          isA<AnkiConnectException>().having(
            (e) => e.message,
            'message',
            contains('HTTP 500'),
          ),
        ),
      );
      // testConnection wraps it into false
      expect(await service.testConnection(), isFalse);
    });

    test('deckNames returns the result list', () async {
      final client = _FakeClient(
        (req) async => _jsonResponse({
          'result': ['Core 2k', 'Mining'],
          'error': null,
        }),
      );
      final service = AnkiConnectService('http://anki.test', client);

      final decks = await service.getDeckNames();
      expect(decks, ['Core 2k', 'Mining']);
    });

    test('addNote sends the note and returns the id', () async {
      final client = _FakeClient(
        (req) async => _jsonResponse({'result': 1651234, 'error': null}),
      );
      final service = AnkiConnectService('http://anki.test', client);

      final id = await service.addNote(
        deckName: 'Mining',
        modelName: 'Japanese',
        fields: {'Front': '読む', 'Back': 'to read'},
        tags: ['lang'],
      );

      expect(id, 1651234);
      final sent = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(sent['action'], 'addNote');
      final note = (sent['params'] as Map)['note'] as Map;
      expect(note['deckName'], 'Mining');
      expect(note['fields']['Front'], '読む');
      expect(note['tags'], ['lang']);
      expect(note['options']['allowDuplicate'], isFalse);
    });

    test('timeout surfaces a friendly exception', () async {
      final client = _FakeClient((req) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return _jsonResponse({'result': 1, 'error': null});
      });
      final service = AnkiConnectService('http://anki.test', client)
        ..timeout = const Duration(milliseconds: 50);

      // getDeckNames lets the mapped exception through
      expect(
        service.getDeckNames(),
        throwsA(
          isA<AnkiConnectException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('canAddNote false when the answer is false', () async {
      final client = _FakeClient(
        (req) async => _jsonResponse({
          'result': [false],
          'error': null,
        }),
      );
      final service = AnkiConnectService('http://anki.test', client);

      final can = await service.canAddNote('d', 'm', {'F': 'x'});
      expect(can, isFalse);
    });
  });
}
