import 'chinese_util.dart';

class IdeographicUtil {
  // Common Chinese radicals that can act as particles/components
  static const List<String> commonRadicals = [
    // Single-stroke radicals
    '一', '丨', '丶', '丿', '乙', '亅',
    
    // Two-stroke radicals
    '二', '亠', '人', '儿', '入', '八', '冂', '冖', '冫', '几', '凵', '刀', 
    '力', '勹', '匕', '匚', '十', '卜', '卩', '厂', '厶', '又', '亻', '丷',
    
    // Three-stroke radicals
    '三', '宀', '廴', '尢', '弋', '弓', '彐', '彡', '彳', '心', '忄', '戈', 
    '戶', '户', '手', '扌', '支', '攵', '文', '斗', '斤', '方', '无', '日', 
    '曰', '月', '木', '欠', '止', '歹', '殳', '毋', '比', '毛', '氏', '气', 
    '水', '氵', '火', '灬', '爪', '爫', '父', '爻', '爿', '片', '牙', '牛', 
    '犬', '犭', '玄', '玉', '王', '瓜', '瓦', '甘', '生', '用', '田', '疋', 
    '疒', '癶', '白', '皮', '皿', '目', '矛', '矢', '石', '示', '礻', '禸', 
    '禾', '穴', '立', '竹', '糸', '纟', '网', '罒', '羊', '羴', '羽', '老', 
    '而', '耒', '耳', '聿', '肉', '臣', '自', '至', '臼', '舌', '舛', '舟', 
    '艮', '色', '艸', '艹', '虍', '虫', '血', '行', '衣', '衤', '西', '襾', 
    '見', '见', '角', '言', '訁', '谷', '豆', '豕', '豸', '貝', '貝', '赤', 
    '走', '足', '身', '車', '車', '辛', '辰', '辵', '辶', '邑', '酉', '釆', 
    '里', '金', '釒', '長', '長', '門', '阜', '隶', '隹', '雨', '靑', '非', 
    '面', '革', '韋', '韭', '音', '頁', '風', '飛', '食', '饣', '首', '香', 
    '馬', '骨', '高', '髟', '鬥', '鬯', '鬲', '鬼', '魚', '鳥', '鹵', '鹿', 
    '麥', '麻', '黃', '黍', '黑', '黹', '黽', '鼎', '鼓', '鼠', '鼻', '齊', 
    '齒', '龍', '龜', '龠',
    
    // Common particles/components in Chinese characters
    '口', '日', '月', '木', '水', '火', '土', '金', '山', '石', '田', '心',
    '宀', '扌', '氵', '灬', '忄', '犭', '艹', '竹', '米', '女', '子', '宀',
    '宀', '宀', '宀', // Repeat for emphasis
    '宀', '宀', '宀',
    '亻', // Person radical
    '彳', // Walking radical
    '亍', // Small step radical
    '罒', // Eye radical (used in many characters)
    '礻', // Ritual radical
    '衤', // Clothing radical
    '饣', // Food radical
    '钅', // Metal radical
    '釒', // Metal radical variant
    '亠', // Studied radical
    '儿', // Person radical variant
    '入', // Enter radical
    '八', // Eight radical
    '厶', // Private radical
    '卩', // Seal radical
  ];

  /// Find all ideographic components/particles in a given character
  static List<String> getComponents(String character) {
    if (character.isEmpty) return [];

    // For now, we'll use a simple approach - return each radical found in the character
    final components = <String>{};
    
    // Check each known radical to see if it appears in the character
    for (final radical in commonRadicals) {
      if (character.contains(radical)) {
        components.add(radical);
      }
    }
    
    // Also return the character itself as a component
    if (components.isEmpty) {
      return [character];
    }
    
    return components.toList();
  }

  /// Search for characters containing specific radical/particle
  static List<String> findCharactersByParticle(String particle, List<String> allCharacters) {
    return allCharacters.where((char) => char.contains(particle)).toList();
  }

  /// Get decomposition of a character into radicals/components
  static Map<String, dynamic> decomposeCharacter(String character) {
    final components = getComponents(character);
    
    return {
      'character': character,
      'components': components,
      'hasComponents': components.length > 1,
      'componentCount': components.length,
    };
  }

  /// Search for characters that share common components
  static List<String> findSimilarByStructure(String character, List<String> allCharacters) {
    final targetComponents = getComponents(character);
    final similar = <String>{};
    
    for (final c in allCharacters) {
      if (c == character) continue; // Skip the same character
      
      final components = getComponents(c);
      // Find intersection of components
      final commonComponents = targetComponents.toSet().intersection(components.toSet());
      
      if (commonComponents.isNotEmpty) {
        similar.add(c);
      }
    }
    
    return similar.toList();
  }

  /// Check if text contains ideographic characters (Chinese, Kanji, Hanja)
  static bool containsIdeographic(String text) {
    return ChineseUtil.containsIdeographic(text);
  }

  /// Check if text contains Chinese characters specifically
  static bool containsChinese(String text) {
    return ChineseUtil.containsChinese(text);
  }

  /// Check if text contains Japanese Kanji characters
  static bool containsKanji(String text) {
    return ChineseUtil.containsJapaneseKanji(text);
  }
}