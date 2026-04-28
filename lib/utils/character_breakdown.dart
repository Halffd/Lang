import 'dart:convert';
import 'chinese_util.dart';
import '../../domain/entities/dictionary.dart' as model;

class CharacterBreakdown {
  /// Break down a compound word into individual characters with their meanings
  static List<CharacterInfo> breakdownWord(String word) {
    final characters = <CharacterInfo>[];
    
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      
      // Check if the character is an ideographic character (Chinese, Japanese, etc.)
      if (ChineseUtil.containsIdeographic(char)) {
        // Create a character info object
        characters.add(CharacterInfo(
          character: char,
          position: i,
          isIdeographic: true,
          pinyin: ChineseUtil.toPinyin(char),
          meaning: '', // This would be populated from dictionary lookup
          onyomi: '', // Japanese reading if applicable
          kunyomi: '', // Japanese reading if applicable
        ));
      } else {
        // For non-ideographic characters, just return basic info
        characters.add(CharacterInfo(
          character: char,
          position: i,
          isIdeographic: false,
          pinyin: '',
          meaning: '',
          onyomi: '',
          kunyomi: '',
        ));
      }
    }
    
    return characters;
  }

  /// Get detailed information for each character from the search result
  static List<CharacterInfo> breakdownWithDetails(
    String word,
    List<model.DictionaryEntry> entries,
    List<model.KanjiEntry> kanjiEntries,
  ) {
    final characters = <CharacterInfo>[];
    
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      
      if (ChineseUtil.containsIdeographic(char)) {
        // Try to find detailed information for this character
        final charEntry = entries.firstWhere(
          (entry) => entry.term == char,
          orElse: () => model.DictionaryEntry.fromData(term: char, reading: '', definitions: []),
        );
        
        final charKanji = kanjiEntries.firstWhere(
          (kanji) => kanji.character == char,
          orElse: () => model.KanjiEntry(character: char, meanings: [], dictionaryId: 0),
        );
        
        characters.add(CharacterInfo(
          character: char,
          position: i,
          isIdeographic: true,
          pinyin: charEntry.reading.isNotEmpty ? charEntry.reading : ChineseUtil.toPinyin(char),
          meaning: charEntry.definitions.isNotEmpty 
              ? charEntry.definitions.first 
              : (charKanji.meanings.isNotEmpty ? charKanji.meanings.first : ''),
          onyomi: charKanji.onyomi?.join(', ') ?? '',
          kunyomi: charKanji.kunyomi?.join(', ') ?? '',
          definitions: charEntry.definitions,
          onyomiList: charKanji.onyomi ?? [],
          kunyomiList: charKanji.kunyomi ?? [],
        ));
      } else {
        characters.add(CharacterInfo(
          character: char,
          position: i,
          isIdeographic: false,
          pinyin: '',
          meaning: '',
          onyomi: '',
          kunyomi: '',
        ));
      }
    }
    
    return characters;
  }
}

class CharacterInfo {
  final String character;
  final int position;
  final bool isIdeographic;
  final String pinyin;
  final String meaning;
  final String onyomi;
  final String kunyomi;
  final List<String> definitions;
  final List<String> onyomiList;
  final List<String> kunyomiList;

  CharacterInfo({
    required this.character,
    required this.position,
    required this.isIdeographic,
    required this.pinyin,
    required this.meaning,
    required this.onyomi,
    required this.kunyomi,
    this.definitions = const [],
    this.onyomiList = const [],
    this.kunyomiList = const [],
  });

  @override
  String toString() {
    return 'CharacterInfo{character: $character, position: $position, isIdeographic: $isIdeographic, pinyin: $pinyin, meaning: $meaning}';
  }
}