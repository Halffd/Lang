import 'dart:convert';

/// Field marker context and renderer for Anki note building.
///
/// Mirrors Yomitan's anki-note-data-creator.js: a [AnkiNoteData]
/// holds all information about the term being exported, and
/// [AnkiMarkerRenderer] replaces {marker} strings in field templates
/// with values from the data.

// ============================================================
// Note data
// ============================================================

class ClozeData {
  final String sentence;
  final String prefix;
  final String body;
  final String bodyKana;
  final String suffix;

  ClozeData({
    required this.sentence,
    required this.prefix,
    required this.body,
    required this.bodyKana,
    required this.suffix,
  });
}

class FrequencyEntry {
  final String dictionary;
  final String frequency;

  FrequencyEntry(this.dictionary, this.frequency);
}

class PitchAccent {
  final List<String> positions;
  final String? reading;

  PitchAccent(this.positions, {this.reading});
}

enum NoteDataType { term, termGrouped, termMerged, kanji }

/// Everything the markers need about the term being exported.
class AnkiNoteData {
  final String expression;
  final String? reading;
  final String language;

  final ClozeData? cloze;
  final List<String> glossary;
  final List<String> glossaryBrief;
  final String dictionary;
  final String? dictionaryAlias;

  final List<FrequencyEntry> frequencies;
  final List<PitchAccent> pitchAccents;

  final List<String> tags;
  final String? partOfSpeech;
  final String? conjugation;

  // kanji specific
  final String? character;
  final List<String>? onyomi;
  final List<String>? kunyomi;
  final int? strokeCount;

  // media
  final String? audioPath;
  final String? audioSentencePath;
  final String? screenshotPath;
  final String? clipboardText;
  final String? clipboardImagePath;
  final String? selectionText;

  // context
  final String? documentTitle;
  final String? url;
  final String? searchQuery;

  final NoteDataType type;
  final List<AnalyzedDefGroup>? definitionGroups;

  AnkiNoteData({
    required this.expression,
    this.reading,
    this.language = 'ja',
    this.cloze,
    this.glossary = const [],
    this.glossaryBrief = const [],
    this.dictionary = '',
    this.dictionaryAlias,
    this.frequencies = const [],
    this.pitchAccents = const [],
    this.tags = const [],
    this.partOfSpeech,
    this.conjugation,
    this.character,
    this.onyomi,
    this.kunyomi,
    this.strokeCount,
    this.audioPath,
    this.audioSentencePath,
    this.screenshotPath,
    this.clipboardText,
    this.clipboardImagePath,
    this.selectionText,
    this.documentTitle,
    this.url,
    this.searchQuery,
    this.type = NoteDataType.term,
    this.definitionGroups,
  });
}

/// One dictionary's definitions group (for termGrouped/termMerged).
class AnalyzedDefGroup {
  final String dictionary;
  final List<String> glossary;
  final List<String> definitionTags;

  AnalyzedDefGroup(this.dictionary, this.glossary,
      {this.definitionTags = const []});
}

// ============================================================
// Marker renderer
// ============================================================

class AnkiMarkerRenderer {
  static final RegExp _markerPattern =
      RegExp(r'\{([\p{Letter}\p{Number}_-]+)\}', unicode: true);

  /// All markers that can appear in field templates.
  static const List<String> termMarkers = [
    'audio', 'cloze-body-kana', 'conjugation', 'expression', 'furigana',
    'furigana-plain', 'glossary', 'glossary-brief', 'glossary-no-dictionary',
    'glossary-first', 'glossary-plain', 'glossary-plain-no-dictionary',
    'glossary-first-brief', 'glossary-first-no-dictionary', 'part-of-speech',
    'phonetic-transcriptions', 'pitch-accents', 'pitch-accent-graphs',
    'pitch-accent-graphs-jj', 'pitch-accent-positions',
    'pitch-accent-categories', 'reading', 'tags',
    'sentence-audio', 'hint', 'cloze-body', 'cloze-prefix', 'cloze-suffix',
    'frequency-harmonic-rank', 'frequency-harmonic-occurrence',
    'frequency-average-rank', 'frequency-average-occurrence',
    'secondary-definition', 'extra-definitions',
  ];

