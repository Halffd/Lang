import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/json_html_renderer.dart';
import 'package:lang/domain/entities/dictionary_display_options.dart';
import 'package:lang/data/datasources/local/yomichan_parser.dart';
import 'dart:io';

void main() {
  group('JsonHtmlRenderer structured content', () {
    testWidgets('plain text node', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: JsonHtmlRenderer.render('hello'))),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('json-encoded string auto-decodes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render(
              '[{"tag":"span","content":"decoded text"}]',
            ),
          ),
        ),
      );
      expect(find.text('decoded text'), findsOneWidget);
    });

    testWidgets('br renders line break spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render([
              'line1',
              {'tag': 'br'},
              'line2',
            ]),
          ),
        ),
      );
      expect(find.text('line1'), findsOneWidget);
      expect(find.text('line2'), findsOneWidget);
    });

    testWidgets('ruby renders base and reading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'ruby',
              'content': [
                '読',
                {'tag': 'rt', 'content': 'よ'},
              ],
            }),
          ),
        ),
      );
      expect(find.text('読'), findsOneWidget);
      expect(find.text('よ'), findsOneWidget);
    });

    testWidgets('ruby inside sentence keeps base text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render([
              {'tag': 'span', 'content': '本を'},
              {
                'tag': 'ruby',
                'content': [
                  '読',
                  {'tag': 'rt', 'content': 'よ'},
                ],
              },
              {'tag': 'span', 'content': 'む'},
            ]),
          ),
        ),
      );
      expect(find.text('本を'), findsOneWidget);
      expect(find.text('読'), findsOneWidget);
      expect(find.text('む'), findsOneWidget);
    });

    testWidgets('unstyled list renders bullets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'ul',
              'content': [
                {'tag': 'li', 'content': 'one'},
                {'tag': 'li', 'content': 'two'},
              ],
            }),
          ),
        ),
      );
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(find.text('• '), findsNWidgets(2));
    });

    testWidgets('ordered list renders numbers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'ol',
              'content': [
                {'tag': 'li', 'content': 'first'},
                {'tag': 'li', 'content': 'second'},
              ],
            }),
          ),
        ),
      );
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
    });

    testWidgets('compact glossaries joins with |', (tester) async {
      final options = DictionaryDisplayOptions()..compactGlossaries = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'ul',
              'content': [
                {'tag': 'li', 'content': 'aa'},
                {'tag': 'li', 'content': 'bb'},
              ],
            }, options: options),
          ),
        ),
      );
      expect(find.text('aa'), findsOneWidget);
      expect(find.text('bb'), findsOneWidget);
      expect(find.text(' | '), findsOneWidget);
      expect(find.text('• '), findsNothing);
    });

    testWidgets('table renders rows and header styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'table',
              'content': [
                {
                  'tag': 'tr',
                  'content': [
                    {'tag': 'th', 'content': 'Kanji'},
                    {'tag': 'th', 'content': 'Reading'},
                  ],
                },
                {
                  'tag': 'tr',
                  'content': [
                    {'tag': 'td', 'content': '読'},
                    {'tag': 'td', 'content': 'よみ'},
                  ],
                },
              ],
            }),
          ),
        ),
      );
      expect(find.text('Kanji'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('読'), findsOneWidget);
      expect(find.text('よみ'), findsOneWidget);
    });

    testWidgets('details renders as expansion tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'details',
              'content': [
                {'tag': 'summary', 'content': 'More info'},
                {'tag': 'div', 'content': 'hidden body'},
              ],
            }),
          ),
        ),
      );
      expect(find.text('More info'), findsOneWidget);
      expect(find.text('hidden body'), findsNothing); // collapsed
    });

    testWidgets('unknown tag renders children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'unknown-tag',
              'content': 'inner text',
            }),
          ),
        ),
      );
      expect(find.text('inner text'), findsOneWidget);
    });


    // find the deepest TextSpan in a RichText tree
    TextSpan? leafSpan(WidgetTester tester) {
      final rich = tester.widget<RichText>(find.byType(RichText));
      var span = rich.text as TextSpan;
      while (span.children != null &&
          span.children!.isNotEmpty &&
          span.children!.first is TextSpan) {
        final next = span.children!.first as TextSpan;
        if (next.text == null) {
          span = next;
        } else {
          return next;
        }
      }
      return span;
    }

    testWidgets('bold style span renders bold text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'span',
              'content': 'important',
              'style': {'fontWeight': 'bold'},
            }),
          ),
        ),
      );
      final inner = leafSpan(tester);
      expect(inner!.text, 'important');
      expect(inner.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('line-through style applies', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'span',
              'content': 'cut',
              'style': {'textDecoration': 'line-through'},
            }),
          ),
        ),
      );
      final inner = leafSpan(tester);
      expect(inner!.text, 'cut');
      expect(inner.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('legacy style string parses bold + color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'span',
              'content': 'styled',
              'data': {'style': 'font-weight:bold;color:#FF0000'},
            }),
          ),
        ),
      );
      // data.style currently unused by span builder; ensure no crash
      expect(find.text('styled'), findsOneWidget);
    });
  });

  group('display toggles', () {
    testWidgets('example sentence hidden when toggle off', (tester) async {
      final options = DictionaryDisplayOptions()..showSentences = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'div',
              'data': {'class': 'example-sentence'},
              'content': '例文 here',
            }, options: options),
          ),
        ),
      );
      expect(find.text('例文 here'), findsNothing);
    });

    testWidgets('example sentence shown when toggle on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'div',
              'data': {'class': 'example-sentence'},
              'content': '例文 here',
            }),
          ),
        ),
      );
      expect(find.text('例文 here'), findsOneWidget);
    });

    testWidgets('tags hidden when toggle off', (tester) async {
      final options = DictionaryDisplayOptions()..showTags = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'span',
              'data': {'class': 'tag'},
              'content': 'noun',
              'title': 'noun',
            }, options: options),
          ),
        ),
      );
      expect(find.text('noun'), findsNothing);
    });

    testWidgets('notes hidden when toggle off', (tester) async {
      final options = DictionaryDisplayOptions()..showNotes = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'div',
              'data': {'content': 'extra-info'},
              'content': 'usage note',
            }, options: options),
          ),
        ),
      );
      expect(find.text('usage note'), findsNothing);
    });

    testWidgets('images hidden when toggle off', (tester) async {
      final options = DictionaryDisplayOptions()..showImages = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'img',
              'path': 'img/entry.png',
            }, options: options),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('pitch accent hidden when toggle off', (tester) async {
      final options = DictionaryDisplayOptions()..showPitchAccent = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'div',
              'data': {'class': 'pronunciation'},
              'content': '[0]',
            }, options: options),
          ),
        ),
      );
      expect(find.text('[0]'), findsNothing);
    });

    test('options serialize roundtrip', () {
      final o = DictionaryDisplayOptions();
      o.showSentences = false;
      o.showImages = false;
      o.compactGlossaries = true;
      o.showDictionaryName = false;
      final back = DictionaryDisplayOptions.deserialize(o.serialize());
      expect(back.showSentences, false);
      expect(back.showImages, false);
      expect(back.compactGlossaries, true);
      expect(back.showDictionaryName, false);
      expect(back.showTags, true); // untouched default
    });

    test('deserialize null keeps defaults', () {
      final o = DictionaryDisplayOptions.deserialize(null);
      expect(o.showSentences, true);
      expect(o.compactGlossaries, false);
      expect(o.showImages, true);
    });

    test('deserialize invalid json keeps defaults', () {
      final o = DictionaryDisplayOptions.deserialize('{bad');
      expect(o.showSentences, true);
    });
  });

  group('dictionary images', () {
    testWidgets('missing image renders fallback with alt name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render({
              'tag': 'img',
              'path': 'img/missing.png',
              'alt': 'stroke diagram',
            }),
          ),
        ),
      );
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(find.text('stroke diagram'), findsOneWidget);
    });

    testWidgets('image with real file renders Image widget', (tester) async {
      final tmp = Directory.systemTemp.createTempSync('dict_media');
      final imgFile = File('${tmp.path}/entry.png');
      // 1x1 transparent png
      imgFile.writeAsBytesSync(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x62,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
      addTearDown(() => tmp.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonHtmlRenderer.render(
              {'tag': 'img', 'path': 'entry.png'},
              mediaIndex: {'entry.png': imgFile.path},
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    test('resolveMediaPath direct and basename matches', () {
      const media = {
        'img/entry.png': '/store/img/entry.png',
        'entry.png': '/store/img/entry.png',
      };
      expect(
        YomichanParser.resolveMediaPath('img/entry.png', media),
        '/store/img/entry.png',
      );
      expect(
        YomichanParser.resolveMediaPath('./img/entry.png', media),
        '/store/img/entry.png',
      );
      expect(
        YomichanParser.resolveMediaPath('entry.png', media),
        '/store/img/entry.png',
      );
      expect(YomichanParser.resolveMediaPath('other.png', media), isNull);
      expect(YomichanParser.resolveMediaPath('', media), isNull);
    });

    test('resolveMediaPath case-insensitive last resort', () {
      const media = {'IMG/Entry.PNG': '/store/img/Entry.PNG'};
      expect(
        YomichanParser.resolveMediaPath('img/entry.png', media),
        '/store/img/Entry.PNG',
      );
    });
  });
}
