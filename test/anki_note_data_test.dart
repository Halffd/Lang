// AnkiNoteData.fromAnalyzedWord: core export logic test.
// Pure data transformation from AnalyzedWord to AnkiNoteData.

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/anki_note_data.dart';
import 'package:lang/domain/entities/anki_note_types.dart';

void main() {
  group('AnkiNoteData.fromAnalyzedWord', () {
    late AnalyzedWord word;

    setUp(() {
      word = AnalyzedWord(
        word: '読む',
        reading: 'よむ',
        frequency: 100,
        sentence: '本を読む',
        ichiMoeDefinitions: ['to read', 'to study'],
        kanjiList: ['読'],
        kanjiDetails: {
          'readings': [
            {'onyomi': 'トク', 'kunyomi': 'よ.む', 'strokes': 14},
          ],
        },
        kanjipediaData: {
          'readings': {'onyomi': 'トク', 'kunyomi': 'よ.む', 'strokes': '14'},
        },
        localDefinitions: [
          {
            'glossary': ['to read', 'to study'],
          },
        ],
        mdbgData: null,
        nestedEntries: [],
        sourceDictionary: 'test',
      );
    });

    test('basic term and reading', () {
      final note = AnkiNoteData.fromAnalyzedWord(word);
      expect(note.expression, '読む');
      expect(note.reading, 'よむ');
      expect(note.language, 'ja');
    });

    test('cloze built from sentence', () {
      final note = AnkiNoteData.fromAnalyzedWord(word);
      expect(note.cloze, isNotNull);
      expect(note.cloze!.sentence, '本を読む');
      expect(note.cloze!.body, '読む');
    });

    test('glossary combines multiple sources', () {
      final note = AnkiNoteData.fromAnalyzedWord(word);
      // ichiMoe + localDefinitions glossary
      expect(note.glossary, isNotEmpty);
      expect(note.glossary, contains('to read'));
      expect(note.glossary, contains('to study'));
    });

    test('kanji type detected for single kanji', () {
      final kanjiWord = AnalyzedWord(
        word: '読',
        reading: 'よみ',
        frequency: 50,
        sentence: '読む',
        ichiMoeDefinitions: ['to read'],
        kanjiList: ['読'],
        kanjiDetails: {
          'readings': [
            {'onyomi': 'トク', 'kunyomi': 'よ.む'},
          ],
        },
        kanjipediaData: {
          'readings': {'onyomi': 'トク', 'kunyomi': 'よ.む'},
        },
        localDefinitions: [],
        mdbgData: null,
        nestedEntries: [],
        sourceDictionary: 'test',
      );

      final note = AnkiNoteData.fromAnalyzedWord(kanjiWord);
      expect(note.type, NoteDataType.kanji);
      expect(note.character, '読');
      expect(note.onyomi, contains('トク'));
      expect(note.kunyomi, contains('よ.む'));
    });

    test('cloze bodyKana uses reading', () {
      final note = AnkiNoteData.fromAnalyzedWord(word);
      expect(note.cloze!.bodyKana, 'よむ');
    });

    test('glossaryBrief defaults to empty list', () {
      final note = AnkiNoteData.fromAnalyzedWord(word);
      final map = note.toTemplateMap();
      expect(map['glossaryBrief'], isA<List<String>>());
      expect(map['glossaryBrief'], isEmpty);
    });

    test('extraTags merged into tags', () {
      final note = AnkiNoteData.fromAnalyzedWord(
        word,
        extraTags: ['custom-tag'],
      );
      expect(note.tags, contains('custom-tag'));
    });

    test('hint and clipboard text stored', () {
      final note = AnkiNoteData.fromAnalyzedWord(
        word,
        hint: 'my hint',
        clipboardText: 'clipboard content',
      );
      expect(note.hint, 'my hint');
      expect(note.clipboardText, 'clipboard content');
    });

    test('cloze is null when no sentence', () {
      final noSentence = AnalyzedWord(
        word: '読む',
        reading: 'よむ',
        ichiMoeDefinitions: ['to read'],
        kanjiList: ['読'],
        kanjiDetails: {},
        kanjipediaData: {},
        localDefinitions: [],
        nestedEntries: [],
      );
      final note = AnkiNoteData.fromAnalyzedWord(noSentence);
      expect(note.cloze, isNull);
    });
  });
}
