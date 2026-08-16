import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:lang/utils/html_sanitizer.dart';

/// A service for fetching and parsing Wikipedia content
class WikipediaService {
  /// Fetches Wikipedia article content for a given word and language
  ///
  /// Parameters:
  /// - term: The term to search for
  /// - languageCode: Language code (ja, en, zh, etc.)
  Future<WikipediaArticle?> fetchArticle(String term, {String languageCode = 'ja'}) async {
    final languageSubdomain = languageCode;
    final url = 'https://$languageSubdomain.wikipedia.org/wiki/${Uri.encodeComponent(term)}';

    try {
      final response = await http.get(
        Uri.parse(Uri.encodeFull(url)),
        headers: {
          'Content-Type': 'text/html; charset=UTF-8',
          'User-Agent': 'LangApp/1.0 (https://github.com/lang-app; lang-app@example.com)',
        },
      );

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load Wikipedia article: ${response.statusCode}');
      }

      return _parseWikipediaContent(response.body, term);
    } catch (e) {
      throw Exception('Error fetching Wikipedia article: $e');
    }
  }

  /// Fetch summary/extract for a term (shorter, for quick preview)
  Future<String?> fetchSummary(String term, {String languageCode = 'ja'}) async {
    final languageSubdomain = languageCode;
    final url = 'https://$languageSubdomain.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(term)}';

    try {
      final response = await http.get(
        Uri.parse(Uri.encodeFull(url)),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'LangApp/1.0',
        },
      );

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      return data['extract'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Search Wikipedia for terms
  Future<List<WikipediaSearchResult>> search(String query, {String languageCode = 'ja', int limit = 10}) async {
    final languageSubdomain = languageCode;
    final url = 'https://$languageSubdomain.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json&srlimit=$limit';

    try {
      final response = await http.get(
        Uri.parse(Uri.encodeFull(url)),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'LangApp/1.0',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final searchResults = data['query']['search'] as List? ?? [];

      return searchResults.map((item) => WikipediaSearchResult.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  WikipediaArticle? _parseWikipediaContent(String html, String term) {
    try {
      final document = parse(html);
      final contentDiv = document.querySelector('#mw-content-text .mw-parser-output');

      if (contentDiv == null) return null;

      // Get the lead section (before first h2)
      final leadContent = <String>[];
      final sections = <WikipediaSection>[];
      bool inLead = true;

      for (final element in contentDiv.children) {
        final tagName = element.localName?.toLowerCase() ?? '';

        // Check for headings
        if (tagName.startsWith('h') && tagName.length == 2) {
          final level = int.tryParse(tagName.substring(1)) ?? 2;
          if (level == 2) {
            inLead = false;
          }

          final headingText = element.text.trim();
          if (headingText.isNotEmpty && !headingText.contains('Contents') && !headingText.contains('See also')) {
            sections.add(WikipediaSection(
              title: headingText,
              level: level,
              content: '',
            ));
          }
          continue;
        }

        final sanitizedHtml = HtmlSanitizer.sanitize(element.outerHtml ?? '');

        if (inLead && sanitizedHtml.isNotEmpty) {
          leadContent.add(sanitizedHtml);
        } else if (!inLead && sections.isNotEmpty) {
          sections.last.content += sanitizedHtml;
        }
      }

      // Extract infobox if present
      String? infoboxHtml;
      final infobox = contentDiv.querySelector('.infobox');
      if (infobox != null) {
        infoboxHtml = HtmlSanitizer.sanitize(infobox.outerHtml);
      }

      // Extract first image
      String? imageUrl;
      final firstImage = contentDiv.querySelector('img');
      if (firstImage != null) {
        imageUrl = firstImage.attributes['src'];
        if (imageUrl != null && imageUrl.startsWith('//')) {
          imageUrl = 'https:$imageUrl';
        }
      }

      return WikipediaArticle(
        title: term,
        leadHtml: leadContent.join(''),
        sections: sections,
        infoboxHtml: infoboxHtml,
        imageUrl: imageUrl,
      );
    } catch (e) {
      return null;
    }
  }
}

class WikipediaArticle {
  final String title;
  final String leadHtml;
  final List<WikipediaSection> sections;
  final String? infoboxHtml;
  final String? imageUrl;

  WikipediaArticle({
    required this.title,
    required this.leadHtml,
    required this.sections,
    this.infoboxHtml,
    this.imageUrl,
  });

  bool get isEmpty => leadHtml.isEmpty && sections.isEmpty;
}

class WikipediaSection {
  final String title;
  final int level;
  String content;

  WikipediaSection({
    required this.title,
    required this.level,
    required this.content,
  });
}

class WikipediaSearchResult {
  final String title;
  final String snippet;
  final int pageId;

  WikipediaSearchResult({
    required this.title,
    required this.snippet,
    required this.pageId,
  });

  factory WikipediaSearchResult.fromMap(Map<String, dynamic> map) {
    return WikipediaSearchResult(
      title: map['title'] as String? ?? '',
      snippet: map['snippet'] as String? ?? '',
      pageId: map['pageid'] as int? ?? 0,
    );
  }
}