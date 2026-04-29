import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class MdbgEntry {
  final String word;
  final String pinyin;
  final List<String> definitions;
  final List<String> strokes;
  final String? traditional;
  final String? simplified;

  MdbgEntry({
    required this.word,
    required this.pinyin,
    required this.definitions,
    this.strokes = const [],
    this.traditional,
    this.simplified,
  });
}

class MdbgService {
  static const String _baseUrl = 'https://www.mdbg.net/chinese/dictionary';

  Future<MdbgEntry?> lookupWord(String word) async {
    try {
      final uri = Uri.parse('$_baseUrl?page=worddict&wdrst=0&wdqb=$word');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      return _parseResponse(word, response.body);
    } catch (e) {
      return null;
    }
  }

  MdbgEntry? _parseResponse(String query, String html) {
    final document = html_parser.parse(html);

    final entries = document.querySelectorAll('.worddict-entry');
    if (entries.isEmpty) return null;

    for (final entry in entries) {
      final hanzi = entry.querySelector('.hanzi');
      if (hanzi == null) continue;

      final word = hanzi.text.trim();
      if (word.isEmpty) continue;

      final simp = entry.querySelector('.simp');
      final trad = entry.querySelector('.trad');

      final pinyinElement = entry.querySelector('.pinyin');
      final pinyin = pinyinElement?.text.trim().replaceAll(RegExp(r'\[|\]'), '').trim() ?? '';

      final defs = <String>[];
      final defElements = entry.querySelectorAll('.defs');
      for (final def in defElements) {
        for (final li in def.querySelectorAll('li')) {
          final text = li.text.trim();
          if (text.isNotEmpty) defs.add(text);
        }
      }

      if (defs.isEmpty) {
        final noDef = entry.querySelector('.nodef');
        if (noDef != null) {
          defs.add(noDef.text.trim());
        }
      }

      return MdbgEntry(
        word: word,
        pinyin: pinyin,
        definitions: defs,
        simplified: simp?.text.trim(),
        traditional: trad?.text.trim(),
      );
    }

    return null;
  }

  Future<List<MdbgEntry>> searchWords(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl?page=worddict&wdrst=0&wdqb=$query');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      return _parseSearchResults(response.body, limit: limit);
    } catch (e) {
      return [];
    }
  }

  List<MdbgEntry> _parseSearchResults(String html, {int limit = 10}) {
    final results = <MdbgEntry>[];
    final document = html_parser.parse(html);

    final entries = document.querySelectorAll('.worddict-entry');
    for (final entry in entries.take(limit)) {
      final hanzi = entry.querySelector('.hanzi');
      if (hanzi == null) continue;

      final word = hanzi.text.trim();
      if (word.isEmpty) continue;

      final pinyinElement = entry.querySelector('.pinyin');
      final pinyin = pinyinElement?.text.trim().replaceAll(RegExp(r'\[|\]'), '').trim() ?? '';

      final defs = <String>[];
      final defElements = entry.querySelectorAll('.defs');
      for (final def in defElements) {
        for (final li in def.querySelectorAll('li')) {
          final text = li.text.trim();
          if (text.isNotEmpty) defs.add(text);
        }
      }

      results.add(MdbgEntry(
        word: word,
        pinyin: pinyin,
        definitions: defs,
      ));
    }

    return results;
  }
}