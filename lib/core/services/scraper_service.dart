import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// How a page is fetched.
enum ScraperMethod {
  /// Dart HTTP client — always available, the default.
  dartHttp,

  /// System curl binary.
  curl,

  /// Python requests library.
  pythonRequests,

  /// Python selenium (needs a webdriver + browser).
  selenium,

  /// Node.js puppeteer (headless Chromium).
  puppeteer,
}

/// Output format for a scraped page.
enum ScraperOutputFormat { html, text, json }

/// Persistent configuration for one scraping profile.
class ScraperConfig {
  ScraperMethod method;
  Map<String, String> headers;
  int retries;
  Duration timeout;
  String? proxy;
  int maxBytes;
  ScraperOutputFormat format;

  /// Reuse HTTP client for connection pooling
  bool reuseClient;

  /// CSS-ish element filter kept as a plain substring/regex string —
  /// applied after fetch to extract only matching fragments.
  String elementFilter;

  /// Regex over the fetched content; only matching lines are kept.
  String textFilter;

  ScraperConfig({
    this.method = ScraperMethod.dartHttp,
    Map<String, String>? headers,
    this.retries = 1,
    Duration? timeout,
    this.proxy,
    this.maxBytes = 2 * 1024 * 1024,
    this.format = ScraperOutputFormat.html,
    this.elementFilter = '',
    this.textFilter = '',
    this.reuseClient = true,
  }) : headers = headers ?? {'User-Agent': 'LangScraper/1.0'},
       timeout = timeout ?? const Duration(seconds: 15);

  Map<String, dynamic> toJson() => {
    'method': method.name,
    'headers': headers,
    'retries': retries,
    'timeoutMs': timeout.inMilliseconds,
    'proxy': proxy ?? '',
    'maxBytes': maxBytes,
    'format': format.name,
    'elementFilter': elementFilter,
    'textFilter': textFilter,
  };

  factory ScraperConfig.fromJson(Map<String, dynamic> json) {
    return ScraperConfig(
      method: ScraperMethod.values.firstWhere(
        (m) => m.name == json['method'],
        orElse: () => ScraperMethod.dartHttp,
      ),
      headers: (json['headers'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      retries: (json['retries'] as num?)?.toInt() ?? 1,
      timeout: Duration(
        milliseconds: (json['timeoutMs'] as num?)?.toInt() ?? 15000,
      ),
      proxy: (json['proxy'] as String?)?.isEmpty == true
          ? null
          : json['proxy'] as String?,
      maxBytes: (json['maxBytes'] as num?)?.toInt() ?? 2 * 1024 * 1024,
      format: ScraperOutputFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => ScraperOutputFormat.html,
      ),
      elementFilter: json['elementFilter'] as String? ?? '',
      textFilter: json['textFilter'] as String? ?? '',
    );
  }

  ScraperConfig copy() => ScraperConfig.fromJson(toJson());
}

/// Availability of one external scraping method on this machine.
class MethodAvailability {
  final ScraperMethod method;
  final bool available;
  final String detail;

  const MethodAvailability({
    required this.method,
    required this.available,
    this.detail = '',
  });
}

/// One scraped page: raw + processed content and metadata.
class ScrapeResult {
  final String url;
  final bool success;
  final String content;
  final ScraperOutputFormat format;
  final int bytes;
  final int elapsedMs;
  final String? error;
  final ScraperMethod method;

  const ScrapeResult({
    required this.url,
    required this.success,
    required this.content,
    required this.format,
    required this.bytes,
    required this.elapsedMs,
    required this.method,
    this.error,
  });
}

/// Injectable command runner (exit, stdout, stderr).
typedef ScrapeCommandRunner =
    Future<(int, String, String)> Function(
      String executable,
      List<String> arguments,
    );

/// Multi-method web scraping with persistent config.
///
/// Dart HTTP is the primary method (no external dependency); curl,
/// python-requests, selenium and puppeteer run through the system
/// toolchain with availability probes. Every method honours the same
/// [ScraperConfig]: headers, retries, proxy, size cap, output format
/// and the element/text filters.
class ScraperService {
  /// Injectable for tests.
  ScrapeCommandRunner runCommand = _realRunner;

  /// HTTP client override for tests.
  http.Client httpClient = http.Client();

