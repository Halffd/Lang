import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/subtitle_parser.dart';

void main() {
  group('parseSrt', () {
    test('parses standard SRT cues', () {
      const raw = '''
1
00:00:01,000 --> 00:00:04,000
Hello, how are you?

2
00:00:04,500 --> 00:00:07,250
I am fine, thank you.
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues, hasLength(2));
      expect(cues[0].start, 1000);
      expect(cues[0].end, 4000);
      expect(cues[0].text, 'Hello, how are you?');
      expect(cues[1].start, 4500);
      expect(cues[1].end, 7250);
    });

    test('parses WebVTT headers and dot separators', () {
      const raw = '''WEBVTT

00:00:01.500 --> 00:00:03.000
First line

00:03.000 --> 00:05.000
Second line
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues, hasLength(2));
      expect(cues[0].start, 1500);
      expect(cues[0].text, 'First line');
      // MM:SS.mmm without the hours field
      expect(cues[1].start, 3000);
      expect(cues[1].text, 'Second line');
    });

    test('joins multi-line cues', () {
      const raw = '''1
00:00:01,000 --> 00:00:04,000
first line
second line
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues.single.text, 'first line\nsecond line');
    });

    test('handles CRLF line endings', () {
      const raw = '1\r\n00:00:01,000 --> 00:00:02,000\r\nCRLF cue\r\n\r\n';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues.single.text, 'CRLF cue');
    });

    test('skips NOTE blocks and blank input', () {
      const raw = '''WEBVTT

NOTE this is a comment

00:00:01,000 --> 00:00:02,000
Real cue
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Real cue');
      expect(SubtitleParser.parseSrt(''), isEmpty);
      expect(SubtitleParser.parseSrt('   \n  '), isEmpty);
    });

    test('sorts cues that arrive out of order', () {
      const raw = '''1
00:00:09,000 --> 00:00:10,000
later

2
00:00:01,000 --> 00:00:02,000
earlier
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues.first.text, 'earlier');
      expect(cues.last.text, 'later');
    });

    test('drops entries with an unparseable timing line', () {
      const raw = '''1
garbage timing
ignored

2
00:00:01,000 --> 00:00:02,000
kept
''';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues, hasLength(1));
      expect(cues.single.text, 'kept');
    });

    test('reads hour-long timestamps', () {
      const raw = '1\n01:02:03,456 --> 01:02:04,000\nlate\n';
      final cues = SubtitleParser.parseSrt(raw);
      expect(cues.single.start, 3723456);
    });
  });

  group('SubtitleCue', () {
    test('plainText strips markup and speaker prefixes', () {
      const cue = SubtitleCue(
        start: 0,
        end: 1000,
        text: '<i>Italic</i> <c.color>text</c>\n<b>bold</b>',
      );
      expect(cue.plainText, 'Italic text bold');
    });

    test('plainText removes a Speaker: prefix', () {
      const cue = SubtitleCue(start: 0, end: 1000, text: 'Yuki: 今日はいい天気ですね');
      expect(cue.plainText, '今日はいい天気ですね');
    });

    test('contains uses a half-open interval', () {
      const cue = SubtitleCue(start: 1000, end: 2000, text: 'x');
      expect(cue.contains(const Duration(milliseconds: 1000)), isTrue);
      expect(cue.contains(const Duration(milliseconds: 1999)), isTrue);
      expect(cue.contains(const Duration(milliseconds: 2000)), isFalse);
      expect(cue.contains(const Duration(milliseconds: 999)), isFalse);
    });
  });

  group('cueAt', () {
    late List<SubtitleCue> cues;

    setUp(() {
      cues = SubtitleParser.parseSrt('''
1
00:00:01,000 --> 00:00:02,000
one

2
00:00:03,000 --> 00:00:04,000
two

3
00:00:05,000 --> 00:00:06,000
three
''');
    });

    test('finds the cue at a position', () {
      expect(
        SubtitleParser.cueAt(cues, const Duration(milliseconds: 3500))?.text,
        'two',
      );
    });

    test('returns null inside a gap and past the end', () {
      expect(
        SubtitleParser.cueAt(cues, const Duration(milliseconds: 2500)),
        isNull,
      );
      expect(
        SubtitleParser.cueAt(cues, const Duration(milliseconds: 60000)),
        isNull,
      );
    });

    test('returns null on an empty list', () {
      expect(SubtitleParser.cueAt(const [], Duration.zero), isNull);
    });

    test('binary search agrees with a linear scan over every ms', () {
      for (var ms = 0; ms < 7000; ms += 37) {
        SubtitleCue? expected;
        for (final c in cues) {
          if (ms >= c.start && ms < c.end) {
            expected = c;
            break;
          }
        }
        final actual = SubtitleParser.cueAt(cues, Duration(milliseconds: ms));
        expect(actual?.text, expected?.text, reason: 'at $ms ms');
      }
    });
  });

  group('indexAtOrBefore', () {
    late List<SubtitleCue> cues;

    setUp(() {
      cues = SubtitleParser.parseSrt('''
1
00:00:01,000 --> 00:00:02,000
one

2
00:00:03,000 --> 00:00:04,000
two
''');
    });

    test('returns the cue that has started when inside a gap', () {
      expect(
        SubtitleParser.indexAtOrBefore(
          cues,
          const Duration(milliseconds: 2500),
        ),
        0,
      );
    });

    test('returns -1 before the first cue', () {
      expect(SubtitleParser.indexAtOrBefore(cues, Duration.zero), -1);
    });

    test('returns the last cue past the end', () {
      expect(
        SubtitleParser.indexAtOrBefore(
          cues,
          const Duration(milliseconds: 90000),
        ),
        1,
      );
    });
  });

  group('parseYouTubeJson', () {
    test('parses a timedtext events payload', () {
      const raw = '''
{"events":[
  {"tStartMs":1000,"dDurationMs":2000,"segs":[{"utf8":"Hello "},{"utf8":"world"}]},
  {"tStartMs":4000,"dDurationMs":1500,"segs":[{"utf8":"Second line"}]}
]}''';
      final cues = SubtitleParser.parseYouTubeJson(raw);
      expect(cues, hasLength(2));
      expect(cues[0].start, 1000);
      expect(cues[0].end, 3000);
      expect(cues[0].text, 'Hello world');
      expect(cues[1].text, 'Second line');
    });

    test('unescapes quotes and newlines', () {
      const raw =
          '{"events":[{"tStartMs":0,"dDurationMs":1000,"segs":[{"utf8":"say \\"hi\\""},{"utf8":"\\nnow"}]}]}';
      final cues = SubtitleParser.parseYouTubeJson(raw);
      expect(cues.single.text, 'say "hi" now');
    });

    test('skips events with no text', () {
      const raw =
          '{"events":[{"tStartMs":0,"dDurationMs":1000,"segs":[]},{"tStartMs":2000,"dDurationMs":1000,"segs":[{"utf8":"kept"}]}]}';
      final cues = SubtitleParser.parseYouTubeJson(raw);
      expect(cues, hasLength(1));
      expect(cues.single.text, 'kept');
    });

    test('returns empty for non-json input', () {
      expect(SubtitleParser.parseYouTubeJson('not json'), isEmpty);
      expect(SubtitleParser.parseYouTubeJson(''), isEmpty);
    });
  });

  group('parseAuto', () {
    test('routes by extension', () {
      expect(
        SubtitleParser.parseAuto(
          '{"events":[{"tStartMs":0,"dDurationMs":1000,"segs":[{"utf8":"x"}]}]}',
          filename: 'subs.json',
        ),
        hasLength(1),
      );
      expect(
        SubtitleParser.parseAuto(
          '1\n00:00:01,000 --> 00:00:02,000\nsrt line\n',
          filename: 'subs.srt',
        ),
        hasLength(1),
      );
    });

    test('falls back to sniffing a leading brace', () {
      final cues = SubtitleParser.parseAuto(
        '{"events":[{"tStartMs":0,"dDurationMs":1000,"segs":[{"utf8":"x"}]}]}',
      );
      expect(cues.single.text, 'x');
    });
  });
}
