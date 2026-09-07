import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/anki_note_data.dart';
import 'package:lang/domain/entities/anki_note_types.dart';
import 'package:lang/domain/entities/analyzed_word.dart';

void main() {
  group('AnkiNoteData.fromAnalyzedWord', () {
    final word = AnalyzedWord(
      word: '読む',
      reading: 'よむ',
      frequency: 1200,
      sentence: '本を読む。',
      ichiMoeDefinitions: ['to read'],
      kanjiList: [],
    );

    test('builds note data with cloze from sentence', () {
      final d = AnkiNoteData.fromAnalyzedWord(word);
      expect(d.expression, '読む');
      expect(d.reading, 'よむ');
      expect(d.cloze?.sentence, '本を読む。');
      expect(d.cloze?.prefix, '本を');
      expect(d.cloze?.body, '読む');
      expect(d.cloze?.suffix, '。');
      expect(d.glossary, contains('to read'));
      expect(d.frequencies.single.frequency, '1200');
      expect(d.type, NoteDataType.term);
    });

    test('hint and clipboard inputs', () {
      final d = AnkiNoteData.fromAnalyzedWord(
        word,
        hint: 'my note',
        clipboardText: 'context text',
      );
      expect(d.hint, 'my note');
      expect(d.clipboardText, 'context text');
      expect(AnkiMarkerRenderer.renderMarker('hint', d), 'my note');
      expect(
        AnkiMarkerRenderer.renderMarker('clipboard-text', d),
        'context text',
      );
    });

    test('single kanji detected as kanji type', () {
      final kanjiWord = AnalyzedWord(
        word: '読',
        kanjiList: ['読'],
        kanjiDetails: {'strokes': 13},
      );
      final d = AnkiNoteData.fromAnalyzedWord(kanjiWord);
      expect(d.type, NoteDataType.kanji);
      expect(d.character, '読');
      expect(d.strokeCount, 13);
      expect(AnkiMarkerRenderer.renderMarker('character', d), '読');
      expect(AnkiMarkerRenderer.renderMarker('stroke-count', d), '13');
    });

    test('multi-char word not kanji type', () {
      final d = AnkiNoteData.fromAnalyzedWord(word);
      expect(d.type, NoteDataType.term);
      expect(d.character, isNull);
    });
  });

  group('marker rendering with custom handlebars templates', () {
    final word = AnalyzedWord(
      word: '読む',
      reading: 'よむ',
      frequency: 800,
      sentence: '本を読む。',
      ichiMoeDefinitions: ['to read'],
    );

    test('custom glossary template overrides builtin', () {
      final data = AnkiNoteData.fromAnalyzedWord(word);
      final result = AnkiMarkerRenderer.render(
        '{glossary}',
        data,
        markerTemplates: {
          'glossary':
              '{{#each definition.definitions}}({{dictionary}}): {{#each glossary}}{{.}}{{#unless @last}}, {{/unless}}{{/each}}{{#unless @last}}; {{/unless}}{{/each}}',
        },
      );
      expect(result, contains('(IchiMoe): to read'));
    });

    test('custom frequency template', () {
      final data = AnkiNoteData.fromAnalyzedWord(word, extraTags: []);
      final result = AnkiMarkerRenderer.render(
        '{frequencies}',
        data,
        markerTemplates: {
          'frequencies':
              '{{#each frequencies}}[{{dictionary}}={{frequency}}]{{/each}}',
        },
      );
      expect(result, contains('[local='));
    });

    test('custom sentence-furigana template with cloze', () {
      final data = AnkiNoteData.fromAnalyzedWord(word);
      final result = AnkiMarkerRenderer.render(
        '{sentence}',
        data,
        markerTemplates: {
          'sentence':
              '{{#if definition.cloze}}{{definition.cloze.sentence}}{{/if}}',
        },
      );
      expect(result, '本を読む。');
    });

    test('hasMedia/getMedia helpers in templates', () {
      final data = AnkiNoteData.fromAnalyzedWord(
        word,
        clipboardText: 'clipped',
      );
      final result = AnkiMarkerRenderer.render(
        '{clipboard-text}',
        data,
        markerTemplates: {
          'clipboard-text':
              '{{#if (hasMedia "clipboardText")}}CTX: {{{getMedia "clipboardText"}}}{{/if}}',
        },
      );
      expect(result, 'CTX: clipped');
    });

    test('empty template falls back to builtin', () {
      final data = AnkiNoteData.fromAnalyzedWord(word);
      final result = AnkiMarkerRenderer.render(
        '{expression}',
        data,
        markerTemplates: {'expression': ''},
      );
      expect(result, '読む');
    });

    test('broken template renders empty, not crash', () {
      final data = AnkiNoteData.fromAnalyzedWord(word);
      final result = AnkiMarkerRenderer.render(
        '{glossary}',
        data,
        markerTemplates: {'glossary': '{{#each definitionz }'},
      );
      expect(result, isNotNull);
    });
  });

  group('note type field end-to-end build', () {
    final word = AnalyzedWord(
      word: '読む',
      reading: 'よむ',
      frequency: 800,
      sentence: '本を読む。',
      ichiMoeDefinitions: ['to read', 'to study'],
    );

    test('expression note type builds jp-mining-note fields', () {
      final data = AnkiNoteData.fromAnalyzedWord(
        word,
        hint: 'watch out',
        extraTags: ['v5'],
      );
      final config = DefaultNoteTypes.expression();
      final fields = <String, String>{
        for (final f in config.fields)
          if (f.name.isNotEmpty)
            f.name: AnkiMarkerRenderer.render(f.value, data),
      };

      expect(fields['Word'], '読む');
      expect(fields['WordReading'], '読む[よむ]');
      expect(fields['PrimaryDefinition'], '(IchiMoe) to read');
      expect(fields['Sentence'], '本を読む。');
      expect(fields['SentenceReading'], '本を<b>読む</b>。');
      expect(fields['Hint'], 'watch out');
      expect(fields['FrequenciesStylized'], contains('800'));
      expect(fields['WordReadingHiragana'], 'よむ');
      expect(fields['AJTWordPitch'], ''); // no pitch data
      expect(fields['Comment'], ''); // no clipboard
    });

    test('kanji note type builds fields', () {
      final word = AnalyzedWord(
        word: '読',
        kanjiList: ['読'],
        kanjiDetails: {'strokes': 13},
      );
      final data = AnkiNoteData.fromAnalyzedWord(word);
      final config = DefaultNoteTypes.kanji();
      final fields = <String, String>{
        for (final f in config.fields)
          if (f.name.isNotEmpty)
            f.name: AnkiMarkerRenderer.render(f.value, data),
      };
      expect(fields['Word'], '読');
      // no on/kun data: renders empty (not kept as marker text)
      expect(fields['Reading'], ', ');
      expect(fields['Glossary'], isNotNull);
    });
  });

  group('AnkiNoteTypes markerTemplates serialization', () {
    test('roundtrip with custom templates', () {
      final nt = AnkiNoteTypes.defaults();
      nt.markerTemplates['glossary'] =
          '{{#each definition.definitions}}{{dictionary}}{{/each}}';
      final back = AnkiNoteTypes.deserialize(nt.serialize());
      expect(
        back.markerTemplates['glossary'],
        '{{#each definition.definitions}}{{dictionary}}{{/each}}',
      );
      expect(back.markerTemplates.length, 1);
    });

    test('empty templates persist as empty', () {
      final nt = AnkiNoteTypes.defaults();
      final back = AnkiNoteTypes.deserialize(nt.serialize());
      expect(back.markerTemplates, isEmpty);
    });
  });
}
