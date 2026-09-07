import 'dart:convert';
import 'package:http/http.dart' as http;

class WiktionaryEntry {
  final String word;
  final String language; // Language being looked up
  final String partOfSpeech; // e.g. noun, verb, adjective
  final String definition; // Main definition
  final String etymology; // Etymology information
  final List<String> examples; // Example sentences
  final List<String> translations; // Translations if available
  final List<String> synonyms; // Synonyms if available
  final List<String> antonyms; // Antonyms if available

  WiktionaryEntry({
    required this.word,
    required this.language,
    this.partOfSpeech = '',
    this.definition = '',
    this.etymology = '',
    this.examples = const [],
    this.translations = const [],
    this.synonyms = const [],
    this.antonyms = const [],
  });
}

class EtymologyResult {
  final String word;
  final String language;
  final List<EtymologySection> sections;

  EtymologyResult({
    required this.word,
    required this.language,
    required this.sections,
  });
}

class EtymologySection {
  final String title;
  final String language;  // The language of the current app context
  final String originalLanguage;  // The original language being traced
  final String content;  // The etymology content

  EtymologySection({
    required this.title,
    required this.language,
    required this.originalLanguage,
    required this.content,
  });
}

class WiktionaryEtymologyService {
  // Map of language codes to their Wiktionary subdomain
  static const Map<String, String> _languageSubdomains = {
    'en': 'en',
    'ja': 'ja',
    'zh': 'zh',
    'de': 'de',
    'fr': 'fr',
    'es': 'es',
    'ko': 'ko',
    'ru': 'ru',
    'ar': 'ar',
    'pt': 'pt',
    'it': 'it',
    'nl': 'nl',
    'pl': 'pl',
    'sv': 'sv',
    'da': 'da',
    'fi': 'fi',
    'no': 'no',
    'tr': 'tr',
    'he': 'he',
    'el': 'el',
    'th': 'th',
    'vi': 'vi',
    'hi': 'hi',
    'id': 'id',
    'cs': 'cs',
    'hu': 'hu',
    'ro': 'ro',
    'bg': 'bg',
    'uk': 'uk',
    'hr': 'hr',
    'sr': 'sr',
    'sk': 'sk',
    'sl': 'sl',
    'lt': 'lt',
    'lv': 'lv',
    'et': 'et',
    'ca': 'ca',
    'tl': 'tl',
  };

  /// Get the Wiktionary subdomain for a given language code
  String _getSubdomain(String languageCode) {
    return _languageSubdomains[languageCode] ?? 'en'; // Default to English if language not supported
  }

