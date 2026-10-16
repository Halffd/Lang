import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/wiktionary_lookup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WiktionaryLookupService', () {
    test('stripHtml removes tags and unescapes entities', () {
      expect(
        WiktionaryLookupService.stripHtml(
          '<strong>cat</strong> <i>(Felis)</i>&nbsp;catus',
        ),
        'cat (Felis) catus',
      );
    });

    test('isSupported: override wins over detected', () {
      // 'ja' is not in the supported set, but an explicit override is
      expect(WiktionaryLookupService.isSupported('ja', override: 'en'), isTrue);
      // 'auto' falls through to detection
      expect(
        WiktionaryLookupService.isSupported('ja', override: 'auto'),
        isFalse,
      );
      expect(
        WiktionaryLookupService.isSupported('ru', override: 'auto'),
        isTrue,
      );
      expect(WiktionaryLookupService.isSupported('ru', override: 'ru'), isTrue);
    });

    test('subdomainFor: override wins, auto follows detection', () {
      expect(WiktionaryLookupService.subdomainFor('el', override: 'ru'), 'ru');
      expect(
        WiktionaryLookupService.subdomainFor('el', override: 'auto'),
        'el',
      );
    });

    test('supportedLanguages excludes CJK (yomichan territory)', () {
      expect(
        WiktionaryLookupService.supportedLanguages.contains('ja'),
        isFalse,
      );
      expect(
        WiktionaryLookupService.supportedLanguages.contains('zh'),
        isFalse,
      );
      expect(WiktionaryLookupService.supportedLanguages.contains('en'), isTrue);
    });
  });
}
