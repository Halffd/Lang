import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/json_html_renderer.dart';

void main() {
  group('JsonHtmlRenderer Tests', () {
    test('render returns SizedBox.shrink for null', () {
      final widget = JsonHtmlRenderer.render(null);
      expect(widget, isA<SizedBox>());
    });

    test('render handles empty list', () {
      final widget = JsonHtmlRenderer.render(<dynamic>[]);
      expect(widget, isA<Column>());
    });

    test('render handles list of elements', () {
      final widget = JsonHtmlRenderer.render(<Map<String, dynamic>>[
        {'tag': 'p', 'data': <String, dynamic>{}, 'content': 'Hello'},
        {'tag': 'p', 'data': <String, dynamic>{}, 'content': 'World'},
      ]);
      expect(widget, isA<Column>());
    });

    test('render handles simple string value', () {
      final widget = JsonHtmlRenderer.render('Simple text');
      expect(widget, isA<Text>());
      expect((widget as Text).data, equals('Simple text'));
    });

    test('render handles div with class example-sentence', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'div',
        'data': {'class': 'example-sentence'},
        'content': <Map<String, dynamic>>[
          {'tag': 'span', 'data': <String, dynamic>{}, 'content': 'Japanese text'},
          {'tag': 'span', 'data': <String, dynamic>{}, 'content': 'English translation'},
        ],
      });
      expect(widget, isA<Container>());
    });

    test('render handles span with tag class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'span',
        'data': {'class': 'tag'},
        'title': 'noun',
        'content': 'noun',
      });
      expect(widget, isA<Container>());
    });

    test('render handles ul list', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'ul',
        'data': <String, dynamic>{},
        'content': <Map<String, dynamic>>[
          {'tag': 'li', 'data': <String, dynamic>{}, 'content': 'Item 1'},
          {'tag': 'li', 'data': <String, dynamic>{}, 'content': 'Item 2'},
        ],
      });
      expect(widget, isA<Column>());
    });

    test('render handles ol list', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'ol',
        'data': <String, dynamic>{},
        'content': <Map<String, dynamic>>[
          {'tag': 'li', 'data': <String, dynamic>{}, 'content': 'First'},
          {'tag': 'li', 'data': <String, dynamic>{}, 'content': 'Second'},
        ],
      });
      expect(widget, isA<Column>());
    });

    test('render handles link (a tag)', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'a',
        'href': 'https://example.com',
        'content': 'Click here',
      });
      expect(widget, isA<InkWell>());
    });

    test('render handles img tag', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'img',
        'data': {'src': 'image.png'},
      });
      expect(widget, isA<Icon>());
    });

    test('render handles ruby tag with base and annotation', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'ruby',
        'data': <String, dynamic>{},
        'content': <dynamic>[
          '東',
          <String, dynamic>{
            'tag': 'rt',
            'data': <String, dynamic>{},
            'content': 'ひがし',
          },
        ],
      });
      expect(widget, isA<RichText>());
    });

    test('render handles ruby with complex annotation', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'ruby',
        'data': <String, dynamic>{},
        'content': <dynamic>[
          '日本',
          <String, dynamic>{
            'tag': 'rt',
            'data': <String, dynamic>{'content': 'にほん'},
            'content': 'にほん',
          },
        ],
      });
      expect(widget, isA<RichText>());
    });

    test('render handles div with sense-group class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'div',
        'data': {'content': 'sense-group'},
        'content': 'Sense content',
      });
      expect(widget, isA<Container>());
    });

    test('render handles div with sense class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'div',
        'data': {'content': 'sense'},
        'content': 'Definition',
      });
      expect(widget, isA<Container>());
    });

    test('render handles div with glossary class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'div',
        'data': {'content': 'glossary'},
        'content': 'Glossary content',
      });
      expect(widget, isA<Text>());
    });

    test('render handles div with extra-info class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'div',
        'data': {'content': 'extra-info'},
        'content': 'Extra info',
      });
      expect(widget, isA<Container>());
    });

    test('render handles span with extra-box class', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'span',
        'data': {'class': 'extra-box'},
        'content': 'Box content',
      });
      expect(widget, isA<Container>());
    });

    test('render handles unknown tag by rendering content', () {
      final widget = JsonHtmlRenderer.render(<String, dynamic>{
        'tag': 'unknown',
        'data': <String, dynamic>{},
        'content': 'Unknown content',
      });
      expect(widget, isA<Text>());
    });
  });
}