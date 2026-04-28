import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class DictionaryRemoteDataSource {
  final String apiUrl = 'http://localhost:5000';

  Future<int?> getFrequency(String word, String lang) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/frequency'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': word, 'mode': 'A'}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['frequency'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<List<String>> ichiMoeLookup(String word) async {
    try {
      final url = Uri.parse('https://ichi.moe/cl/qr/?r=hb&q=$word');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);
        var definitionElements = document.querySelectorAll('div.gloss-content.scroll-pane > dl');
        
        return definitionElements.map((e) {
          e.querySelectorAll('.sense-info-note.has-tip').forEach((el) => el.remove());
          return e.text.trim();
        }).where((s) => s.isNotEmpty).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  Future<String?> wiktionaryLookup(String word, String lang) async {
    try {
      String langCode = lang.isNotEmpty ? lang : 'en';
      final url = Uri.parse('https://$langCode.wiktionary.org/wiki/$word');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);
        var content = document.querySelector('#mw-content-text');
        return content?.innerHtml;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
}
