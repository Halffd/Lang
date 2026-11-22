import 'package:lang/data/services/dictionary/tokenizer_service.dart';

/// Builds the reading of a whole scanned term from the readings of
/// its parts.
///
/// The popup dictionary looks a word up as the longest dictionary
/// entry that matches the scanned text. For a compound that has no
/// dictionary entry of its own, the lookup falls back to a shorter
/// prefix — so the reading shown would be that prefix's reading
/// ("にほんご" for 日本語学校) rather than the compound's reading
/// ("にほんごがっこう"). This rebuilds the reading from the parts, so
/// the popup shows the reading of the text the user actually
/// selected.
///
/// Returns null when the parts cannot be resolved (no reading for one
/// of them, or the segmentation does not cover the whole term), so
/// the caller can keep the dictionary's own reading.
class CompoundReading {
  const CompoundReading._();

  /// The reading of [term], built from the readings of its parts.
  ///
  /// [tokenizer] is injectable for tests.
  static Future<String?> build(
    String term, {
    TokenizerService? tokenizer,
  }) async {
    if (term.isEmpty) return null;
    final service = tokenizer ?? TokenizerService();
    final tokens = await service.tokenize(term);
    if (tokens.isEmpty) return null;

    final readings = <String>[];
    var covered = 0;
    for (final token in tokens) {
      // punctuation and whitespace carry no reading
      if (token.partOfSpeech == 'punctuation') {
        covered = token.endIndex;
        continue;
      }
      final reading = token.reading.trim();
      if (reading.isEmpty) {
        // an unmatched character: the compound's reading cannot be
        // built reliably
        return null;
      }
      readings.add(reading);
      covered = token.endIndex;
    }
    // the segmentation must account for the whole term, otherwise the
    // reading describes only part of it
    if (covered < term.length) return null;
    if (readings.isEmpty) return null;
    return readings.join();
  }
}