  static const List<String> kanjiMarkers = [
    'character', 'glossary', 'kunyomi', 'onyomi', 'onyomi-hiragana',
    'stroke-count',
  ];

  static const List<String> bothMarkers = [
    'clipboard-image', 'clipboard-text', 'cloze-body', 'cloze-prefix',
    'cloze-suffix', 'dictionary', 'dictionary-alias', 'document-title',
    'frequencies', 'screenshot', 'search-query', 'popup-selection-text',
    'sentence', 'sentence-furigana', 'sentence-furigana-plain', 'url',
    'url-plain',
  ];

  static const List<String> allMarkers = [...termMarkers, ...kanjiMarkers, ...bothMarkers];

  /// True when [text] contains any marker.
  static bool containsMarker(String text) => _markerPattern.hasMatch(text);

  /// All markers contained in [text].
  static List<String> markersIn(String text) =>
      _markerPattern.allMatches(text).map((m) => m.group(1)!).toList();

  /// Replace every {marker} in [template] using [data].
  static String render(String template, AnkiNoteData data) {
    return template.replaceAllMapped(_markerPattern, (m) {
      final marker = m.group(1)!;
      return renderMarker(marker, data);
    });
  }

  /// Render a single [marker] from [data]. Unknown markers render as
  /// the original text (so user typos survive roundtrips).
  static String renderMarker(String marker, AnkiNoteData data) {
    switch (marker) {
      // ---- term ----
      case 'expression':
        return data.expression;
      case 'reading':
        return data.reading ?? '';
      case 'audio':
        return data.audioPath != null ? '[sound:${data.audioPath}]' : '';
      case 'sentence-audio':
        return data.audioSentencePath != null
            ? '[sound:${data.audioSentencePath}]'
            : '';
      case 'hint':
        return '';

      // ---- cloze / sentence ----
      case 'sentence':
        return data.cloze?.sentence ?? '';
      case 'cloze-prefix':
        return data.cloze?.prefix ?? '';
      case 'cloze-body':
        return data.cloze?.body ?? '';
      case 'cloze-suffix':
        return data.cloze?.suffix ?? '';
      case 'cloze-body-kana':
        return data.cloze?.bodyKana ?? data.cloze?.body ?? '';

      // ---- glossary family ----
      case 'glossary':
        return _glossary(data, brief: false, noDict: false);
      case 'glossary-brief':
        return _glossary(data, brief: true, noDict: false);
      case 'glossary-no-dictionary':
        return _glossary(data, brief: false, noDict: true);
      case 'glossary-first':
        return _glossaryFirst(data, brief: false, noDict: false);
      case 'glossary-first-brief':
        return _glossaryFirst(data, brief: true, noDict: false);
      case 'glossary-first-no-dictionary':
        return _glossaryFirst(data, brief: false, noDict: true);
      case 'glossary-plain':
        return _glossaryPlain(data, noDict: false);
      case 'glossary-plain-no-dictionary':
        return _glossaryPlain(data, noDict: true);
      case 'secondary-definition':
        return _glossary(data, brief: false, noDict: true, skipFirstDict: true);
      case 'extra-definitions':
        return _glossary(data, brief: false, noDict: false, skipFirstDict: true);

      // ---- furigana ----
      case 'furigana':
        return _furigana(data, plain: false);
      case 'furigana-plain':
        return _furigana(data, plain: true);
      case 'sentence-furigana':
        return _sentenceFurigana(data, plain: false);
      case 'sentence-furigana-plain':
        return _sentenceFurigana(data, plain: true);

      // ---- frequencies ----
      case 'frequencies':
        return _frequencies(data);
      case 'frequency-harmonic-rank':
        return _freqAgg(data, harmonic: true, occurrence: false);
      case 'frequency-harmonic-occurrence':
        return _freqAgg(data, harmonic: true, occurrence: true);
      case 'frequency-average-rank':
        return _freqAgg(data, harmonic: false, occurrence: false);
      case 'frequency-average-occurrence':
        return _freqAgg(data, harmonic: false, occurrence: true);

      // ---- pitch accent ----
      case 'pitch-accents':
        return _pitchAccents(data, format: 'text');
      case 'pitch-accent-graphs':
        return _pitchAccents(data, format: 'graph');
      case 'pitch-accent-graphs-jj':
        return _pitchAccents(data, format: 'graph-jj');
      case 'pitch-accent-positions':
        return _pitchAccents(data, format: 'position');
      case 'pitch-accent-categories':
        return _pitchCategories(data);
      case 'phonetic-transcriptions':
        return _phoneticTranscriptions(data);

      // ---- tags / pos ----
      case 'tags':
        return data.tags.join(', ');
      case 'part-of-speech':
        return data.partOfSpeech ?? 'Unknown';
      case 'conjugation':
        return data.conjugation ?? '';

      // ---- kanji ----
      case 'character':
        return data.character ?? data.expression;
      case 'onyomi':
        return (data.onyomi ?? const []).join(', ');
      case 'kunyomi':
        return (data.kunyomi ?? const []).join(', ');
      case 'onyomi-hiragana':
        return (data.onyomi ?? const []).join(', ');
      case 'stroke-count':
        return data.strokeCount?.toString() ?? 'Unknown';

      // ---- dictionary ----
      case 'dictionary':
        return data.dictionary;
      case 'dictionary-alias':
        return data.dictionaryAlias ?? data.dictionary;

      // ---- media / context ----
      case 'clipboard-image':
        return data.clipboardImagePath != null
            ? '<img src="${data.clipboardImagePath}" />'
            : '';
      case 'clipboard-text':
        return data.clipboardText ?? '';
      case 'screenshot':
        return data.screenshotPath != null
            ? '<img src="${data.screenshotPath}" />'
            : '';
      case 'document-title':
        return data.documentTitle ?? '';
      case 'url':
        return data.url != null ? '<a href="${data.url}">${data.url}</a>' : '';
      case 'url-plain':
        return data.url ?? '';
      case 'search-query':
        return data.searchQuery ?? '';
      case 'popup-selection-text':
        return data.selectionText ?? '';

      default:
        // unknown marker: keep as-is
        return '{$marker}';
    }
  }

