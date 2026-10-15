import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for a whisper-subs transcription server — the same API the
/// WhisperSubs Android app talks to.
///
/// [transcribeForSrt] submits a source (a YouTube URL; the server
/// downloads it with yt-dlp), polls the task until it finishes, then
/// fetches the SRT the run produced. New subtitles are located by
/// diffing /subtitles/list before and after the run, so no filename
/// guessing: the server names files after the video title, which the
/// client does not know in advance.
class WhisperSubsService {
  WhisperSubsService({required this.baseUrl, this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// Server root, e.g. `http://192.168.1.10:8000`.
  final String baseUrl;

  /// API key sent as `X-API-Key` (created on the server via
  /// POST /auth/api-keys).
  final String? apiKey;

  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  Uri _uri(String path, [Map<String, String>? query]) {
    var root = baseUrl.trim();
    while (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    return Uri.parse(
      '$root$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  Map<String, String> get _headers => {
    if (apiKey != null && apiKey!.trim().isNotEmpty)
      'X-API-Key': apiKey!.trim(),
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _decodeOk(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) {
          detail = '${decoded['detail']}';
        }
      } catch (_) {
        // keep the raw body as the detail
      }
      if (response.statusCode == 401) {
        throw WhisperSubsException('unauthorized — check the API key');
      }
      throw WhisperSubsException('HTTP ${response.statusCode}: $detail');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// GET /auth/me — the cheapest call that validates both the server URL
  /// and the API key; doubles as the Settings "Test Connection" probe.
  Future<Map<String, dynamic>> authMe() async {
    final response = await _client
        .get(_uri('/auth/me'), headers: _headers)
        .timeout(_timeout);
    return _decodeOk(response);
  }

  /// GET /models — server-reachable model names (unauthenticated).
  Future<List<String>> models() async {
    final response = await _client
        .get(_uri('/models'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhisperSubsException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.cast<String>().toList();
    }
    if (decoded is Map && decoded['models'] is List) {
      return (decoded['models'] as List).cast<String>().toList();
    }
    return const [];
  }

  /// POST /transcribe — start a transcription task, returns the task id.
  Future<String> startTranscription(
    String source, {
    String model = 'large-v3',
  }) async {
    final response = await _client
        .post(
          _uri('/transcribe'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'source': source,
            'model_name': model,
            'run_mpv': false,
          }),
        )
        .timeout(_timeout);
    final decoded = await _decodeOk(response);
    final id = decoded['task_id'];
    if (id is! String || id.isEmpty) {
      throw const WhisperSubsException('server returned no task id');
    }
    return id;
  }

  /// GET /tasks/{id} — {status, progress, error, ...}.
  Future<Map<String, dynamic>> taskStatus(String taskId) async {
    final response = await _client
        .get(_uri('/tasks/$taskId'), headers: _headers)
        .timeout(_timeout);
    return _decodeOk(response);
  }

  /// GET /subtitles/list — newest first: {filename, path, created}.
  Future<List<Map<String, dynamic>>> subtitleList() async {
    final response = await _client
        .get(_uri('/subtitles/list'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhisperSubsException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const WhisperSubsException('unexpected /subtitles/list shape');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  /// GET /subtitles/{path} — the raw SRT text.
  Future<String> fetchSubtitle(String path) async {
    // Encode each segment, not the whole path: %2F inside a path
    // parameter is not decoded back into a separator by the server, but
    // spaces/brackets in titles still need encoding.
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final response = await _client
        .get(
          _uri('/subtitles/$encoded'),
          headers: {..._headers, 'Accept': 'text/plain'},
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhisperSubsException('HTTP ${response.statusCode} fetching $path');
    }
    return response.body;
  }

  /// Full flow: submit the source, poll until done, return the SRT text
  /// the run produced.
  ///
  /// [onStatus] receives a one-line progress string suitable for a
  /// waiting dialog ("processing · 42%").
  Future<String> transcribeForSrt(
    String source, {
    String model = 'large-v3',
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxWait = const Duration(minutes: 60),
    void Function(String line)? onStatus,
  }) async {
    final before = await subtitleList();
    final beforePaths = before.map((e) => e['path']).toSet();
    final taskId = await startTranscription(source, model: model);
    onStatus?.call('queued');

    final deadline = DateTime.now().add(maxWait);
    while (true) {
      await Future<void>.delayed(pollInterval);
      final status = await taskStatus(taskId);
      final state = '${status['status'] ?? ''}';
      final progress = status['progress'];
      onStatus?.call(
        progress == null || '$progress'.isEmpty ? state : '$state · $progress',
      );
      if (state == 'completed') break;
      if (state == 'failed') {
        throw WhisperSubsException(
          'transcription failed: ${status['error'] ?? 'unknown error'}',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const WhisperSubsException('timed out waiting for the task');
      }
    }

    final after = await subtitleList();
    final fresh = after.where((e) => !beforePaths.contains(e['path'])).toList();
    if (fresh.isEmpty) {
      throw const WhisperSubsException(
        'task completed but produced no new subtitle file',
      );
    }
    // Newest first is the server's sort order; the diff normally has
    // exactly one entry.
    return fetchSubtitle('${fresh.first['path']}');
  }
}

class WhisperSubsException implements Exception {
  const WhisperSubsException(this.message);

  final String message;

  @override
  String toString() => message;
}
