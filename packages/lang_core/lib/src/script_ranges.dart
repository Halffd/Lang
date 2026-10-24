/// Pure-Dart classification of writing-script ranges, used by the
/// language detector and the tokenizer to route text to the right
/// segmentation strategy.
///
/// These are the ranges the app's detector actually branches on; keep
/// them in one place so detection, tokenization and UI coloring agree.
class ScriptRanges {
  ScriptRanges._();

  static bool containsChinese(String text) => text.runes.any(
        (c) =>
            (c >= 0x4E00 && c <= 0x9FFF) || // CJK Unified Ideographs
            (c >= 0x3400 && c <= 0x4DBF) || // Extension A
            (c >= 0xF900 && c <= 0xFAFF), // Compatibility Ideographs
      );

  static bool isHiragana(int c) => c >= 0x3040 && c <= 0x309F;

  static bool isKatakana(int c) => c >= 0x30A0 && c <= 0x30FF;

  static bool isKana(int c) => isHiragana(c) || isKatakana(c);

  static bool isKanji(int c) =>
      (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF);

  static bool isHangul(int c) => c >= 0xAC00 && c <= 0xD7AF;

  /// CJK scripts the dictionary-backed tokenizer segments.
  static bool isCjkChar(int c) =>
      isKana(c) ||
      isKanji(c) ||
      isHangul(c) ||
      containsChinese(String.fromCharCode(c));
}