  /// Fetch detailed Wiktionary information for a given word in a specific language
  Future<List<WiktionaryEntry>> fetchWordDetails(String word, String language) async {
    try {
      // Get the appropriate Wiktionary subdomain for the language
      String subdomain = _getSubdomain(language);
      String baseUrl = 'https://$subdomain.wiktionary.org/w/api.php';

      // Use the Parse API which gives us wikitext that we can parse more accurately
      final response = await http.get(
        Uri.parse('$baseUrl?action=parse&page=$word&prop=wikitext&format=json'),
        headers: {'User-Agent': 'LangApp/1.0 (contact@langapp.com)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        // Fallback to English Wiktionary if the specific language version doesn't exist
        if (subdomain != 'en') {
          return await fetchWordDetails(word, 'en');
        }
        return [];
      }

      final data = json.decode(response.body);
      
      // Check if the page exists
      if (data['parse'] == null) {
        return [];
      }
      
      final wikitext = data['parse']['wikitext']['*'] as String?;

      if (wikitext == null || wikitext.isEmpty) {
        return [];
      }

      // Parse the wikitext for different sections
      return _parseWiktionaryContent(wikitext, word, language);
    } catch (e) {
      print('Error fetching Wiktionary details for $word: $e');
      return [];
    }
  }
  
  /// Parse content from Wiktionary
  List<WiktionaryEntry> _parseWiktionaryContent(String wikitext, String word, String language) {
    final entries = <WiktionaryEntry>[];
    
    // Split by language headers (==English==, ==Japanese==, etc.)
    final languageSections = _splitByHeaders(wikitext, '==', '==', 2);
    
    for (final section in languageSections) {
      // Extract language from header if present
      String lang = language;
      final lines = section.split('\n');
      if (lines.isNotEmpty && lines[0].startsWith('==') && lines[0].endsWith('==')) {
        lang = lines[0].replaceAll('==', '').trim();
        lines.removeAt(0); // Remove the header line
      }
      
      // Find etymology, definitions, examples, etc. within this language section
      final content = lines.join('\n');
      final etymology = _extractEtymology(content);
      final definitions = _extractDefinitions(content);
      
      // Process each definition to create WiktionaryEntry
      for (final definition in definitions) {
        entries.add(WiktionaryEntry(
          word: word,
          language: lang,
          partOfSpeech: definition['pos'] ?? '',
          definition: definition['def'] ?? '',
          etymology: etymology,
          examples: definition['examples']?.cast<String>() ?? [],
          synonyms: definition['synonyms']?.cast<String>() ?? [],
          antonyms: definition['antonyms']?.cast<String>() ?? [],
          translations: [], // Translations would need more complex parsing
        ));
      }
    }
    
    return entries;
  }
  
  /// Extract etymology from content
  String _extractEtymology(String content) {
    // Look for etymology sections
    final lines = content.split('\n');
    bool inEtymology = false;
    List<String> etymologyLines = [];
    
    for (final line in lines) {
      if (line.contains('==Etymology') || line.contains('==Etymologie') || line.contains('==語源')) {
        inEtymology = true;
        continue;
      } 
      else if (line.startsWith('==') && line.endsWith('==')) {
        // New section header, stop collecting etymology
        if (inEtymology) break;
      }
      else if (inEtymology) {
        if (line.trim().isNotEmpty && !line.startsWith('#')) {
          etymologyLines.add(line.trim());
        }
      }
    }
    
    return etymologyLines.join(' ').trim();
  }
  
  /// Extract definitions from content
  List<Map<String, dynamic>> _extractDefinitions(String content) {
    final definitions = <Map<String, dynamic>>[];
    final lines = content.split('\n');
    
    String currentPos = ''; // Current part of speech
    Map<String, dynamic>? currentDef;
    
    for (final line in lines) {
      // Look for part of speech headers like ===Noun===, ===Verb===, etc.
      if (line.startsWith('===') && line.endsWith('===')) {
        currentPos = line.replaceAll('===', '').trim();
        continue;
      }
      // Look for definitions starting with # 
      else if (line.startsWith('# ') && currentPos.isNotEmpty) {
        // If we had a previous definition, add it
        if (currentDef != null) {
          definitions.add(currentDef);
        }
        
        // Start a new definition
        String defText = line.substring(2).trim(); // Remove '# ' prefix
        defText = _cleanWikitext(defText);
        
        currentDef = {
          'pos': currentPos,
          'def': defText,
          'examples': <String>[],
          'synonyms': <String>[],
          'antonyms': <String>[],
        };
      }
      // Look for examples starting with #* 
      else if (line.startsWith('#* ') && currentDef != null) {
        String exampleText = line.substring(3).trim(); // Remove '#* ' prefix
        exampleText = _cleanWikitext(exampleText);
        (currentDef['examples'] as List).add(exampleText);
      }
      // Look for synonyms starting with #*: 
      else if (line.startsWith('#*: Synonyms:') && currentDef != null) {
        String synonymsText = line.substring('#*: Synonyms:'.length).trim();
        List<String> synonyms = synonymsText.split(',').map((s) => _cleanWikitext(s.trim())).toList();
        (currentDef['synonyms'] as List).addAll(synonyms);
      }
      // Look for antonyms starting with #*: 
      else if (line.startsWith('#*: Antonyms:') && currentDef != null) {
        String antonymsText = line.substring('#*: Antonyms:'.length).trim();
        List<String> antonyms = antonymsText.split(',').map((s) => _cleanWikitext(s.trim())).toList();
        (currentDef['antonyms'] as List).addAll(antonyms);
      }
    }
    
    // Don't forget the last definition
    if (currentDef != null) {
      definitions.add(currentDef);
    }
    
    return definitions;
  }
  
  /// Split text by headers of specified level
  List<String> _splitByHeaders(String text, String startMarker, String endMarker, int level) {
    final result = <String>[];
    final lines = text.split('\n');
    String currentSection = '';
    
    for (final line in lines) {
      if (line.startsWith(startMarker) && line.endsWith(endMarker)) {
        // Found a header of the expected level
        if (currentSection.isNotEmpty) {
          result.add(currentSection);
        }
        currentSection = '$line\n';
      } else {
        currentSection += '$line\n';
      }
    }
    
    if (currentSection.isNotEmpty) {
      result.add(currentSection);
    }
    
    return result;
  }
  
  /// Clean wikitext formatting
  String _cleanWikitext(String text) {
    // Remove various Wiktionary formatting
    text = text.replaceAll(RegExp(r'\[\[([^\]|]*\|)?([^\]|]*)\]\]'), r'$2'); // Remove [[links|text]] -> text
    text = text.replaceAll(RegExp(r'\[\[([^\]|]*)\]\]'), r'$1'); // Remove [[text]] -> text
    text = text.replaceAll(RegExp(r"''([^']*)''"), r'$1'); // Remove ''italic'' -> italic
    text = text.replaceAll(RegExp(r"'''([^']*)'''"), r'$1'); // Remove '''bold''' -> bold
    text = text.replaceAll(RegExp(r'\{\{([^}]*)\}\}'), ''); // Remove {{templates}}
    text = text.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML tags
    text = text.replaceAll(RegExp(r'\n+'), '\n'); // Normalize multiple newlines
    
    return text.trim();
  }

  /// Fetch etymology information for a given word in a specific language
  Future<EtymologyResult> fetchEtymology(String word, String language) async {
    try {
      // Get detailed Wiktionary information including etymology
      final entries = await fetchWordDetails(word, language);
      
      // Convert to EtymologyResult format
      final sections = entries.map((entry) => EtymologySection(
        title: 'Etymology: ${entry.partOfSpeech}',
        language: language,
        originalLanguage: language,
        content: entry.etymology.isNotEmpty ? entry.etymology : 'Etymology information not available',
      )).toList();
      
      return EtymologyResult(
        word: word,
        language: language,
        sections: sections,
      );
    } catch (e) {
      print('Error fetching etymology for $word: $e');
      return EtymologyResult(word: word, language: language, sections: []);
    }
  }
  
  /// Fetch etymology from Wiktionary API with more specific parameters
  Future<EtymologyResult> fetchEtymologyDetailed(String word, String language) async {
    return await fetchEtymology(word, language);
  }
}