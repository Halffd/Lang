import 'package:lang/data/datasources/remote/wiktionary_lookup_service.dart';
import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';

/// Shared composition of tokenizer + dictionary + wiktionary lookups.
///
/// The analyzer provider and the speech tab both build word cards the
/// same way: dictionary-backed languages (ja/zh/ko) go tokenize →
/// dedupe → Yomichan enrich; space-separated languages go Wiktionary
/// REST → flattened '(pos) definition' lines. This is the single home
/// for that pipeline.
class LookupService {
  LookupService({
    TokenizerService? tokenizer,
    YomichanService? yomichan,
    WiktionaryLookupService? wiktionary,
  }) : _tokenizer = tokenizer ?? TokenizerService(),
       _yomichan = yomichan ?? YomichanService(),
       _wiktionary = wiktionary ?? WiktionaryLookupService();

  static final LookupService instance = LookupService();

  /// Languages with installed-dictionary enrichment; everything else
  /// falls back to Wiktionary.
  static const yomichanLanguages = {'ja', 'zh', 'ko'};

  final TokenizerService _tokenizer;
  final YomichanService _yomichan;
  final WiktionaryLookupService _wiktionary;

  /// Distinct word surfaces from [text] via the tokenizer, filtered for
  /// empties and pure numerals, capped at [limit]. Order preserved.
  Future<List<String>> uniqueSurfaces(
    String text, {
    int limit = 50,
    Set<String> exclude = const {},
  }) async {
    final tokens = await _tokenizer.tokenize(text);
    final seen = <String>{};
    final out = <String>[];
    for (final token in tokens) {
      final surface = token.surface.trim();
      if (surface.isEmpty ||
          seen.contains(surface) ||
          exclude.contains(surface) ||
          RegExp(r'^\d+$').hasMatch(surface)) {
        continue;
      }
      seen.add(surface);
      out.add(surface);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Wiktionary enrichment for space-separated languages: supported-
  /// language gate, one REST call, groups flattened to definition lines.
  /// Returns null when unsupported or nothing found.
  Future<AnalyzedWord?> enrichViaWiktionary(
    String word,
    String language, {
    String override = 'auto',
    String? sentence,
  }) async {
    if (!WiktionaryLookupService.isSupported(language, override: override)) {
      return null;
    }
    final defs = await _wiktionary.lookup(word, language, override: override);
    if (defs.isEmpty) return null;
    return AnalyzedWord(
      word: word,
      sentence: sentence,
      wiktionaryDefinitions: flattenWiktionary(defs),
      sourceDictionary: 'wiktionary',
    );
  }

  /// Flatten definition groups to '(pos) definition' lines for the card
  /// display.
  static List<String> flattenWiktionary(List<WiktionaryDefinition> defs) {
    final flat = <String>[];
    for (final group in defs) {
      final prefix = group.partOfSpeech.isEmpty
          ? ''
          : '(${group.partOfSpeech}) ';
      for (final d in group.definitions) {
        flat.add('$prefix$d');
      }
    }
    return flat;
  }

  /// Auto word-card generation: CJK/dictionary languages go tokenize →
  /// Yomichan enrich; space-separated languages go Wiktionary REST.
  /// [excludeWords] filters already-known surfaces (the caller's card
  /// deck or the user's saved words).
  Future<List<AnalyzedWord>> generateWordCards(
    String text,
    String language, {
    String wiktionaryOverride = 'auto',
    Set<String> excludeWords = const {},
    int limit = 50,
  }) async {
    final generated = <AnalyzedWord>[];

    if (yomichanLanguages.contains(language)) {
      final surfaces = await uniqueSurfaces(
        text,
        limit: limit,
        exclude: excludeWords,
      );
      for (final surface in surfaces) {
        final enriched = await _yomichan.enrichWord(surface, language);
        if (enriched != null) generated.add(enriched);
      }
    } else {
      final words = text
          .split(RegExp(r'[\s,.;:!?]+'))
          .where((w) => w.length >= 2 && !excludeWords.contains(w))
          .toSet();
      for (final word in words) {
        final card = await enrichViaWiktionary(
          word,
          language,
          override: wiktionaryOverride,
        );
        if (card != null) generated.add(card);
      }
    }

    return generated;
  }
}
