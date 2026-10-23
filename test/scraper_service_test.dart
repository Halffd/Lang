// encode/decode + subprocess probes exceed the 30s default when
// the full suite runs in parallel on a loaded machine
@Timeout(Duration(minutes: 3))
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/scraper_service.dart';

void main() {
  group('ScraperConfig', () {
    test('defaults to dartHttp method', () {
      final cfg = ScraperConfig();
      expect(cfg.method, ScraperMethod.dartHttp);
      expect(cfg.retries, 1);
      expect(cfg.timeout, const Duration(seconds: 15));
      expect(cfg.maxBytes, 2 * 1024 * 1024);
      expect(cfg.format, ScraperOutputFormat.html);
      expect(cfg.headers['User-Agent'], 'LangScraper/1.0');
    });

    test('copy preserves all fields', () {
      final cfg = ScraperConfig(
        method: ScraperMethod.curl,
        headers: {'X-Custom': 'value'},
        retries: 3,
        timeout: const Duration(seconds: 30),
        proxy: 'http://proxy:8080',
        maxBytes: 1024,
        format: ScraperOutputFormat.text,
        elementFilter: 'div.content',
        textFilter: 'important',
      );
      final copy = cfg.copy();
      expect(copy.method, cfg.method);
      expect(copy.headers, cfg.headers);
      expect(copy.retries, cfg.retries);
      expect(copy.timeout, cfg.timeout);
      expect(copy.proxy, cfg.proxy);
      expect(copy.maxBytes, cfg.maxBytes);
      expect(copy.format, cfg.format);
      expect(copy.elementFilter, cfg.elementFilter);
      expect(copy.textFilter, cfg.textFilter);
    });

    test('toJson/fromJson roundtrip', () {
      final cfg = ScraperConfig(
        method: ScraperMethod.selenium,
        headers: {'X-API': 'key'},
        retries: 2,
        timeout: const Duration(seconds: 45),
        proxy: 'http://p:8080',
        maxBytes: 5000,
        format: ScraperOutputFormat.json,
        elementFilter: 'table',
        textFilter: 'regex',
      );
      final json = cfg.toJson();
      final restored = ScraperConfig.fromJson(json);
      expect(restored.method, cfg.method);
      expect(restored.headers, cfg.headers);
      expect(restored.retries, cfg.retries);
      expect(restored.timeout, cfg.timeout);
      expect(restored.proxy, cfg.proxy);
      expect(restored.maxBytes, cfg.maxBytes);
      expect(restored.format, cfg.format);
      expect(restored.elementFilter, cfg.elementFilter);
      expect(restored.textFilter, cfg.textFilter);
    });

    test('fromJson falls back to defaults for missing fields', () {
      final cfg = ScraperConfig.fromJson({'method': 'curl'});
      expect(cfg.method, ScraperMethod.curl);
      expect(cfg.retries, 1);
      expect(cfg.format, ScraperOutputFormat.html);
    });
  });

  group('ScraperConfig roundtrip', () {
    test('all engine types serialize', () {
      for (final method in ScraperMethod.values) {
        final cfg = ScraperConfig(method: method);
        final json = cfg.toJson();
        expect(json['method'], method.name);
      }
    });

    test('all output formats serialize', () {
      for (final fmt in ScraperOutputFormat.values) {
        final cfg = ScraperConfig(format: fmt);
        final json = cfg.toJson();
        expect(json['format'], fmt.name);
      }
    });
  });

  group('ScraperService', () {
    late ScraperService scraper;

    setUp(() {
      scraper = ScraperService();
    });

    test('probeAvailability always includes Dart HTTP', () async {
      final avail = await scraper.probeAvailability();
      final dartHttp = avail.firstWhere(
        (a) => a.method == ScraperMethod.dartHttp,
      );
      expect(dartHttp.available, isTrue);
      expect(dartHttp.detail, 'built-in');
    });

    test('dartHttp fetch succeeds for valid URL', () async {
      final result = await scraper.scrape(
        'https://httpbin.org/get',
        ScraperConfig(method: ScraperMethod.dartHttp),
      );
      expect(result.success, isTrue);
      expect(result.url, 'https://httpbin.org/get');
      expect(result.content, isNotEmpty);
    });

    test('htmlToText strips tags and entities', () {
      const html = '<p>Hello & <b>world</b></p>';
      final text = ScraperService.htmlToText('<p>Hello & <b>world</b></p>');
      expect(text, contains('Hello'));
      expect(text, contains('world'));
      expect(text, isNot(contains('<p>')));
    });

    test('htmlToText removes scripts and styles', () {
      const html = '<script>bad</script><style>css</style><p>keep</p>';
      final text = ScraperService.htmlToText(html);
      expect(text, contains('keep'));
      expect(text, isNot(contains('bad')));
      expect(text, isNot(contains('css')));
    });
  });

  group('ScraperConfig roundtrip', () {
    test('all engine types serialize', () {
      for (final method in ScraperMethod.values) {
        final cfg = ScraperConfig(method: method);
        final json = cfg.toJson();
        expect(json['method'], method.name);
      }
    });

    test('all output formats serialize', () {
      for (final fmt in ScraperOutputFormat.values) {
        final cfg = ScraperConfig(format: fmt);
        final json = cfg.toJson();
        expect(json['format'], fmt.name);
      }
    });
  });
}
