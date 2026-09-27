import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class MdbgEntry {
  final String word;
  final String pinyin;
  final List<String> definitions;
  final List<String> strokes;
  final String? traditional;
  final String? simplified;

  /// HSK level text as shown on the page, e.g. "HSK 1" or "HSK 7-9".
  final String? hskLevel;

  /// The slice of the original query this row covers (the first td of a
  /// worddict multi-word result row).
  final String? originalText;

  /// Alternate readings of the same characters (说 as shuì / shuō / 説).
  /// The primary reading stays in [word]/[pinyin]; variants carry their own.
  final List<MdbgEntry> variants;

  MdbgEntry({
    required this.word,
    required this.pinyin,
    required this.definitions,
    this.strokes = const [],
    this.traditional,
    this.simplified,
    this.hskLevel,
    this.originalText,
    this.variants = const [],
  });
}

/// Scraper for mdbg.net worddict result pages.
///
/// Current markup (verified against a live page): results live in
/// `table.wordresults tr.row`, one row per candidate reading. Inside a row:
/// - first td (*.otxt*) — the slice of the original query this row covers
/// - td.head div.hanzi — simplified hanzi, one span per character
/// - td.head div.pinyin — tone-marked pinyin, one span per syllable
/// - td.details div.defs — definitions separated by `<strong>/</strong>`
/// - td.tail div.hanzi — traditional form (absent when identical)
/// - td.tail div.hsk — HSK level (absent when unranked)
///
/// Rows for alternate readings of the same characters are split by
/// `td.separator` rows; they are grouped under the primary entry in
/// [MdbgEntry.variants].
class MdbgService {
  static const String _baseUrl = 'https://www.mdbg.net/chinese/dictionary';

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  Future<MdbgEntry?> lookupWord(String word) async {
    final results = await searchWords(word);
    if (results.isEmpty) return null;
    // an exact hanzi match beats the first arbitrary candidate
    for (final r in results) {
      if (r.word == word) return r;
    }
    return results.first;
  }

  Future<List<MdbgEntry>> searchWords(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?page=worddict&email=&wdrst=0&wdqb=$query',
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      return parseResults(response.body, limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Parse a worddict results page. Exposed for tests.
  List<MdbgEntry> parseResults(String html, {int limit = 20}) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('table.wordresults tr.row');
    if (rows.isEmpty) return [];

    final results = <MdbgEntry>[];
    var currentOriginalText = '';
    // variants of the previous entry (same hanzi, alternate readings)
    var variants = <MdbgEntry>[];
    MdbgEntry? last;

    void finishLast() {
      if (last == null) return;
      if (variants.isNotEmpty) {
        // re-emit with variants attached
        final l = last!;
        last = MdbgEntry(
          word: l.word,
          pinyin: l.pinyin,
          definitions: l.definitions,
          strokes: l.strokes,
          traditional: l.traditional,
          simplified: l.simplified,
          hskLevel: l.hskLevel,
          originalText: l.originalText,
          variants: List.unmodifiable(variants),
        );
        variants = <MdbgEntry>[];
      }
    }

    void commitLast() {
      finishLast();
      if (last != null) results.add(last!);
      last = null;
    }

    for (final row in rows) {
      if (results.length >= limit) break;

      // separator rows (td.separator) split variant readings of the same
      // characters and do not match the tr.row selector; variant rows have
      // an empty otxt cell and the same hanzi as their primary row
      final otxtRaw = row.querySelector('td[class*="otxt"]')?.text;
      final otxt = otxtRaw
          ?.replaceAll(' ', ' ') // &nbsp; is not stripped by trim()
          .trim();
      final querySlice = (otxt == null || otxt.isEmpty) ? null : otxt;
      if (querySlice != null) currentOriginalText = querySlice;

      final headHanzi = row.querySelector('td.head div.hanzi');
      if (headHanzi == null) continue;
      final word = headHanzi.text.trim();
      if (word.isEmpty) continue;

      final pinyin = _pinyinOf(row);
      final defs = _definitionsOf(row);
      final tail = row.querySelector('td.tail');
      final hsk = tail?.querySelector('div.hsk')?.text.trim();
      final traditional = tail
          ?.querySelector('div.hanzi')
          ?.text
          .trim()
          .nullIfEmpty;

      final entry = MdbgEntry(
        word: word,
        pinyin: pinyin,
        definitions: defs,
        traditional: (traditional != null && traditional != word)
            ? traditional
            : null,
        simplified: word,
        hskLevel: hsk.nullIfEmpty,
        originalText: currentOriginalText.nullIfEmpty,
      );

      final isVariant =
          querySlice == null && last != null && word == last!.word;
      if (isVariant) {
        variants.add(entry);
      } else {
        commitLast();
        last = entry;
      }
    }
    commitLast();

    return results;
  }

  String _pinyinOf(Element row) {
    final pinyinDiv = row.querySelector('td.head div.pinyin');
    if (pinyinDiv == null) return '';
    // one span per syllable; join with spaces (wbr elements render nothing)
    final syllables = <String>[];
    for (final span in pinyinDiv.querySelectorAll('span')) {
      final s = span.text.trim();
      if (s.isNotEmpty) syllables.add(s);
    }
    if (syllables.isNotEmpty) return syllables.join(' ');
    return pinyinDiv.text.trim();
  }

  List<String> _definitionsOf(Element row) {
    final defsDiv = row.querySelector('td.details div.defs');
    if (defsDiv == null) return [];
    // definitions are separated by <strong>/</strong>; link text inside a
    // definition (cross-referenced words) belongs to its segment
    final segments = <String>[];
    var current = StringBuffer();

    void flush() {
      final text = _squashWhitespace(current.toString());
      current = StringBuffer();
      if (text.isNotEmpty) segments.add(text);
    }

    for (final node in defsDiv.nodes) {
      if (node is Element &&
          node.localName == 'strong' &&
          node.text.trim() == '/') {
        flush();
      } else {
        current.write(node.text);
      }
    }
    flush();
    return segments;
  }

  String _squashWhitespace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension _StringX on String? {
  String? get nullIfEmpty {
    final v = this?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
