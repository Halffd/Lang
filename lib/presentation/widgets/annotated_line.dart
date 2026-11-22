import 'package:flutter/material.dart';

import 'package:lang_core/lang_core.dart' show Token;
import 'package:lang/data/services/dictionary/tokenizer_service.dart'
    show TokenizerService;
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/utils/chinese_util.dart';
import 'package:lang/utils/pinyin_util.dart';

/// One diacritized word in the transcript: surface, reading and the
/// word types the dictionary gave it. Tokenization runs through the
/// shared lang_core tokenizer (yomichan-backed via the app's
/// DictionaryDb port), with de-conjugation for inflected Japanese
/// forms; Chinese tokens with no dictionary reading fall back to a
/// simple per-character pinyin build.
class AnnotatedToken {
  const AnnotatedToken({
    required this.text,
    this.reading,
    this.wordTypes = const [],
  });

  final String text;
  final String? reading;
  final List<String> wordTypes;
}

/// A tokenized transcript line with furigana or pinyin above words and
/// coloring by learning state / word type. Tokenization runs against the
/// yomichan library via the dictionary service (`tokenizeText`), so the
/// entries already carry authentic readings; Chinese tokens with no
/// dictionary reading fall back to a simple per-character pinyin build.
class AnnotatedLine extends StatefulWidget {
  const AnnotatedLine({
    super.key,
    required this.text,
    required this.appState,
    required this.fontSize,
    required this.weight,
    this.baseStyle,
    this.readingStyle,
    this.textAlign,
  });

  final String text;
  final AppState appState;
  final double fontSize;
  final FontWeight weight;

  /// Style the base text and the reading are painted with.
  ///
  /// Null (the default) keeps the reader behaviour: the base text is
  /// coloured by learning state and word type, and the reading is a
  /// dimmed version of it. Supplying a style pins the colours — what
  /// the video subtitle overlay needs, where the text sits white on a
  /// picture and learning-state colours would be unreadable.
  final TextStyle? baseStyle;

  /// Which reading to draw above the base text. Null takes the
  /// reading style from [appState]; `'off'` draws none.
  final String? readingStyle;

  /// How the text is aligned within its box.
  final TextAlign? textAlign;

  /// Reading size as a fraction of the base size.
  static const double readingScale = 0.6;

  /// Whether a reading belongs above [token] under the current style:
  /// `off` never reads, `furigana`/`pinyin` read only their script,
  /// `auto` reads whenever a reading is known.
  ///
  /// [isChinese] says whether the line is Chinese. Kanji are shared
  /// between the two scripts, so without it a Japanese reading (日 →
  /// ひ) would be drawn under the pinyin style.
  static bool hasReadingFor(
    String style,
    AnnotatedToken token, {
    bool isChinese = false,
  }) {
    if (style == 'off') return false;
    if ((token.reading ?? '').isEmpty) return false;
    if (style == 'furigana') {
      if (isChinese) return false;
      return token.text.runes.any(
        (c) =>
            c >= 0x4E00 && c <= 0x9FFF || // kanji
            c >= 0x3040 && c <= 0x30FF, // kana
      );
    }
    if (style == 'pinyin') {
      // Chinese tokens are words, not single characters, so the gate
      // looks for hanzi anywhere in the token.
      return isChinese && ChineseUtil.containsChinese(token.text);
    }
    return true;
  }

  /// Word color: by learning state first (favorite > saved > learned),
  /// then by word type, else the default surface color.
  static Color colorFor(
    BuildContext context,
    AnnotatedToken token,
    AppState appState,
  ) {
    final theme = Theme.of(context);
    if (!appState.wordColoringEnabled) return theme.colorScheme.onSurface;
    if (appState.favoriteWords.contains(token.text)) {
      return const Color(0xFFB3261E);
    }
    if (appState.savedWords.contains(token.text)) {
      return const Color(0xFF1A6611);
    }
    if (appState.ankiWords.contains(token.text)) {
      return const Color(0xFF7C5800);
    }
    if (token.wordTypes.contains('verb')) return theme.colorScheme.primary;
    if (token.wordTypes.contains('adjective')) {
      return theme.colorScheme.tertiary;
    }
    if (token.wordTypes.contains('adverb')) return theme.colorScheme.secondary;
    return theme.colorScheme.onSurface;
  }

