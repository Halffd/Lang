/// Chapter markers parsed out of a video description.
///
/// YouTube has no chapter API: chapters are declared by the creator as
/// the first lines of the description, each line starting with a
/// timestamp — `0:00 Introduction`, `1:23 - Second topic`. This parser
/// reads that convention, the same one every YouTube client uses to
/// render chapter markers on the seek bar.
library;

/// One chapter marker in a video's description.
///
/// YouTube chapters are declared as the first lines of the description
/// (`0:00 Intro`, `1:23 - Topic`), so they come from the description
/// rather than a dedicated API.
class YouTubeChapter {
  const YouTubeChapter({
    required this.title,
    required this.start,
    required this.end,
  });

  /// Chapter heading, without the leading timestamp.
  final String title;

  /// Where the chapter starts.
  final Duration start;

  /// Where the chapter ends; the next chapter's start, or the video's
  /// end for the last one.
  final Duration end;

  /// The chapter covering [position], or null when it falls outside.
  bool contains(Duration position) => position >= start && position < end;
}

/// Parses chapter markers from a video description.
class ChapterParser {
  const ChapterParser._();

  /// The minimum number of chapters that makes the list worth showing.
  /// A single timestamp in a description is usually a link to another
  /// moment, not a chapter list.
  static const int minimumChapters = 2;

  /// Parse the chapter markers out of [description].
  ///
  /// Only the leading lines are considered: YouTube requires chapters
  /// to be at the top of the description, and scanning the whole body
  /// would pick up timestamps buried in prose.
  ///
  /// Each chapter ends where the next one starts; the last one runs to
  /// the end of the video when [videoDuration] is known, and stays open
  /// ended otherwise.
  static List<YouTubeChapter> parse(
    String description, {
    Duration? videoDuration,
  }) {
    if (description.trim().isEmpty) return const [];

    final starts = <({Duration start, String title})>[];
    for (final line in description.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        // a blank line ends the chapter block
        if (starts.isNotEmpty) break;
        continue;
      }
      final parsed = _parseChapterLine(trimmed);
      if (parsed == null) {
        // the first non-empty line that is not a timestamp ends the
        // chapter block; anything after it is prose
        if (starts.isNotEmpty) break;
        continue;
      }
      starts.add(parsed);
    }

    if (starts.length < minimumChapters) return const [];

    final chapters = <YouTubeChapter>[];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i].start;
      final end = i + 1 < starts.length
          ? starts[i + 1].start
          : (videoDuration ?? _openEnded);
      // a zero-length chapter would never be reachable
      if (end != _openEnded && end <= start) continue;
      chapters.add(
        YouTubeChapter(title: starts[i].title, start: start, end: end),
      );
    }
    return chapters;
  }

  /// The end of a chapter whose real end is not known. A year is longer
  /// than any video, so the chapter still contains every playhead
  /// position inside it.
  static const Duration _openEnded = Duration(days: 365);

  /// One chapter line: a leading timestamp and the title after it.
  ///
  /// Accepts `0:00 Title`, `0:00 - Title` and `00:00:00 Title`; the
  /// dash is a separator YouTube itself writes but is not required.
  ///
  /// The timestamp must carry a colon: a bare number at the start of a
  /// line is part of the title, not a timestamp.
  static ({Duration start, String title})? _parseChapterLine(String line) {
    // hours:minutes:seconds, tried first because it is the longer form
    final hours = _hoursMinutesSeconds.firstMatch(line);
    if (hours != null) {
      final title = _titleAfter(line, hours.end);
      if (title.isEmpty) return null;
      final seconds = int.parse(hours.group(3)!);
      final minutes = int.parse(hours.group(2)!);
      if (seconds > 59 || minutes > 59) return null;
      return (
        start: Duration(
          hours: int.parse(hours.group(1)!),
          minutes: minutes,
          seconds: seconds,
        ),
        title: title,
      );
    }

    // minutes:seconds
    final mins = _minutesSeconds.firstMatch(line);
    if (mins == null) return null;
    final title = _titleAfter(line, mins.end);
    if (title.isEmpty) return null;
    final seconds = int.parse(mins.group(2)!);
    if (seconds > 59) return null;
    return (
      start: Duration(minutes: int.parse(mins.group(1)!), seconds: seconds),
      title: title,
    );
  }

  /// `H:MM:SS` at the start of a line.
  static final _hoursMinutesSeconds = RegExp(r'^(\d{1,2}):(\d{1,2}):(\d{1,2})');

  /// `M:SS` at the start of a line. Minutes run past 59 for long
  /// videos, so they take up to three digits.
  static final _minutesSeconds = RegExp(r'^(\d{1,3}):(\d{1,2})');

  /// The chapter title: whatever follows the timestamp, minus the
  /// separator YouTube writes (`-`, `–`, `—` or `:`) and whitespace.
  static String _titleAfter(String line, int timestampEnd) {
    final rest = line.substring(timestampEnd).trimLeft();
    final withoutSeparator = rest.replaceFirst(
      RegExp(r'^[-–—:]?\s*'),
      '',
    );
    return withoutSeparator.trim();
  }
}
