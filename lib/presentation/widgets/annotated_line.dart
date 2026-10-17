import 'package:flutter/material.dart';

import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart'
    show TokenizerService;
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/utils/chinese_util.dart';
import 'package:lang/utils/pinyin_util.dart';

/// One diacritized word in the transcript: surface, reading and the
/// word types the dictionary gave it.
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
  });

  final String text;
  final AppState appState;
  final double fontSize;
  final FontWeight weight;

  /// Reading size as a fraction of the base size.
  static const double readingScale = 0.6;

  /// Whether a reading belongs above [token] under the current style:
  /// `off` never reads, `furigana`/`pinyin` read only their script,
  /// `auto` reads whenever a reading is known.
  static bool hasReadingFor(String style, AnnotatedToken token) {
    if (style == 'off') return false;
    if ((token.reading ?? '').isEmpty) return false;
    if (style == 'furigana') {
      return token.text.runes.any(
        (c) =>
            c >= 0x4E00 && c <= 0x9FFF || // kanji
            c >= 0x3040 && c <= 0x30FF, // kana
      );
    }
    if (style == 'pinyin') {
      return ChineseUtil.isHanzi(token.text);
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

  Future<List<AnnotatedToken>> _annotate() async {
    final tokens = await DictionaryService().tokenizeText(widget.text);
    return [
      for (final token in tokens)
        AnnotatedToken(
          text: token.text,
          reading: _readingFor(token),
          wordTypes: _wordTypesFromTags(token),
        ),
    ];
  }

  /// Reading for [token]: the dictionary entry's reading, falling back to
  /// a per-character pinyin build for Chinese. Kana and unannotated text
  /// return null (nothing to read above it).
  static String? _readingFor(Token token) {
    final reading = (token.entry?.reading ?? '').trim();
    if (reading.isNotEmpty) return reading;
    if (ChineseUtil.isHanzi(token.text)) {
      return PinyinUtil.getPinyin(token.text) ?? _pinyinPerChar(token.text);
    }
    return null;
  }

  /// Multi-character Chinese: pinyin per character, joined with a space.
  /// Only meaningful when every character resolves — partial pinyin
  /// reads as noise, so a single miss returns null.
  static String? _pinyinPerChar(String word) {
    if (word.length < 2) return null;
    final syllables = <String>[];
    for (final char in word.split('')) {
      if (!ChineseUtil.isHanzi(char)) continue;
      final p = PinyinUtil.getPinyin(char);
      if (p == null) return null;
      syllables.add(p);
    }
    return syllables.isEmpty ? null : syllables.join(' ');
  }

  /// Word types from the entry's merged tag lists, normalized to the
  /// three hues we tint: `verb`, `adjective`, `adverb`.
  static List<String> _wordTypesFromTags(Token token) {
    final tags =
        token.entry?.tags.map((s) => s.toLowerCase()).toList() ??
        const <String>[];
    final has = (Iterable<String> needles) =>
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
        );
      },
    );
  }

  InlineSpan _tokenSpan(BuildContext context, AnnotatedToken token) {
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.weight,
      color: AnnotatedLine.colorFor(context, token, widget.appState),
    );
    if (!AnnotatedLine.hasReadingFor(widget.appState.readingStyle, token)) {
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
