import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class KanjiRemoteDataSource {
  static final RegExp _kanjiRegex = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]');

  List<String> extractKanji(String text) {
    return text.split('').where((char) => _kanjiRegex.hasMatch(char)).toSet().toList();
  }

  Future<Map<String, dynamic>?> getKanjiDetails(String kanji) async {
    try {
      final response = await http.get(Uri.parse('https://kanjiapi.dev/v1/kanji/$kanji'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<Map<String, String>?> getKanjipediaEtymology(String kanji) async {
    try {
      final searchUrl = Uri.parse('https://www.kanjipedia.jp/search?kt=1&sk=leftHand&k=$kanji');
      final response = await http.get(searchUrl);
      
      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);
        
        var firstResult = document.querySelector('#resultKanjiList a');
        if (firstResult != null) {
          final detailPath = firstResult.attributes['href'];
          final detailUrl = Uri.parse('https://www.kanjipedia.jp$detailPath');
          final detailResponse = await http.get(detailUrl);
          if (detailResponse.statusCode == 200) {
            document = html_parser.parse(detailResponse.body);
          }
        }

        Map<String, String> details = {};
        
        var origin = document.querySelector('li.naritachi div:nth-child(2) p');
        if (origin != null) details['origin'] = origin.innerHtml;

        var meaning = document.querySelector('#kanjiRightSection > ul > li:nth-child(1) > div > p');
        if (meaning != null) details['meaning'] = meaning.innerHtml;

        var usage = document.querySelector('#kanjiRightSection > ul > li:nth-child(2) > div > p');
        if (usage != null) details['usage'] = usage.innerHtml;

        return details.isNotEmpty ? details : null;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
}