  // ------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------

  static String _glossary(AnkiNoteData data,
      {required bool brief, required bool noDict, bool skipFirstDict = false}) {
    final groups = data.definitionGroups;
    if (groups != null && groups.isNotEmpty) {
      final out = StringBuffer();
      if (!brief) out.write('<ol>');
      var primary = groups.first.dictionary;
      for (final g in groups) {
        if (skipFirstDict && g.dictionary == primary) continue;
        if (!brief) out.write('<li>');
        if (!noDict && !brief) out.write('(${g.dictionary}) ');
        out.write(brief
            ? g.glossary.join(' | ')
            : g.glossary.map((x) => x).join(brief ? ' | ' : '; '));
        if (!brief) out.write('</li>');
      }
      if (!brief) out.write('</ol>');
      return out.toString();
    }

    if (data.glossary.isEmpty) return '';
    if (brief) return data.glossary.join(' | ');
    if (noDict) return data.glossary.join('; ');
    final dict = data.dictionary.isEmpty ? '' : '(${data.dictionary}) ';
    return '$dict${data.glossary.join('; ')}';
  }

  static String _glossaryFirst(AnkiNoteData data,
      {required bool brief, required bool noDict}) {
    final groups = data.definitionGroups;
    if (groups != null && groups.isNotEmpty) {
      final g = groups.first;
      if (!noDict) return '(${g.dictionary}) ${g.glossary.first}';
      return g.glossary.first;
    }
    if (data.glossary.isEmpty) return '';
    final first = data.glossary.first;
    if (noDict || data.dictionary.isEmpty) return first;
    return '(${data.dictionary}) $first';
  }

  static String _glossaryPlain(AnkiNoteData data, {required bool noDict}) {
    final groups = data.definitionGroups;
    if (groups != null && groups.isNotEmpty) {
      final out = StringBuffer();
      for (final g in groups) {
        if (!noDict) out.write('(${g.dictionary})<br>');
        out.write(g.glossary.join('<br>'));
        out.write('<br>');
      }
      return out.toString();
    }
    final dict = (noDict || data.dictionary.isEmpty) ? '' : '(${data.dictionary})<br>';
    return '$dict${data.glossary.join('<br>')}';
  }

