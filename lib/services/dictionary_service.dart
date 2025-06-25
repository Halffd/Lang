import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dictionary_entry.dart';
import 'package:kana_kit/kana_kit.dart';

class DictionaryService {
  final KanaKit _kanaKit = KanaKit();
  
  // This would typically connect to a real API or local dictionary database
  // For now, we'll implement a mock service with some sample data
  Future<DictionarySearchResult> search(String query, {String language = 'ja'}) async {
    // In a real implementation, this would call an API or query a local database
    if (query.isEmpty) {
      return DictionarySearchResult(entries: [], query: query);
    }
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // For demo purposes, generate some mock entries
    final entries = _generateMockEntries(query);
    
    return DictionarySearchResult(
      entries: entries,
      query: query,
      hasMore: entries.length >= 10,
    );
  }
  
  Future<List<String>> translateText(String text, String fromLang, String toLang) async {
    // In a real implementation, this would use a translation API
    // For now, we'll just return a mock translation
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (fromLang == 'ja' && toLang == 'en') {
      return ['This is a mock translation of "$text" from Japanese to English'];
    } else if (fromLang == 'en' && toLang == 'ja') {
      return ['これは「$text」の英語から日本語へのモック翻訳です'];
    } else {
      return ['Translation from $fromLang to $toLang is not supported yet'];
    }
  }
  
  bool isJapanese(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF\uFF00-\uFFEF\u4E00-\u9FAF]');
    return japaneseRegex.hasMatch(text);
  }
  
  String toHiragana(String text) {
    return _kanaKit.toHiragana(text);
  }
  
  String toKatakana(String text) {
    return _kanaKit.toKatakana(text);
  }
  
  String toRomaji(String text) {
    return _kanaKit.toRomaji(text);
  }
  
  // Mock data generator
  List<DictionaryEntry> _generateMockEntries(String query) {
    final List<DictionaryEntry> entries = [];
    
    // Convert query to hiragana for matching
    final hiraganaQuery = _kanaKit.toHiragana(query);
    
    // Sample Japanese dictionary data
    final mockData = [
      {
        'term': '日本語',
        'reading': 'にほんご',
        'definitions': ['Japanese language'],
        'tags': ['noun'],
        'frequency': 1,
      },
      {
        'term': '勉強',
        'reading': 'べんきょう',
        'definitions': ['study', 'learning', 'homework'],
        'tags': ['noun', 'suru-verb'],
        'frequency': 10,
      },
      {
        'term': '単語',
        'reading': 'たんご',
        'definitions': ['word', 'vocabulary'],
        'tags': ['noun'],
        'frequency': 50,
      },
      {
        'term': '辞書',
        'reading': 'じしょ',
        'definitions': ['dictionary', 'lexicon'],
        'tags': ['noun'],
        'frequency': 100,
      },
      {
        'term': '検索',
        'reading': 'けんさく',
        'definitions': ['search', 'lookup'],
        'tags': ['noun', 'suru-verb'],
        'frequency': 200,
      },
      {
        'term': '言語',
        'reading': 'げんご',
        'definitions': ['language', 'tongue', 'speech'],
        'tags': ['noun'],
        'frequency': 300,
      },
      {
        'term': '翻訳',
        'reading': 'ほんやく',
        'definitions': ['translation', 'interpret'],
        'tags': ['noun', 'suru-verb'],
        'frequency': 400,
      },
      {
        'term': '漢字',
        'reading': 'かんじ',
        'definitions': ['kanji', 'Chinese characters'],
        'tags': ['noun'],
        'frequency': 150,
      },
      {
        'term': 'ひらがな',
        'reading': 'ひらがな',
        'definitions': ['hiragana', 'Japanese syllabary'],
        'tags': ['noun'],
        'frequency': 180,
      },
      {
        'term': 'カタカナ',
        'reading': 'カタカナ',
        'definitions': ['katakana', 'Japanese syllabary'],
        'tags': ['noun'],
        'frequency': 190,
      },
    ];
    
    // Filter entries based on query
    for (final data in mockData) {
      final term = data['term'] as String;
      final reading = data['reading'] as String;
      final definitions = List<String>.from(data['definitions'] as List);
      
      if (term.contains(query) || 
          reading.contains(hiraganaQuery) || 
          definitions.any((def) => def.toLowerCase().contains(query.toLowerCase()))) {
        
        entries.add(DictionaryEntry(
          term: term,
          reading: reading,
          definitions: definitions,
          tags: List<String>.from(data['tags'] as List),
          frequency: data['frequency'] as int,
          examples: [],
        ));
      }
    }
    
    // If no matches, add some default entries
    if (entries.isEmpty) {
      entries.add(DictionaryEntry(
        term: query,
        reading: _kanaKit.toHiragana(query),
        definitions: ['No exact matches found'],
        tags: [],
        frequency: -1,
        examples: [],
      ));
    }
    
    return entries;
  }
}
