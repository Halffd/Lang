import 'package:lang/utils/chinese_util.dart';
import 'package:lang/domain/entities/tone_model.dart';

// This is a test file to demonstrate how search terms would be processed
void main() {
  // Test with "xiexie" (谢谢) and "huanglong" (黄龙)
  String input1 = "xiexie";
  String input2 = "huanglong";
  
  print("Testing search for: $input1");
  print("Contains Chinese characters: ${ChineseUtil.containsChinese(input1)}");
  print("Looks like Chinese Pinyin: ${ChineseUtil.looksLikeChinesePinyin(input1)}");
  print("Pinyin variations: ${ChineseUtil.getAllSearchVariations(input1)}");
  print("Spaced Pinyin: ${ChineseUtil.toSpacedPinyin(input1)}");
  print("Pinyin without tone: ${ChineseUtil.toPinyinWithoutTone(input1)}");
  print("Pinyin with tone numbers: ${ChineseUtil.toPinyinWithToneNumber(input1)}");
  print("Pinyin initials: ${ChineseUtil.getPinyinInitials(input1)}");
  print("");
  
  print("Testing search for: $input2");
  print("Contains Chinese characters: ${ChineseUtil.containsChinese(input2)}");
  print("Looks like Chinese Pinyin: ${ChineseUtil.looksLikeChinesePinyin(input2)}");
  print("Pinyin variations: ${ChineseUtil.getAllSearchVariations(input2)}");
  print("Spaced Pinyin: ${ChineseUtil.toSpacedPinyin(input2)}");
  print("Pinyin without tone: ${ChineseUtil.toPinyinWithoutTone(input2)}");
  print("Pinyin with tone numbers: ${ChineseUtil.toPinyinWithToneNumber(input2)}");
  print("Pinyin initials: ${ChineseUtil.getPinyinInitials(input2)}");
  print("");
  
  // Demonstrate how tone information would be displayed
  print("Example tone information for 'xiexie' (谢谢):");
  var toneExample = ToneInfo(
    id: 1,
    dictionaryId: 1,
    term: "谢谢",
    reading: "xiè xie",
    language: "mandarin",
    tones: [
      TonePattern(position: 0, toneNumber: 4, toneType: "falling", romanization: "xiè"),
      TonePattern(position: 1, toneNumber: 0, toneType: "neutral", romanization: "xie"),
    ]
  );
  
  var toneDisplay = ToneDisplay.fromToneInfo(toneExample);
  print("Pinyin with tones: ${toneDisplay.pinyinWithTones}");
  print("Tone numbers: ${toneDisplay.toneNumbers}");
  print("Tone names: ${toneDisplay.individualTones}");
  print("Language: ${toneDisplay.language}");
}