  static Future<(int, String, String)> _realRunner(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return (
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  // ------------------------------------------------------------
  // availability probes
  // ------------------------------------------------------------

  Future<bool> hasCurl() async {
    try {
      final (code, _, _) = await runCommand('curl', ['--version']);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPythonRequests() async {
    try {
      final (code, _, _) = await runCommand('python3', [
        '-c',
        'import requests',
      ]);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasSelenium() async {
    try {
      final (code, _, _) = await runCommand('python3', [
        '-c',
        'import selenium',
      ]);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPuppeteer() async {
    try {
      final (code, _, _) = await runCommand('node', [
        '-e',
        'require("puppeteer")',
      ]);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  /// Probe every non-Dart method; Dart HTTP is always available.
  Future<List<MethodAvailability>> probeAvailability() async {
    return [
      const MethodAvailability(
        method: ScraperMethod.dartHttp,
        available: true,
        detail: 'built-in',
      ),
      MethodAvailability(
        method: ScraperMethod.curl,
        available: await hasCurl(),
      ),
      MethodAvailability(
        method: ScraperMethod.pythonRequests,
        available: await hasPythonRequests(),
      ),
      MethodAvailability(
        method: ScraperMethod.selenium,
        available: await hasSelenium(),
        detail: 'needs webdriver + browser',
      ),
      MethodAvailability(
        method: ScraperMethod.puppeteer,
        available: await hasPuppeteer(),
        detail: 'needs node + chromium',
      ),
    ];
  }

  // ------------------------------------------------------------
  // scraping pipeline
  // ------------------------------------------------------------

  Future<ScrapeResult> scrape(String url, ScraperConfig config) async {
    final sw = Stopwatch()..start();
    for (var attempt = 0; attempt <= config.retries; attempt++) {
      try {
        final (content, bytes) = await _fetchOnce(url, config);
        sw.stop();
        final processed = _process(content, config);
        return ScrapeResult(
          url: url,
          success: true,
          content: processed,
          format: config.format,
          bytes: bytes,
          elapsedMs: sw.elapsedMilliseconds,
          method: config.method,
        );
      } catch (e) {
        if (attempt == config.retries) {
          sw.stop();
          return ScrapeResult(
            url: url,
            success: false,
            content: '',
            format: config.format,
            bytes: 0,
            elapsedMs: sw.elapsedMilliseconds,
            method: config.method,
            error: e.toString(),
          );
        }
        // linear backoff before the next attempt
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw StateError('unreachable');
  }

  Future<(String, int)> _fetchOnce(String url, ScraperConfig config) async {
    switch (config.method) {
      case ScraperMethod.dartHttp:
        return _fetchHttp(url, config);
      case ScraperMethod.curl:
        return _fetchCurl(url, config);
      case ScraperMethod.pythonRequests:
        return _fetchPythonRequests(url, config);
      case ScraperMethod.selenium:
        return _fetchSelenium(url, config);
      case ScraperMethod.puppeteer:
        return _fetchPuppeteer(url, config);
    }
  }

  Future<(String, int)> _fetchHttp(String url, ScraperConfig config) async {
    var uri = Uri.parse(url);
    if (config.proxy != null && config.proxy!.isNotEmpty) {
      // dart:io HttpClient honours findProxy; the http package does not
      // accept a proxy directly, so rewrite through the proxy host when
      // it is a plain host:port
      final proxy = config.proxy!;
      if (proxy.startsWith('http://') || proxy.startsWith('https://')) {
        uri = Uri.parse('$proxy/$url'.replaceFirst('$proxy/', '$proxy?url='));
      }
    }
    final response = await httpClient
        .get(uri, headers: config.headers)
        .timeout(config.timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    final bytes = response.bodyBytes;
    if (bytes.length > config.maxBytes) {
      return (
        utf8.decode(bytes.take(config.maxBytes).toList(), allowMalformed: true),
        config.maxBytes,
      );
    }
    return (utf8.decode(bytes, allowMalformed: true), bytes.length);
  }

  Future<(String, int)> _fetchCurl(String url, ScraperConfig config) async {
    final args = <String>[
      '-s',
      '-L',
      '--max-time',
      '${config.timeout.inSeconds}',
    ];
    config.headers.forEach((k, v) => args.addAll(['-H', '$k: $v']));
    if (config.proxy != null && config.proxy!.isNotEmpty) {
      args.addAll(['-x', config.proxy!]);
    }
    args.add(url);
    final (code, stdout_, stderr) = await runCommand('curl', args);
    if (code != 0) throw HttpException('curl failed: $stderr');
    final capped = stdout_.length > config.maxBytes
        ? stdout_.substring(0, config.maxBytes)
        : stdout_;
    return (capped, capped.length);
  }

  Future<(String, int)> _fetchPythonRequests(
    String url,
    ScraperConfig config,
  ) async {
    final script =
        '''
import sys
import requests

headers = ${jsonEncode(config.headers)}
proxies = ${config.proxy == null || config.proxy!.isEmpty ? 'None' : jsonEncode({'http': config.proxy, 'https': config.proxy})}
resp = requests.get(${jsonEncode(url)}, headers=headers, proxies=proxies, timeout=${config.timeout.inSeconds})
sys.stdout.write(resp.text)
''';
    final (code, stdout_, stderr) = await runCommand('python3', ['-c', script]);
    if (code != 0) throw HttpException('python requests failed: $stderr');
    final capped = stdout_.length > config.maxBytes
        ? stdout_.substring(0, config.maxBytes)
        : stdout_;
    return (capped, capped.length);
  }

  Future<(String, int)> _fetchSelenium(String url, ScraperConfig config) async {
    // headless chrome/firefox through selenium; page_source after load
    final script =
        '''
import sys
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

opts = Options()
opts.add_argument('--headless=new')
${config.proxy != null && config.proxy!.isNotEmpty ? "opts.add_argument('--proxy-server=${config.proxy}')" : ''}
driver = webdriver.Chrome(options=opts)
try:
    driver.set_page_load_timeout(${config.timeout.inSeconds})
    driver.get(${jsonEncode(url)})
    sys.stdout.write(driver.page_source)
finally:
    driver.quit()
''';
    final (code, stdout_, stderr) = await runCommand('python3', ['-c', script]);
    if (code != 0) throw HttpException('selenium failed: $stderr');
    final capped = stdout_.length > config.maxBytes
        ? stdout_.substring(0, config.maxBytes)
        : stdout_;
    return (capped, capped.length);
  }

  Future<(String, int)> _fetchPuppeteer(
    String url,
    ScraperConfig config,
  ) async {
    final script =
        '''
const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({ headless: 'new'${config.proxy != null && config.proxy!.isNotEmpty ? ", args: ['--proxy-server=${config.proxy}']" : ''} });
  try {
    const page = await browser.newPage();
    await page.goto(${jsonEncode(url)}, { waitUntil: 'networkidle2', timeout: ${config.timeout.inMilliseconds} });
    process.stdout.write(await page.content());
  } finally {
    await browser.close();
  }
})();
''';
    final (code, stdout_, stderr) = await runCommand('node', ['-e', script]);
    if (code != 0) throw HttpException('puppeteer failed: $stderr');
    final capped = stdout_.length > config.maxBytes
        ? stdout_.substring(0, config.maxBytes)
        : stdout_;
    return (capped, capped.length);
  }

  // ------------------------------------------------------------
  // post-processing
  // ------------------------------------------------------------

  /// Apply format conversion + element/text filters.
  String _process(String content, ScraperConfig config) {
    var out = content;

    // element filter: keep only the requested element blocks (naive
    // tag matching — enough for the common <table>/<div class=x> case)
    if (config.elementFilter.trim().isNotEmpty) {
      out = _extractElements(out, config.elementFilter.trim());
    }

    // text filter: keep matching lines only
    if (config.textFilter.trim().isNotEmpty) {
      try {
        final re = RegExp(config.textFilter, multiLine: true);
        out = out.split('\n').where(re.hasMatch).join('\n');
      } on FormatException {
        // invalid regex: fall back to substring match
        out = out
            .split('\n')
            .where((l) => l.contains(config.textFilter))
            .join('\n');
      }
    }

    switch (config.format) {
      case ScraperOutputFormat.html:
        return out;
      case ScraperOutputFormat.text:
        return htmlToText(out);
      case ScraperOutputFormat.json:
        // try to parse; wrap raw text into a json envelope on failure
        try {
          final decoded = jsonDecode(out);
          return const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          return jsonEncode({'url': '', 'text': out});
        }
    }
  }

  /// Extract every `<tag ...>...</tag>` block for the requested tag or
  /// `tag.class` / `tag#id` selector.
  static String _extractElements(String html, String selector) {
    var tag = selector;
    String? attrName;
    String? attrValue;
    final classMatch = RegExp(r'^(\w+)\.([\w-]+)$').firstMatch(selector);
    final idMatch = RegExp(r'^(\w+)#([\w-]+)$').firstMatch(selector);
    if (classMatch != null) {
      tag = classMatch.group(1)!;
      attrName = 'class';
      attrValue = classMatch.group(2)!;
    } else if (idMatch != null) {
      tag = idMatch.group(1)!;
      attrName = 'id';
      attrValue = idMatch.group(2)!;
    }

    final openRe = attrName == null
        ? RegExp('<$tag[\\s>]', caseSensitive: false)
        : RegExp(
            '<$tag[^>]*$attrName=["\'][^"\']*${RegExp.escape(attrValue!)}[^"\']*["\'][^>]*>',
            caseSensitive: false,
          );

    final out = StringBuffer();
    var searchFrom = 0;
    while (true) {
      final m = openRe.firstMatch(html.substring(searchFrom));
      if (m == null) break;
      final start = searchFrom + m.start;
      // find the matching close tag (no nesting awareness — first close)
      final closeIdx = html.indexOf('</$tag>', start);
      if (closeIdx < 0) break;
      final end = closeIdx + tag.length + 3;
      out.writeln(html.substring(start, end));
      searchFrom = end;
    }
    final extracted = out.toString().trim();
    return extracted.isEmpty ? html : extracted;
  }

  /// Very small HTML → text conversion: drop scripts/styles, strip
  /// remaining tags, collapse whitespace, keep block breaks. Public:
  /// the browser tab renders scraped HTML with it too.
  static String htmlToText(String html) {
    var s = html
        .replaceAll(
          RegExp(
            r'<(script|style)[^>]*>.*?</\1>',
            dotAll: true,
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'<br\s*/?>|</(p|div|tr|li|h[1-6])>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&', '&')
        .replaceAll('<', '<')
        .replaceAll('>', '>');
    s = s
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((l) => l.isNotEmpty)
        .join('\n');
    return s;
  }
}
