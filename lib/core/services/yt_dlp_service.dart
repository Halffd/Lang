/// System yt-dlp backend for the video tab's YouTube source.
///
/// Preferred over youtube_explode when installed: YouTube changes its
/// internals constantly and yt-dlp adapts within days, while a pinned
/// Dart package does not. Resolution runs `yt-dlp -J --skip-download`
/// and parses the JSON it prints; captions reuse the timedtext URLs the
/// extraction returns, so nothing is downloaded to disk.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:lang/core/services/youtube_service.dart';
import 'package:lang/utils/subtitle_parser.dart';

/// Runs a subprocess; injectable so tests can fake yt-dlp output.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Resolves YouTube videos and captions through the system yt-dlp binary.
class YtDlpService implements YouTubeBackend {
  YtDlpService({
    ProcessRunner? runProcess,
    String command = 'yt-dlp',
    Duration timeout = const Duration(seconds: 90),
  }) : _runProcess = runProcess ?? Process.run,
       _command = command,
       _timeout = timeout;

  final ProcessRunner _runProcess;
  final String _command;
  final Duration _timeout;

  bool? _available;

  /// Probe once per instance: `yt-dlp --version`. A missing binary exits
  /// with a ProcessException from Process.run, not a non-zero code.
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      final result = await _runProcess(_command, const [
        '--version',
      ]).timeout(_timeout);
      _available = result.exitCode == 0;
    } on Object {
      _available = false;
    }
    return _available!;
  }

  /// Resolve a URL to metadata and the muxed quality list, or null when
  /// yt-dlp is unavailable, the extraction fails (bot checks, unknown
  /// URL) or the video has no muxed stream. The caller falls back to the
  /// explode backend, so failing soft here is the contract.
  @override
  Future<YouTubeVideoInfo?> resolve(String url) async {
    if (!await isAvailable()) return null;
    final json = await _extract(url);
    if (json == null) return null;
    return videoInfoFromJson(json);
  }

  /// Text search via yt-dlp's `ytsearch<N>:<query>` pseudo-URL with
  /// `--flat-playlist` (metadata only, no per-video extraction, so it
  /// stays fast). Fails soft: empty list on any problem.
  @override
  Future<List<YouTubeSearchHit>> search(String query, {int limit = 10}) async {
    if (!await isAvailable()) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final result = await _runProcess(_command, [
        '-J',
        '--flat-playlist',
        '--no-warnings',
        'ytsearch${limit.clamp(1, 20)}:$q',
      ]).timeout(_timeout);
      if (result.exitCode != 0) return const [];
      final decoded = jsonDecode(result.stdout.toString());
      if (decoded is! Map) return const [];
      final entries = decoded['entries'];
      if (entries is! List) return const [];
      return [
        for (final e in entries)
          if (e is Map)
            YouTubeSearchHit(
              videoId: (e['id'] ?? '').toString(),
              title: (e['title'] ?? '').toString(),
              author: (e['uploader'] ?? e['channel'] ?? '').toString(),
              duration: (e['duration'] as num?)?.toInt(),
            ),
      ].where((h) => h.videoId.isNotEmpty).toList();
    } on Object {
      return const [];
    }
  }

  /// Caption tracks for a video, manual tracks first. yt-dlp accepts a
  /// bare video ID only as a search query, so the watch URL is rebuilt.
  @override
  Future<List<YouTubeCaptionTrack>> captionTracks(String videoId) async {
    if (!await isAvailable()) return const [];
    final json = await _extract('https://www.youtube.com/watch?v=$videoId');
    if (json == null) return const [];
    return captionTracksFromJson(json, videoId);
  }

  /// Fetch one of this backend's caption tracks. The track's URL is a
  /// direct timedtext link in a parseable format, fetched and parsed
  /// here; it expires within hours, matching the extraction session.
  @override
  Future<List<SubtitleCue>> fetchCaptions(YouTubeCaptionTrack track) async {
    final url = track.url;
    if (url == null) {
      throw Exception('yt-dlp track has no direct caption URL');
    }
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('caption fetch failed: ${response.statusCode}');
    }
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
    // parseAuto sniffs vtt/srt/YouTube-JSON from the content itself
    final cues = SubtitleParser.parseAuto(
      raw,
      filename: '${track.languageCode}.vtt',
    );
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// Run `yt-dlp -J` and decode its JSON, or null on failure.
  Future<Map<String, dynamic>?> _extract(String url) async {
    try {
      final result = await _runProcess(_command, [
        '-J',
        '--skip-download',
        url,
      ]).timeout(_timeout);
      if (result.exitCode != 0) return null;
      final decoded = jsonDecode(result.stdout as String);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  /// Build the resolved video from `yt-dlp -J` output. Muxed formats only
  /// (both audio and video codecs present), labeled by height and fed
  /// through the same normalization as the explode backend. Returns null
  /// when the JSON has no usable muxed stream.
  static YouTubeVideoInfo? videoInfoFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final formats = json['formats'];
    final muxed = <({String url, String qualityLabel})>[];
    if (formats is List) {
      for (final raw in formats) {
        if (raw is! Map<String, dynamic>) continue;
        final vcodec = raw['vcodec']?.toString() ?? 'none';
        final acodec = raw['acodec']?.toString() ?? 'none';
        if (vcodec == 'none' || acodec == 'none') continue;
        final url = raw['url']?.toString();
        final height = raw['height'];
        if (url == null || url.isEmpty || height is! num) continue;
        muxed.add((url: url, qualityLabel: '${height.toInt()}p'));
      }
    }

    final qualities = YouTubeService.qualityOptions(muxed);
    if (qualities.isEmpty) return null;

    return YouTubeVideoInfo(
      videoId: id,
      title: json['title']?.toString() ?? '',
      author: json['uploader']?.toString() ?? json['channel']?.toString() ?? '',
      qualities: qualities,
    );
  }

  /// Caption tracks from `yt-dlp -J` output: manual `subtitles` first,
  /// then `automatic_captions`, one track per language. Only formats the
  /// local parsers understand are kept (vtt, srt, json3); XML variants
  /// (srv*/ttml) are skipped because nothing parses them.
  static List<YouTubeCaptionTrack> captionTracksFromJson(
    Map<String, dynamic> json,
    String videoId,
  ) {
    final tracks = <YouTubeCaptionTrack>[];
    final seen = <String>{};
    for (final auto in const [false, true]) {
      final map = json[auto ? 'automatic_captions' : 'subtitles'];
      if (map is! Map<String, dynamic>) continue;
      // languages arrive unordered; sort so the listing is stable
      final languages = map.keys.map((k) => k.toString()).toList()..sort();
      for (final lang in languages) {
        // the same language can exist as a manual and an autogenerated
        // track; both are offered, deduping only protects against the
        // same kind appearing twice
        if (!seen.add('$lang${auto ? ':auto' : ''}')) continue;
        final variants = map[lang];
        if (variants is! List) continue;
        final pick = _pickVariant(variants);
        if (pick == null) continue;
        tracks.add(
          YouTubeCaptionTrack(
            videoId: videoId,
            url: pick['url']?.toString(),
            languageCode: lang,
            languageName: pick['name']?.toString() ?? lang,
            autoGenerated: auto,
          ),
        );
      }
    }
    return tracks;
  }

  /// Prefer vtt (the subtitle parser handles it directly), then srt, then
  /// json3 (parsed by the YouTube JSON parser). Null when none remain.
  static Map<String, dynamic>? _pickVariant(List<dynamic> variants) {
    for (final ext in const ['vtt', 'srt', 'json3']) {
      for (final variant in variants) {
        if (variant is! Map<String, dynamic>) continue;
        if (variant['ext']?.toString() != ext) continue;
        final url = variant['url']?.toString();
        if (url == null || url.isEmpty) continue;
        return variant;
      }
    }
    return null;
  }
}