  @override
  State<AnnotatedLine> createState() => AnnotatedLineState();
}

class AnnotatedLineState extends State<AnnotatedLine> {
  late final Future<List<AnnotatedToken>> _tokens = _annotate();

  /// Whether the line is Chinese. Kanji are shared between Chinese and
  /// Japanese, so the reading style needs this to tell the scripts
  /// apart.
  bool _isChinese = false;

  Future<List<AnnotatedToken>> _annotate() async {
    final tokenizer = TokenizerService();
    final tokens = await tokenizer.tokenize(widget.text);
    // Kanji are shared between Chinese and Japanese, so the pinyin
    // fallback must only run on a Chinese line. On a Japanese line it
    // would put Chinese readings over Japanese kanji.
    final isChinese = tokenizer.detectLanguage(widget.text) == 'zh';
    _isChinese = isChinese;
    return [
      for (final token in tokens)
        AnnotatedToken(
          text: token.surface,
          reading: _readingFor(token, isChinese: isChinese),
          wordTypes: _wordTypesFromTags(token),
        ),
    ];
  }

  /// Reading for [token]: the dictionary entry's reading, falling back to
  /// a per-character pinyin build for Chinese. Kana and unannotated text
  /// return null (nothing to read above it).
  ///
  /// The dictionary is Japanese, so its readings are kana. For a Chinese
  /// line they are simply wrong and pinyin stands in — the same rule
  /// [AnalyzedWord.readingFor] applies to looked-up words.
  static String? _readingFor(Token token, {required bool isChinese}) {
    final reading = token.reading.trim();
    if (!isChinese) return reading.isEmpty ? null : reading;
    if (!ChineseUtil.containsChinese(token.surface)) return null;
    return PinyinUtil.getPinyin(token.surface) ?? _pinyinPerChar(token.surface);
  }

  /// Multi-character Chinese: pinyin per character, joined with a space.
  /// Only meaningful when every character resolves — partial pinyin
  /// reads as noise, so a single miss returns null.
  static String? _pinyinPerChar(String word) {
    if (word.length < 2) return null;
    final syllables = <String>[];
    for (final char in word.split('')) {
      if (!ChineseUtil.isHanzi(char)) return null;
      final p = PinyinUtil.getPinyin(char);
      if (p == null) return null;
      syllables.add(p);
    }
    return syllables.isEmpty ? null : syllables.join(' ');
  }

  /// Word types from the entry's merged tag lists, normalized to the
  /// three hues we tint: `verb`, `adjective`, `adverb`.
  static List<String> _wordTypesFromTags(Token token) {
    final tags = token.tags.map((s) => s.toLowerCase()).toList(growable: false);
    bool has(Iterable<String> needles) =>
        needles.any((n) => tags.any((s) => s.contains(n)));
    final types = <String>[];
    if (has(['verb', 'v1', 'v5', 'vk', 'vs', 'vz'])) types.add('verb');
    if (has(['adjective', 'adj-i', 'adj-na', 'i-adjective'])) {
      types.add('adjective');
    }
    if (has(['adverb', 'adv'])) types.add('adverb');
    return types;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnnotatedToken>>(
      future: _tokens,
      initialData: [AnnotatedToken(text: widget.text)],
      builder: (context, snapshot) {
        final tokens = snapshot.data!;
        return Text.rich(
          TextSpan(children: [for (final t in tokens) _tokenSpan(context, t)]),
          textAlign: widget.textAlign,
        );
      },
    );
  }

  /// The reading style in force: the explicit override when given,
  /// otherwise the user's global setting.
  String get _readingStyle =>
      widget.readingStyle ?? widget.appState.readingStyle;

  InlineSpan _tokenSpan(BuildContext context, AnnotatedToken token) {
    final style =
        widget.baseStyle ??
        TextStyle(
          fontSize: widget.fontSize,
          fontWeight: widget.weight,
          color: AnnotatedLine.colorFor(context, token, widget.appState),
        );
    if (!AnnotatedLine.hasReadingFor(
      _readingStyle,
      token,
      isChinese: _isChinese,
    )) {
      return TextSpan(text: token.text, style: style);
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            token.reading!,
            style: style.copyWith(
              fontSize: widget.fontSize * AnnotatedLine.readingScale,
              height: 1.1,
              color: style.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(token.text, style: style.copyWith(height: 1.25)),
        ],
      ),
    );
  }
}
