// HtmlSanitizer XSS regression suite: untrusted HTML from
// wiktionary/wikipedia scrapers passes through here before
// rendering, so every classic vector must be neutralized.

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/utils/html_sanitizer.dart';

void main() {
  group('HtmlSanitizer.sanitize', () {
    test('allowed markup survives', () {
      final out = HtmlSanitizer.sanitize('<p>hello <b>bold</b> <i>it</i></p>');
      expect(out, contains('<b>bold</b>'));
      expect(out, contains('<i>it</i>'));
    });

    test('script tags are stripped', () {
      final out = HtmlSanitizer.sanitize('<p>ok</p><script>alert(1)</script>');
      expect(out, isNot(contains('script')));
      expect(out, isNot(contains('alert')));
      expect(out, contains('ok'));
    });

    test('iframe/svg/object embeds are stripped', () {
      for (final tag in ['iframe', 'svg', 'object', 'embed', 'form']) {
        final out = HtmlSanitizer.sanitize('<$tag>x</$tag>');
        expect(out, isNot(contains('<$tag')), reason: tag);
      }
    });

    test('javascript: href is removed', () {
      final out = HtmlSanitizer.sanitize(
        '<a href="javascript:alert(1)">click</a>',
      );
      expect(out, isNot(contains('javascript:')));
      expect(out, contains('click'));
    });

    test('data: href is removed', () {
      final out = HtmlSanitizer.sanitize(
        '<a href="data:text/html;base64,PHNjcmlwdD4=">x</a>',
      );
      expect(out, isNot(contains('data:')));
    });

    test('uppercase/mixed case javascript href is removed', () {
      final out = HtmlSanitizer.sanitize('<a href="JaVaScRiPt:alert(1)">x</a>');
      expect(out.toLowerCase(), isNot(contains('javascript:')));
    });

    test('onerror attribute is dropped', () {
      final out = HtmlSanitizer.sanitize(
        '<img src="http://x/i.png" onerror="alert(1)">',
      );
      expect(out, isNot(contains('onerror')));
    });

    test('onclick on any allowed tag is dropped', () {
      final out = HtmlSanitizer.sanitize('<p onclick="alert(1)">text</p>');
      expect(out, isNot(contains('onclick')));
      expect(out, contains('text'));
    });

    test('external links get noopener + blank target', () {
      final out = HtmlSanitizer.sanitize(
        '<a href="https://en.wikipedia.org/wiki/猫">wiki</a>',
      );
      expect(out, contains('rel="noopener noreferrer"'));
      expect(out, contains('target="_blank"'));
      expect(out, contains('https://en.wikipedia.org'));
    });

    test('relative and anchor links survive', () {
      expect(
        HtmlSanitizer.sanitize('<a href="/wiki/x">a</a>'),
        contains('/wiki/x'),
      );
      expect(HtmlSanitizer.sanitize('<a href="#sec">a</a>'), contains('#sec'));
    });

    test('style allows safe declarations, drops url() and expression()', () {
      final out = HtmlSanitizer.sanitize(
        '<p style="color: red; position: fixed; '
        'background: url(javascript:alert(1)); width: expression(alert(2))">x</p>',
      );
      expect(out, contains('color: red'));
      expect(out, isNot(contains('url(')));
      expect(out, isNot(contains('expression')));
      expect(out, isNot(contains('position')));
    });

    test('style url ( with space cannot bypass the filter', () {
      final out = HtmlSanitizer.sanitize(
        '<p style="background-color: url (javascript:alert(1))">x</p>',
      );
      expect(out, isNot(contains('url (')));
      expect(out, isNot(contains('javascript')));
    });

    test('img with http source and alt survives', () {
      final out = HtmlSanitizer.sanitize(
        '<img src="https://x/a.png" alt="pic">',
      );
      expect(out, contains('https://x/a.png'));
      expect(out, contains('pic'));
    });

    test('img with javascript src is removed', () {
      final out = HtmlSanitizer.sanitize('<img src="javascript:alert(1)">');
      expect(out.toLowerCase(), isNot(contains('javascript')));
    });

    test('nested script inside allowed tag is stripped', () {
      final out = HtmlSanitizer.sanitize(
        '<div><p>text<script>evil()</script></p></div>',
      );
      expect(out, isNot(contains('script')));
      expect(out, isNot(contains('evil')));
      expect(out, contains('text'));
    });

    test('empty input', () {
      expect(HtmlSanitizer.sanitize(''), '');
    });

    test('plain text is unchanged', () {
      expect(HtmlSanitizer.sanitize('just text'), contains('just text'));
    });
  });
}
