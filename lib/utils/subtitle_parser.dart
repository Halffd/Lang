/// One timed line of dialogue, in either a subtitle file or a
/// player-generated caption track.
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
    this.speaker,
  });

  /// Milliseconds from the start of the media.
  final int start;
  final int end;
  final String text;

  /// Speaker label when the track declares one (ASS/SSA `Name:` fields).
  final String? speaker;

  Duration get startDuration => Duration(milliseconds: start);
  Duration get endDuration => Duration(milliseconds: end);
  int get durationMs => end - start;

  /// The cue covering [position], or null when the position falls in a gap.
  bool contains(Duration position) =>
      position.inMilliseconds >= start && position.inMilliseconds < end;

  /// Text with WebVTT/SRT markup removed, for dictionary lookups.
  String get plainText {
    var t = text;
    // <i>, <b>, <c.classname>, <00:00:01.000> inline tags
    t = t.replaceAll(RegExp(r'<[^>]*>'), '');
    // SRT/WebVTT speaker prefix like "Speaker: "
    t = t.replaceAll(RegExp(r'^\s*[A-Z][^:\n]{0,20}:\s*'), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  String toString() =>
      'SubtitleCue(${start}ms-${end}ms, "${text.length > 20 ? '${text.substring(0, 20)}...' : text}")';
}

/// Parsers for the subtitle formats that turn up alongside language-learning
/// video: SubRip (.srt), WebVTT (.vtt) and the YouTube-style JSON timedtext
/// export. All take raw text and return cues sorted by start time, so the
/// transcript can be binary-searched or shown in order.
class SubtitleParser {
  const SubtitleParser._();

  /// Parse SRT or WebVTT. The two overlap heavily: both use index lines
  /// followed by `00:00:01,000 --> 00:00:04,000`, differing in the comma
  /// versus dot millisecond separator and WebVTT's `WEBVTT` header.
  static List<SubtitleCue> parseSrt(String raw) {
    final cues = <SubtitleCue>[];
    if (raw.trim().isEmpty) return cues;

    final blocks = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n\n');
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      var i = 0;
      // skip a WEBVTT header, a NOTE block, or a leading cue index
      if (lines.first.toUpperCase().startsWith('WEBVTT')) i = 1;
      if (i >= lines.length) continue;
      if (lines[i].contains('-->')) {
        // no index line, the timing line comes first
      } else if (int.tryParse(lines[i]) != null ||
          lines[i].startsWith('NOTE')) {
        i++;
      }
      if (i >= lines.length) continue;

      final timing = _parseTimingLine(lines[i]);
      if (timing == null) continue;
      i++;
      if (i >= lines.length) continue;

      final text = lines.sublist(i).join('\n');
      if (text.trim().isEmpty) continue;

      // WebVTT may prefix a cue identifier and carry settings after the times
      final settings = timing.$3;
      cues.add(
        SubtitleCue(
          start: timing.$1,
          end: timing.$2,
          text: text.trim(),
          speaker: settings.isEmpty ? null : settings,
        ),
      );
    }
    return _sorted(cues);
  }

  /// `-->` line: `00:00:01,000 --> 00:00:04,000 align:start position:0%`
  /// Returns (startMs, endMs, settings).
  static (int, int, String)? _parseTimingLine(String line) {
    if (!line.contains('-->')) return null;
    final parts = line.split('-->');
    if (parts.length < 2) return null;
    final start = _parseTimestamp(parts[0]);
    final rest = parts[1].trim();
    // trailing cue settings, if any, sit after the end timestamp
    final endToken = rest.split(RegExp(r'\s+')).first;
    final end = _parseTimestamp(endToken);
    if (start == null || end == null) return null;
    final settings = rest.length > endToken.length
        ? rest.substring(endToken.length).trim()
        : '';
    return (start, end, settings);
  }

  /// Accepts `HH:MM:SS,mmm`, `HH:MM:SS.mmm`, `MM:SS,mmm`, and a bare
  /// `SS,mmm`; also the `h:mm:ss.cc` centisecond form some tools emit.
  static int? _parseTimestamp(String raw) {
    var s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    // trailing alignment artefacts some muxers append
    s = s.replaceAll(RegExp(r'[^0-9:.]'), '');
    if (s.isEmpty) return null;

    final parts = s.split(':');
    if (parts.length > 3) return null;

    int hours = 0, minutes = 0;
    double seconds;
    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      seconds = double.tryParse(parts[2]) ?? 0;
    } else if (parts.length == 2) {
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = double.tryParse(parts[1]) ?? 0;
    } else {
      seconds = double.tryParse(parts[0]) ?? 0;
    }
    if (seconds.isNaN) return null;
    return ((hours * 3600 + minutes * 60) * 1000 + (seconds * 1000).round())
        .toInt();
  }

  /// YouTube's timedtext JSON export: a flat list of events where each
  /// `segs` entry is a run of text and `tStartMs`/`dDurationMs` give the span.
  static List<SubtitleCue> parseYouTubeJson(String raw) {
    final cues = <SubtitleCue>[];
    // deliberately tolerant: accept the object form with an `events` list
    final eventsMatch = RegExp(
      r'"events"\s*:\s*(\[.*)',
      dotAll: true,
    ).firstMatch(raw);
    if (eventsMatch == null) return cues;
    final eventsJson = eventsMatch.group(1)!;

    // walk the array by brace depth so we do not need a full JSON decoder on
    // a payload that is usually well-formed but sometimes truncated
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < eventsJson.length; i++) {
      final c = eventsJson[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
        continue;
      }
      if (c == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && start >= 0) {
          final obj = eventsJson.substring(start, i + 1);
          final cue = _parseYouTubeEvent(obj);
          if (cue != null) cues.add(cue);
          start = -1;
        }
      }
    }
    return _sorted(cues);
  }

  static SubtitleCue? _parseYouTubeEvent(String obj) {
    final startMs = int.tryParse(
      RegExp(r'"tStartMs"\s*:\s*"?(\d+)"?').firstMatch(obj)?.group(1) ?? '',
    );
    if (startMs == null) return null;
    final durMs =
        int.tryParse(
          RegExp(r'"dDurationMs"\s*:\s*"?(\d+)"?').firstMatch(obj)?.group(1) ??
              '',
        ) ??
        0;

    final text = _joinSegs(obj);
    if (text.isEmpty) return null;

    return SubtitleCue(
      start: startMs,
      end: durMs > 0 ? startMs + durMs : startMs + 2000,
      text: text,
    );
  }

  /// Join every `utf8` run in a `segs` array into one line.
  ///
  /// Scans for the string bodies by hand rather than with a regex: the runs
  /// may contain escaped quotes, and a non-greedy `"(.*?)"` stops at the first
  /// escaped quote and truncates the line.
  static String _joinSegs(String obj) {
    final segsIdx = obj.indexOf('"segs"');
    if (segsIdx < 0) return '';
    final open = obj.indexOf('[', segsIdx);
    if (open < 0) return '';

    final buf = StringBuffer();
    var i = open;
    while (i < obj.length) {
      final keyAt = obj.indexOf('"utf8"', i);
      if (keyAt < 0) break;
      final colon = obj.indexOf(':', keyAt);
      if (colon < 0) break;
      var p = colon + 1;
      while (p < obj.length && obj[p] != '"') {
        p++;
      }
      if (p >= obj.length) break;
      p++; // consume the opening quote

      final body = StringBuffer();
      var escaped = false;
      while (p < obj.length) {
        final c = obj[p];
        if (escaped) {
          // decode the single-character escapes here: this loop owns the
          // backslash, so an \n cannot survive as a literal n
          if (c == 'n' || c == 't') {
            body.write(' ');
          } else {
            body.write(c);
          }
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          break;
        } else {
          body.write(c);
        }
        p++;
      }
      // segments are adjacent runs, so join them with a space or a run
      // that ends mid-word would fuse with the next one
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(body.toString());
      i = p + 1;
    }

    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<SubtitleCue> _sorted(List<SubtitleCue> cues) {
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// The cue covering [position], via binary search over sorted cues.
  static SubtitleCue? cueAt(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return null;
    var lo = 0;
    var hi = cues.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final cue = cues[mid];
      if (position.inMilliseconds < cue.start) {
        hi = mid - 1;
      } else if (position.inMilliseconds >= cue.end) {
        lo = mid + 1;
      } else {
        return cue;
      }
    }
    return null;
  }

  /// Index of the last cue that has already started, for transcript
  /// highlighting when the playhead sits in a gap between lines.
  static int indexAtOrBefore(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return -1;
    var lo = 0;
    var hi = cues.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= position.inMilliseconds) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /// Guess the format from a filename so the picker can pick a parser.
  static List<SubtitleCue> parseAuto(String raw, {String? filename}) {
    final f = (filename ?? '').toLowerCase();
    if (f.endsWith('.json')) return parseYouTubeJson(raw);
    if (raw.trimLeft().startsWith('{')) return parseYouTubeJson(raw);
    return parseSrt(raw);
  }
}