  static String _furigana(AnkiNoteData data, {required bool plain}) {
    final expr = data.expression;
    final reading = data.reading;
    if (reading == null || reading == expr) return expr;
    if (plain) return '$expr[$reading]';
    // ruby approximation: group kanji runs with reading spans
    return '<ruby>$expr<rt>$reading</rt></ruby>';
  }

  static String _sentenceFurigana(AnkiNoteData data, {required bool plain}) {
    final sentence = data.cloze?.sentence ?? '';
    if (sentence.isEmpty) return '';
    final body = data.cloze?.body ?? data.expression;
    final bolded = '<b>$body</b>';
    final s = sentence.replaceFirst(body, bolded);
    return plain ? s : s;
  }

  static String _frequencies(AnkiNoteData data) {
    if (data.frequencies.isEmpty) return '';
    final out = StringBuffer('<ul>');
    for (final f in data.frequencies) {
      out.write('<li>${f.dictionary}: ${f.frequency}</li>');
    }
    out.write('</ul>');
    return out.toString();
  }

  static int _parseFreqInt(String freq) {
    final m = RegExp(r'\d+').firstMatch(freq);
    return m != null ? int.parse(m.group(0)!) : 0;
  }

  static String _freqAgg(AnkiNoteData data,
      {required bool harmonic, required bool occurrence}) {
    if (data.frequencies.isEmpty) {
      return occurrence ? '0' : '9999999';
    }
    final values =
        data.frequencies.map((f) => _parseFreqInt(f.frequency)).toList();
    values.removeWhere((v) => v <= 0);
    if (values.isEmpty) return occurrence ? '0' : '9999999';

    int result;
    if (harmonic) {
      final sumInv = values.map((v) => 1 / v).reduce((a, b) => a + b);
      final h = values.length / sumInv;
      result = h.round();
    } else {
      result = (values.reduce((a, b) => a + b) / values.length).round();
    }
    return result.toString();
  }

  static String _pitchAccents(AnkiNoteData data, {required String format}) {
    if (data.pitchAccents.isEmpty) return '';
    final out = StringBuffer();
    if (format == 'text') {
      for (final pa in data.pitchAccents) {
        out.write('${pa.positions.join('、')} ');
      }
    } else if (format == 'position') {
      for (final pa in data.pitchAccents) {
        out.write('(${pa.positions.join(', ')}) ');
      }
    } else {
      // graph / graph-jj: simplified text representation
      for (final pa in data.pitchAccents) {
        out.write('[${pa.positions.join('][')}] ');
      }
    }
    return out.toString().trim();
  }

  static String _pitchCategories(AnkiNoteData data) {
    if (data.pitchAccents.isEmpty) return '';
    final cats = <String>{};
    for (final pa in data.pitchAccents) {
      for (final p in pa.positions) {
        final n = int.tryParse(p);
        if (n == null) continue;
        if (n == 0) {
          cats.add('heiban');
        } else if (n == 1) {
          cats.add('atamadaka');
        } else {
          cats.add(n == data.expression.runes.length ? 'odaka' : 'nakadaka');
        }
      }
    }
    return cats.join(', ');
  }

  static String _phoneticTranscriptions(AnkiNoteData data) {
    // IPA transcriptions not yet sourced from dictionaries
    return '';
  }

  /// Build [cloze] data from a [sentence] and the [term] (with
  /// optional [termKana]) appearing in it.
  static ClozeData buildCloze(String sentence, String term,
      {String? termKana}) {
    final idx = sentence.indexOf(term);
    if (idx < 0) {
      return ClozeData(
        sentence: sentence,
        prefix: '',
        body: term,
        bodyKana: termKana ?? term,
        suffix: '',
      );
    }
    return ClozeData(
      sentence: sentence,
      prefix: sentence.substring(0, idx),
      body: term,
      bodyKana: termKana ?? term,
      suffix: sentence.substring(idx + term.length),
    );
  }
}