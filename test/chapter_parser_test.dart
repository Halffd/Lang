import 'package:flutter_test/flutter_test.dart';

import 'package:lang/utils/chapter_parser.dart';

void main() {
  group('ChapterParser.parse', () {
    test('reads the leading timestamp lines of a description', () {
      final chapters = ChapterParser.parse('''
0:00 Introduction
0:42 First topic
2:15 Second topic
''');

      expect(chapters, hasLength(3));
      expect(chapters[0].title, 'Introduction');
      expect(chapters[0].start, Duration.zero);
      expect(chapters[1].title, 'First topic');
      expect(chapters[1].start, const Duration(seconds: 42));
      expect(chapters[2].title, 'Second topic');
      expect(chapters[2].start, const Duration(minutes: 2, seconds: 15));
    });

    test('a chapter ends where the next one starts', () {
      final chapters = ChapterParser.parse('''
0:00 One
1:30 Two
3:00 Three
''');

      expect(chapters[0].end, const Duration(minutes: 1, seconds: 30));
      expect(chapters[1].end, const Duration(minutes: 3));
    });

    test('the last chapter runs to the end of the video', () {
      final chapters = ChapterParser.parse(
        '0:00 One\n2:00 Two\n',
        videoDuration: const Duration(minutes: 10),
      );

      expect(chapters.last.end, const Duration(minutes: 10));
    });

    test('the last chapter stays open ended without a duration', () {
      final chapters = ChapterParser.parse('0:00 One\n2:00 Two\n');

      expect(chapters, hasLength(2));
      expect(chapters.last.end, greaterThan(chapters.last.start));
    });

    test('accepts the dash separator YouTube writes', () {
      final chapters = ChapterParser.parse('''
0:00 - Introduction
1:00 - The main part
''');

      expect(chapters, hasLength(2));
      expect(chapters[0].title, 'Introduction');
      expect(chapters[1].title, 'The main part');
    });

    test('accepts an hour-long timestamp', () {
      final chapters = ChapterParser.parse('''
0:00 One
1:02:03 Two
''');

      expect(chapters[1].start, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('stops at the first line that is not a timestamp', () {
      final chapters = ChapterParser.parse('''
0:00 One
1:00 Two
This is prose, not a chapter.
2:00 Not a chapter
''');

      expect(chapters, hasLength(2));
      expect(chapters[1].title, 'Two');
    });

    test('ignores timestamps that appear after a blank line', () {
      // the blank line ends the chapter block, so the two timestamps
      // after it never count; one marker alone is not a chapter list
      expect(ChapterParser.parse('0:00 One\n\n2:00 Two\n'), isEmpty);
    });

    test('needs at least two markers to count as chapters', () {
      expect(ChapterParser.parse('0:00 Just one\n'), isEmpty);
      expect(ChapterParser.parse('nothing here'), isEmpty);
      expect(ChapterParser.parse(''), isEmpty);
    });

    test('drops a chapter with a non-positive length', () {
      // two markers at the same instant would make a zero-length chapter
      final chapters = ChapterParser.parse('''
0:00 One
0:00 Two
''');

      // the first chapter is dropped for having no length; the second
      // one stays, and a single remaining chapter is still listed
      expect(chapters, hasLength(1));
      expect(chapters.single.title, 'Two');
    });

    test('rejects a bare number, which is not a timestamp', () {
      expect(ChapterParser.parse('99 One\n100 Two\n'), isEmpty);
    });

    test('rejects an out-of-range seconds field', () {
      expect(ChapterParser.parse('0:75 One\n1:80 Two\n'), isEmpty);
    });
  });

  group('YouTubeChapter.contains', () {
    test('covers the span between its bounds', () {
      const chapter = YouTubeChapter(
        title: 'One',
        start: Duration(seconds: 10),
        end: Duration(seconds: 20),
      );

      expect(chapter.contains(const Duration(seconds: 10)), isTrue);
      expect(chapter.contains(const Duration(seconds: 15)), isTrue);
      expect(chapter.contains(const Duration(seconds: 19)), isTrue);
      expect(chapter.contains(const Duration(seconds: 20)), isFalse);
      expect(chapter.contains(const Duration(seconds: 5)), isFalse);
    });
  });
}
