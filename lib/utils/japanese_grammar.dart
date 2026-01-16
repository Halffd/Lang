import 'package:kana_kit/kana_kit.dart';

class JapaneseGrammar {
  static KanaKit? _kanaKit;
  static KanaKit get kanaKit => _kanaKit ??= KanaKit();
  
  /// Dictionary of common verb ending patterns and their stem forms
  static const Map<String, List<String>> verbEndingPatterns = {
    // Ichidan verbs (group 2)
    'ます': ['ます', 'る', ''],  // 行きます -> 行き, 食べる -> 食べ
    'ない': ['', 'る', ''],     // 食べない -> 食べ + る
    'なかった': ['', 'る', 'た'], // 食べなかった -> 食べ + た
    'なくて': ['', 'る', 'て'], // 食べなくて -> 食べ + て
    'よう': ['う', 'る', ''],    // 食べよう -> 食べ + る
    'ますた': ['ます', 'る', 'た'], // 食べました -> 食べ + た
    
    // Godan verbs (group 1)
    'う': ['う', '', ''],
    'く': ['く', 'か', ''],
    'ぐ': ['ぐ', 'が', ''],
    'す': ['す', 'し', ''],
    'つ': ['つ', 'ち', ''],
    'ぬ': ['ぬ', 'に', ''],
    'ぶ': ['ぶ', 'ば', ''],
    'む': ['む', 'ま', ''],
    'る': ['る', 'ら', ''],
    'い': ['い', '行', ''], // Special for 行く->行く
    
    // Conditional forms
    'えば': ['', '', 'う'], // 書けば -> 書く
    'ったら': ['', '', 'る'], // 行ったら -> 行く
    'たら': ['', '', 'る'],  // 食べたら -> 食べる
    
    // Te-form variations
    'て': ['て', 'る', ''], // 行って -> 行く
    'で': ['で', 'る', ''], // 行って (いく、ある、する etc)
    
    // Potential/Others
    'れる': ['れる', 'る', ''],
    'せる': ['せる', 'る', ''],
    'られる': ['られる', 'る', ''],
    'させる': ['させる', 'る', ''],
    'しめる': ['しめる', 'る', ''],
  };

  // Common irregular verbs
  static const Map<String, List<String>> irregularVerbs = {
    'する': ['する', 'する', 'した', 'して', 'しね', 'しろ', 'せよ'], // suru
    '来る': ['来る', 'くる', '来た', '来て', 'こね', '来い', '来よ'], // kuru
    '行く': ['行く', 'いく', '行った', '行って', 'いかな', '行け', '行け'], // iku
    '為る': ['為る', 'する', 'した', 'して', 'しな', 'しろ', 'せよ'], // suru (alternative form)
  };

