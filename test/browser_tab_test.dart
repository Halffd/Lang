import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/reader/browser_tab.dart';

void main() {
  group('normalizeBrowserUrl', () {
    test('passes full urls through', () {
      expect(
        normalizeBrowserUrl('https://www3.nhk.or.jp/news/easy/'),
        'https://www3.nhk.or.jp/news/easy/',
      );
      expect(
        normalizeBrowserUrl('http://example.com/a?b=c'),
        'http://example.com/a?b=c',
      );
    });

    test('adds https to bare hosts', () {
      expect(normalizeBrowserUrl('example.com'), 'https://example.com');
      expect(normalizeBrowserUrl('tatoeba.org/en'), 'https://tatoeba.org/en');
    });

    test('bare words become a wikipedia search', () {
      expect(
        normalizeBrowserUrl('暗算'),
        'https://www.wikipedia.org/wiki/Special:Search?search=%E6%9A%97%E7%AE%97',
      );
      expect(
        normalizeBrowserUrl('Nihongo lesson 3'),
        'https://www.wikipedia.org/wiki/Special:Search'
        '?search=Nihongo%20lesson%203',
      );
    });

    test('trims whitespace and rejects empty input', () {
      expect(normalizeBrowserUrl('  example.com  '), 'https://example.com');
      expect(normalizeBrowserUrl('   '), isNull);
      expect(normalizeBrowserUrl(''), isNull);
    });
  });
}
