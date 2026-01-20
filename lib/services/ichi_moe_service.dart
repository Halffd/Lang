import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/dictionary.dart' as model;

/// Service for scraping data from ichi.moe
class IchiMoeService {
  /// Fetches and parses data from ichi.moe for a given term
  /// 
  /// Parameters:
  /// - term: The Japanese term to search for
  /// - useRomaji: Whether to use romaji ('hb') or kana ('kana') - defaults to romaji
  Future<List<model.DictionaryEntry>> search(String term, {bool useRomaji = true}) async {
    try {
      final rmj = useRomaji ? 'hb' : 'kana';
      final url = 'https://ichi.moe/cl/qr/?r=$rmj&q=${Uri.encodeComponent(term)}';
      
      print('Ichi.moe URL: $url'); // Debugging
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load ichi.moe data: ${response.statusCode}');
      }

      final document = parse(response.body);
      final entries = <model.DictionaryEntry>[];

      // Find all gloss content containers
      final glossContainers = document.querySelectorAll('div.gloss-content.scroll-pane > dl');
      
      for (int i = 0; i < glossContainers.length; i++) {
        final container = glossContainers[i];
        
        try {
          // Remove any note elements that might interfere
          final notesToRemove = container.querySelectorAll('.sense-info-note.has-tip');
          for (final note in notesToRemove) {
            note.remove();
          }

          // Get the main term/reading from the dt element
          final dtElement = container.querySelector('dt');
          if (dtElement == null) continue;
          
          String termReading = dtElement.innerHtml;
          String extractedTerm = termReading;
          
          // Extract the actual term from the dt element (removing numbers if present)
          final parts = termReading.split(' ');
          if (parts.length > 1 && int.tryParse(parts[0].substring(0, 1)) != null) {
            extractedTerm = parts[1];
          } else {
            extractedTerm = parts[0];
          }

          // Get the definitions from li elements
          final definitionElements = container.querySelectorAll('li');
          final definitions = <String>[];
          
          for (final defElement in definitionElements) {
            if (defElement.innerHtml.isNotEmpty) {
              definitions.add(defElement.innerHtml);
            }
          }

          // Get additional context from parent elements
          String context = '';
          final parentContainer = container.parent?.parent;
          if (parentContainer != null) {
            final contextElement = parentContainer.children.firstWhere(
              (el) => el.classes.contains('term-and-readings'),
              orElse: () => Element.tag('div'),
            );
            
            if (contextElement.localName != 'div' || contextElement.text.isNotEmpty) {
              context = contextElement.text;
            }
          }

          // Create a dictionary entry
          final entry = model.DictionaryEntry(
            id: i, // Using index as temporary ID
            dictionaryId: 999, // Special ID for ichi.moe entries
            term: extractedTerm,
            reading: '', // Will be filled if available
            definitionTags: [],
            rules: [],
            popularity: 0.0,
            definitions: definitions.isNotEmpty ? definitions : [context],
            sequence: i,
            termTags: ['ichi.moe'], // Mark as coming from ichi.moe
          );

          entries.add(entry);
        } catch (e) {
          print('Error parsing entry $i: $e');
          continue;
        }
      }

      return entries;
    } catch (e) {
      print('Error fetching ichi.moe data: $e');
      return [];
    }
  }

  /// Enhanced search that also extracts readings and conjugations
  Future<List<model.DictionaryEntry>> searchWithDetails(String term, {bool useRomaji = true}) async {
    try {
      final rmj = useRomaji ? 'hb' : 'kana';
      final url = 'https://ichi.moe/cl/qr/?r=$rmj&q=${Uri.encodeComponent(term)}';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load ichi.moe data: ${response.statusCode}');
      }

      final document = parse(response.body);
      final entries = <model.DictionaryEntry>[];

      // Find all gloss content containers
      final glossContainers = document.querySelectorAll('div.gloss-content.scroll-pane > dl');
      
      for (int i = 0; i < glossContainers.length; i++) {
        final container = glossContainers[i];
        
        try {
          // Remove any note elements that might interfere
          final notesToRemove = container.querySelectorAll('.sense-info-note.has-tip');
          for (final note in notesToRemove) {
            note.remove();
          }

          // Process conjugation/via elements
          final conjViaElement = container.querySelector('.conj-via');
          final meaningElements = container.querySelectorAll('li');
          final compoundElement = container.querySelector('dl>dt');
          final compoundDescWord = container.querySelector('.compound-desc-word');
          final compoundGloss = container.querySelector('.compound-gloss');
          final compoundSection = container.querySelector('.compounds');
          
          // Get the main term/reading from the dt element
          final dtElement = container.querySelector('dt');
          if (dtElement == null) continue;
          
          String termReading = dtElement.innerHtml;
          String extractedTerm = termReading;
          
          // Extract the actual term from the dt element (removing numbers if present)
          final parts = termReading.split(' ');
          if (parts.length > 1 && int.tryParse(parts[0].substring(0, 1)) != null) {
            extractedTerm = parts[1];
          } else {
            extractedTerm = parts[0];
          }

          // Determine what to use as the main content
          String mainContent = '';
          List<Element> processedMeanings = [];
          
          // Check if we have compound information
          if (compoundElement != null && compoundSection != null && compoundDescWord != null) {
            // Use compound information as main content
            mainContent = compoundSection.innerHtml;
            // Process meanings separately
            for (final u in meaningElements) {
              if (u.innerHtml != null) {
                processedMeanings.add(u);
              }
            }
          } 
          // Check if we have conjugation information
          else if (conjViaElement != null) {
            // Use parent element's dd content
            final ddElement = container.querySelector('dd');
            if (ddElement != null) {
              // Clear and rebuild dd content with meanings
              ddElement.innerHtml = '';
              for (final u in meaningElements) {
                if (u.innerHtml != null) {
                  ddElement.innerHtml += '<li>${u.innerHtml}</li>';
                }
              }
              mainContent = ddElement.innerHtml;
            }
          } 
          // Check if we have compound gloss
          else if (compoundGloss != null) {
            final ddElement = container.querySelector('dd');
            if (ddElement != null) {
              // Clear and rebuild dd content with meanings
              ddElement.innerHtml = '';
              for (final u in meaningElements) {
                if (u.innerHtml != null) {
                  ddElement.innerHtml += '<li>${u.innerHtml}</li>';
                }
              }
              mainContent = ddElement.innerHtml;
            }
          } 
          // Default: just use the meanings
          else {
            for (final u in meaningElements) {
              if (u.innerHtml != null) {
                mainContent += '<li>${u.innerHtml}</li>';
              }
            }
          }

          // Get definitions
          final definitions = <String>[];
          if (mainContent.isNotEmpty) {
            definitions.add(mainContent);
          }
          
          // Add any additional meanings that weren't processed
          for (final defElement in meaningElements) {
            if (defElement.innerHtml.isNotEmpty && !mainContent.contains(defElement.innerHtml)) {
              definitions.add(defElement.innerHtml);
            }
          }

          // Create a dictionary entry
          final entry = model.DictionaryEntry(
            id: i + 10000, // Using higher ID to distinguish from other sources
            dictionaryId: 999, // Special ID for ichi.moe entries
            term: extractedTerm,
            reading: '', // Will be filled if available from context
            definitionTags: [],
            rules: [],
            popularity: 0.0,
            definitions: definitions.isNotEmpty ? definitions : ['No definitions found'],
            sequence: i,
            termTags: ['ichi.moe', 'enhanced'], // Mark as coming from ichi.moe with enhanced parsing
          );

          entries.add(entry);
        } catch (e) {
          print('Error parsing entry $i with details: $e');
          continue;
        }
      }

      return entries;
    } catch (e) {
      print('Error fetching ichi.moe data with details: $e');
      return [];
    }
  }
}