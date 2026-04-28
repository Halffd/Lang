import 'dart:convert';

// Model for Chinese tones
class ToneInfo {
  final int? id;
  final int dictionaryId;
  final String term;
  final String reading; // Pinyin for Mandarin, Jyutping for Cantonese
  final String language; // 'mandarin', 'cantonese', etc.
  final List<TonePattern> tones;

  ToneInfo({
    this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    required this.language,
    required this.tones,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dictionary_id': dictionaryId,
      'term': term,
      'reading': reading,
      'language': language,
      'tones': jsonEncode(tones.map((t) => t.toMap()).toList()),
    };
  }

  factory ToneInfo.fromMap(Map<String, dynamic> map) {
    return ToneInfo(
      id: map['id'] as int?,
      dictionaryId: map['dictionary_id'] as int,
      term: map['term'] as String,
      reading: map['reading'] as String,
      language: map['language'] as String,
      tones: (jsonDecode(map['tones']) as List)
          .map((t) => TonePattern.fromMap(t))
          .toList(),
    );
  }
}

class TonePattern {
  final int position; // Character position in the word (0-indexed)
  final int toneNumber; // 1-4 for Mandarin, 1-6 for Cantonese, 0 for neutral
  final String? toneType; // 'high-level', 'rising', 'dipping', 'falling', etc.
  final String? romanization; // The specific reading with tone marks

  TonePattern({
    required this.position,
    required this.toneNumber,
    this.toneType,
    this.romanization,
  });

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'tone_number': toneNumber,
      if (toneType != null) 'tone_type': toneType,
      if (romanization != null) 'romanization': romanization,
    };
  }

  factory TonePattern.fromMap(Map<String, dynamic> map) {
    return TonePattern(
      position: map['position'] as int,
      toneNumber: map['tone_number'] as int,
      toneType: map['tone_type'] as String?,
      romanization: map['romanization'] as String?,
    );
  }
  
  // Get tone mark symbol for Mandarin
  String getMandarinToneMark() {
    switch (toneNumber) {
      case 1: return 'ˉ'; // First tone (flat)
      case 2: return 'ˊ'; // Second tone (rising)
      case 3: return 'ˇ'; // Third tone (dipping)
      case 4: return 'ˋ'; // Fourth tone (falling)
      default: return ''; // Neutral tone
    }
  }
  
  // Get tone mark symbol for Cantonese
  String getCantoneseToneMark() {
    // Cantonese has 6 tones, but often simplified to 3 categories
    switch (toneNumber) {
      case 1: return '˥'; // High level
      case 2: return '˧˥'; // High rising
      case 3: return '˧'; // Mid level
      case 4: return '˨˩'; // Low falling
      case 5: return '˩˧'; // Low rising
      case 6: return '˨'; // Low level
      default: return '';
    }
  }
  
  // Get tone name in English
  String getToneName(String language) {
    if (language == 'mandarin') {
      switch (toneNumber) {
        case 1: return 'First Tone (high level)';
        case 2: return 'Second Tone (rising)';
        case 3: return 'Third Tone (dipping)';
        case 4: return 'Fourth Tone (falling)';
        default: return 'Neutral Tone';
      }
    } else if (language == 'cantonese') {
      switch (toneNumber) {
        case 1: return 'High Level (yam1)';
        case 2: return 'High Rising (yam2)';
        case 3: return 'Mid Level (yam3)';
        case 4: return 'Low Falling (yam4)';
        case 5: return 'Low Rising (yam5)';
        case 6: return 'Low Level (yam6)';
        default: return 'Tone $toneNumber';
      }
    }
    return 'Tone $toneNumber';
  }
}

// Model for tone display representation
class ToneDisplay {
  final String pinyinWithTones; // Like "nǐ hǎo"
  final String toneNumbers; // Like "3 3" for nǐ hǎo
  final List<String> individualTones; // List of individual tone marks
  final String language;

  ToneDisplay({
    required this.pinyinWithTones,
    required this.toneNumbers,
    required this.individualTones,
    required this.language,
  });
  
  static ToneDisplay fromToneInfo(ToneInfo toneInfo) {
    final pinyinParts = toneInfo.reading.split(' ');
    final pinyinWithTonesParts = <String>[];
    
    for (int i = 0; i < pinyinParts.length; i++) {
      final pinyin = pinyinParts[i];
      final tonePattern = toneInfo.tones.firstWhere(
        (t) => t.position == i,
        orElse: () => TonePattern(position: i, toneNumber: 0),
      );
      
      // Apply tone marks to pinyin characters
      final tonedPinyin = _applyToneToPinyin(pinyin, tonePattern.toneNumber);
      pinyinWithTonesParts.add(tonedPinyin);
    }
    
    final pinyinWithTones = pinyinWithTonesParts.join(' ');
    final toneNumbers = toneInfo.tones.map((t) => t.toneNumber.toString()).join(' ');
    final individualTones = toneInfo.tones.map((t) => t.getToneName(toneInfo.language)).toList();
    
    return ToneDisplay(
      pinyinWithTones: pinyinWithTones,
      toneNumbers: toneNumbers,
      individualTones: individualTones,
      language: toneInfo.language,
    );
  }
  
  static String _applyToneToPinyin(String pinyin, int toneNumber) {
    if (toneNumber <= 0 || toneNumber > 4) return pinyin; // No tone or neutral
    
    // This is a simplified implementation - a full implementation would map
    // each vowel according to Chinese pinyin tone rules
    final vowelMap = {
      1: { 'a': 'ā', 'o': 'ō', 'e': 'ē', 'i': 'ī', 'u': 'ū', 'ü': 'ǖ' },
      2: { 'a': 'á', 'o': 'ó', 'e': 'é', 'i': 'í', 'u': 'ú', 'ü': 'ǘ' },
      3: { 'a': 'ǎ', 'o': 'ǒ', 'e': 'ě', 'i': 'ǐ', 'u': 'ǔ', 'ü': 'ǚ' },
      4: { 'a': 'à', 'o': 'ò', 'e': 'è', 'i': 'ì', 'u': 'ù', 'ü': 'ǜ' },
    };
    
    final vowels = ['a', 'o', 'e', 'i', 'u', 'ü'];
    final toneVowelMap = vowelMap[toneNumber]!;
    
    // Find the primary vowel to apply tone mark to
    // According to pinyin rules: a > o > e > i > u > ü
    for (final vowel in vowels) {
      if (pinyin.toLowerCase().contains(vowel)) {
        return pinyin.replaceAll(vowel, toneVowelMap[vowel]!);
      }
    }
    
    // If no vowel found in the map, return original
    return pinyin;
  }
}