  /// Try to convert conjugated verb to its dictionary form
  static String normalizeVerb(String word) {
    // First check for irregular verbs
    for (final entry in irregularVerbs.entries) {
      if (word.contains(entry.key) || entry.value.any((form) => word.contains(form))) {
        // Find which form this might be and return the dictionary form
        for (final form in entry.value) {
          if (word.endsWith(form)) {
            final prefix = word.substring(0, word.length - form.length);
            return prefix + entry.key;
          }
        }
      }
    }

    // Check for common patterns for regular verbs
    // Ordered from longest patterns to shortest to avoid incorrect matches
    
    // Negative forms
    if (word.endsWith('ません')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('ないです') || word.endsWith('ありません')) {
      return word.substring(0, word.length - 4) + 'る';
    } else if (word.endsWith('ませんでした') || word.endsWith('ました')) {
      return word.substring(0, word.length - 4) + 'る';
    } else if (word.endsWith('ませんでした')) {
      return word.substring(0, word.length - 6) + 'る';
    } else if (word.endsWith('なかった') || word.endsWith('なくて')) {
      return word.substring(0, word.length - 4) + 'る';
    } else if (word.endsWith('ない')) {
      return word.substring(0, word.length - 2) + 'る';
    }
    
    // Past tense forms (richest verbs)
    else if (word.endsWith('ました')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('ました')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('いた') || word.endsWith('いました')) {
      if (word.endsWith('いました')) {
        return word.substring(0, word.length - 4) + 'いく';
      } else {
        return word.substring(0, word.length - 2) + 'いく';
      }
    } else if (word.endsWith('った') || word.endsWith('いった')) {
      return word.substring(0, word.length - 2) + 'う';
    } else if (word.endsWith('んだ') || word.endsWith('んで')) {
      return word.substring(0, word.length - 2) + 'む';
    } else if (word.endsWith('んだ')) {
      return word.substring(0, word.length - 2) + 'む';
    } else if (word.endsWith('した')) {
      return word.substring(0, word.length - 2) + 'する';
    } else if (word.endsWith('来た')) {
      return word.substring(0, word.length - 2) + '来る';
    } else if (word.endsWith('た')) {
      // Ichidan - drop syllable before た
      return word.substring(0, word.length - 1) + 'る';
    }
    
    // Te-form
    else if (word.endsWith('って')) {
      return word.substring(0, word.length - 2) + 'う';
    } else if (word.endsWith('んで') || word.endsWith('で')) {
      // Check if it's -ぶ, -む, -ぬ stem
      if (word.endsWith('んで')) {
        return word.substring(0, word.length - 2) + 'む';
      } else if (word.endsWith('で')) {
        // Could be multiple forms, try common patterns
        return word.substring(0, word.length - 1) + 'る';
      }
    } else if (word.endsWith('て')) {
      return word.substring(0, word.length - 1) + 'る';
    }
    
    // Conditional forms
    else if (word.endsWith('えば')) {
      // Godan -e conditional -> -u
      return word.substring(0, word.length - 2) + 'う';
    } else if (word.endsWith('れば')) {
      // Ichidan conditional
      return word.substring(0, word.length - 2) + 'る';
    } else if (word.endsWith('ったら') || word.endsWith('ったら')) {
      return word.substring(0, word.length - 3) + 'う';
    } else if (word.endsWith('たら')) {
      return word.substring(0, word.length - 2) + 'る';
    }
    
    // Potential/Passive/Causative forms
    else if (word.endsWith('られます') || word.endsWith('られる')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('られた')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('られて')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('られ')) {
      return word.substring(0, word.length - 2) + 'る';
    } else if (word.endsWith('えます')) {
      return word.substring(0, word.length - 3) + 'う';
    } else if (word.endsWith('える')) {
      return word.substring(0, word.length - 2) + 'う';
    } else if (word.endsWith('せます')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('せる')) {
      return word.substring(0, word.length - 2) + 'る';
    } else if (word.endsWith('させた')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('させる')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('させ')) {
      return word.substring(0, word.length - 2) + 'る';
    }
    
    // Volitional forms
    else if (word.endsWith('ましょう') || word.endsWith('ましょ')) {
      return word.substring(0, word.length - 3) + 'る';
    } else if (word.endsWith('ろう') || word.endsWith('ろ')) {
      return word.substring(0, word.length - (word.endsWith('ろう') ? 2 : 1)) + 'る';
    } else if (word.endsWith('よう')) {
      return word.substring(0, word.length - 2) + 'う';
    }
    
    // Adjective forms
    else if (word.endsWith('かった')) {
      return word.substring(0, word.length - 3) + 'い';
    } else if (word.endsWith('くない')) {
      return word.substring(0, word.length - 3) + 'い';
    } else if (word.endsWith('くなかった')) {
      return word.substring(0, word.length - 5) + 'い';
    }
    
    // Special i-adjective handling
    else if (word.endsWith('です')) {
      return word.substring(0, word.length - 2);
    }
    
    // If none of these patterns matched, return the word as-is
    return word;
  }

  /// Normalize a word by checking for all possible conjugations
  static List<String> getAllPossibleForms(String word) {
    final forms = <String>{};
    forms.add(word);
    forms.add(normalizeVerb(word));

    // If word contains kanji, also consider reading variations
    if (hasKanji(word)) {
      // Add hiragana version
      try {
        final hiragana = kanaKit.toHiragana(word);
        forms.add(hiragana);
        // Also normalize the hiragana form
        forms.add(normalizeVerb(hiragana));
      } catch (e) {
        // If conversion fails, continue
      }
    }

    return forms.toList();
  }

  static bool hasKanji(String text) {
    final RegExp kanjiRegex = RegExp(r'[\u4e00-\u9faf]');
    return kanjiRegex.hasMatch(text);
  }
}