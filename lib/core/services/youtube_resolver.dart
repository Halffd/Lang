/// YouTube source facade for the video tab: system yt-dlp when installed,
/// youtube_explode as fallback.
///
/// yt-dlp is preferred because YouTube changes its internals constantly
/// and the binary adapts within days, while a pinned Dart package does
/// not. Every backend failure falls through to the other one, so a bot
/// check on one side does not break playback when the other still works.
library;

import 'package:lang/core/services/yt_dlp_service.dart';
import 'package:lang/core/services/youtube_service.dart';
import 'package:lang/utils/subtitle_parser.dart';

class YouTubeResolver implements YouTubeBackend {
  YouTubeResolver({YtDlpService? ytDlp, YouTubeBackend? explode})
    : _ytDlp = ytDlp ?? YtDlpService(),
      _explode = explode ?? const YouTubeService();

  final YtDlpService _ytDlp;
  final YouTubeBackend _explode;

  /// Resolve a URL to metadata and the muxed quality list. Tries yt-dlp
  /// first (null or a thrown extraction means "not this backend"), then
  /// youtube_explode. Null when neither backend can serve the URL.
  @override
  Future<YouTubeVideoInfo?> resolve(String url) async {
    if (await _ytDlp.isAvailable()) {
      try {
        final info = await _ytDlp.resolve(url);
        if (info != null) return info;
      } on Object {
        // extraction failed; fall through
      }
    }
    return _explode.resolve(url);
  }

  /// Caption tracks for a video, manual tracks first. yt-dlp wins when it
  /// lists anything, otherwise the explode backend.
  @override
  Future<List<YouTubeCaptionTrack>> captionTracks(String videoId) async {
    if (await _ytDlp.isAvailable()) {
      try {
        final tracks = await _ytDlp.captionTracks(videoId);
        if (tracks.isNotEmpty) return tracks;
      } on Object {
        // extraction failed; fall through
      }
    }
    return _explode.captionTracks(videoId);
  }

  /// Fetch one caption track from whichever backend produced it: tracks
  /// carrying a direct URL belong to yt-dlp, the rest re-resolve through
  /// youtube_explode.
  @override
  Future<List<SubtitleCue>> fetchCaptions(YouTubeCaptionTrack track) {
    if (track.url != null) return _ytDlp.fetchCaptions(track);
    return _explode.fetchCaptions(track);
  }
}
