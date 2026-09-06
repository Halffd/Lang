import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/anki_note_data.dart';
import 'package:lang/domain/entities/anki_note_types.dart';
import 'package:lang/domain/entities/yomitan_options.dart';
import 'dart:convert';

void main() {
  group('AnkiMarkerRenderer', () {
    final data = AnkiNoteData(
      expression: '読む',
      reading: 'よむ',
      cloze: ClozeData(
        sentence: '本を読む。',
        prefix: '本を',
        body: '読む',
        bodyKana: 'よむ',
        suffix: '。',
      ),
      glossary: ['to read', 'to study'],
      dictionary: 'JMdict (English)',
      frequencies: [
        FrequencyEntry('JPDB', '440'),
        FrequencyEntry('JMdict', '1200'),
      ],
      tags: ['v5', 'common'],
      partOfSpeech: 'Godan verb',
    );

    test('expression', () {
      expect(AnkiMarkerRenderer.renderMarker('expression', data), '読む');
    });

    test('reading', () {
      expect(AnkiMarkerRenderer.renderMarker('reading', data), 'よむ');
    });

    test('furigana-plain', () {
      expect(AnkiMarkerRenderer.renderMarker('furigana-plain', data), '読む[よむ]');
    });

    test('furigana ruby', () {
      expect(
        AnkiMarkerRenderer.renderMarker('furigana', data),
        '<ruby>読む<rt>よむ</rt></ruby>',
      );
    });

    test('glossary', () {
      final g = AnkiMarkerRenderer.renderMarker('glossary', data);
      expect(g, contains('JMdict'));
      expect(g, contains('to read'));
    });

    test('glossary-first', () {
      expect(
        AnkiMarkerRenderer.renderMarker('glossary-first', data),
        '(JMdict (English)) to read',
      );
    });

    test('glossary-no-dictionary', () {
      expect(
        AnkiMarkerRenderer.renderMarker('glossary-no-dictionary', data),
        'to read; to study',
      );
    });

    test('glossary-brief', () {
      expect(
        AnkiMarkerRenderer.renderMarker('glossary-brief', data),
        'to read | to study',
      );
    });

    test('sentence', () {
      expect(AnkiMarkerRenderer.renderMarker('sentence', data), '本を読む。');
    });

    test('cloze parts', () {
      expect(AnkiMarkerRenderer.renderMarker('cloze-prefix', data), '本を');
      expect(AnkiMarkerRenderer.renderMarker('cloze-body', data), '読む');
      expect(AnkiMarkerRenderer.renderMarker('cloze-suffix', data), '。');
      expect(AnkiMarkerRenderer.renderMarker('cloze-body-kana', data), 'よむ');
    });

    test('sentence-furigana-plain bolds term', () {
      expect(
        AnkiMarkerRenderer.renderMarker('sentence-furigana-plain', data),
        '本を<b>読む</b>。',
      );
    });

    test('frequencies', () {
      final f = AnkiMarkerRenderer.renderMarker('frequencies', data);
      expect(f, contains('JPDB'));
      expect(f, contains('440'));
      expect(f, contains('JMdict'));
    });

    test('frequency-harmonic-rank', () {
      // harmonic mean of 440, 1200 = 2/(1/440+1/1200) ≈ 644
      final r = AnkiMarkerRenderer.renderMarker(
        'frequency-harmonic-rank',
        data,
      );
      expect(int.parse(r), closeTo(644, 2));
    });

    test('frequency-average-rank', () {
      final r = AnkiMarkerRenderer.renderMarker('frequency-average-rank', data);
      expect(int.parse(r), 820);
    });

    test('frequency default when empty', () {
      final empty = AnkiNoteData(expression: 'x');
      expect(
        AnkiMarkerRenderer.renderMarker('frequency-harmonic-rank', empty),
        '9999999',
      );
      expect(
        AnkiMarkerRenderer.renderMarker('frequency-harmonic-occurrence', empty),
        '0',
      );
    });

    test('tags', () {
      expect(AnkiMarkerRenderer.renderMarker('tags', data), 'v5, common');
    });

    test('part-of-speech', () {
      expect(
        AnkiMarkerRenderer.renderMarker('part-of-speech', data),
        'Godan verb',
      );
    });

    test('dictionary', () {
      expect(
        AnkiMarkerRenderer.renderMarker('dictionary', data),
        'JMdict (English)',
      );
    });

    test('clipboard-text', () {
      final d = data;
      final withClip = AnkiNoteData(
        expression: d.expression,
        reading: d.reading,
        clipboardText: 'some context text',
      );
      expect(
        AnkiMarkerRenderer.renderMarker('clipboard-text', withClip),
        'some context text',
      );
      expect(AnkiMarkerRenderer.renderMarker('clipboard-text', d), '');
    });

    test('screenshot html', () {
      final d = AnkiNoteData(expression: 'x', screenshotPath: '/tmp/shot.png');
      expect(
        AnkiMarkerRenderer.renderMarker('screenshot', d),
        '<img src="/tmp/shot.png" />',
      );
    });

    test('audio sound tag', () {
      final d = AnkiNoteData(expression: 'x', audioPath: 'yomu.mp3');
      expect(AnkiMarkerRenderer.renderMarker('audio', d), '[sound:yomu.mp3]');
    });

    test('unknown marker preserved', () {
      expect(
        AnkiMarkerRenderer.renderMarker('nonexistent', data),
        '{nonexistent}',
      );
    });

    test('template with multiple markers', () {
      expect(
        AnkiMarkerRenderer.render('{expression} ({reading})', data),
        '読む (よむ)',
      );
    });

    test('containsMarker / markersIn', () {
      expect(AnkiMarkerRenderer.containsMarker('{expression} test'), true);
      expect(AnkiMarkerRenderer.markersIn('{expression} {reading}'), [
        'expression',
        'reading',
      ]);
    });
  });

  group('AnkiNoteTypes', () {
    test('defaults have all 4 types', () {
      final nt = AnkiNoteTypes.defaults();
      expect(nt.types.length, 4);
      expect(
        nt.types.map((t) => t.typeName),
        containsAll(['expression', 'reading', 'kanji', 'name']),
      );
    });

    test('expression fields match jp-mining-note layout', () {
      final e = DefaultNoteTypes.expression();
      final names = e.fields.map((f) => f.name).toList();
      for (final expected in [
        'Word',
        'WordReading',
        'PrimaryDefinition',
        'Sentence',
        'SentenceReading',
        'Picture',
        'WordAudio',
        'PAGraphs',
        'PAPositions',
        'SecondaryDefinition',
        'ExtraDefinitions',
        'Comment',
      ]) {
        expect(names, contains(expected));
      }
      expect(e.field('Word').value, '{expression}');
      expect(e.field('WordReading').value, '{furigana-plain}');
      expect(e.field('PrimaryDefinition').value, '{glossary-first}');
      expect(e.field('Sentence').value, '{sentence}');
      expect(e.field('Picture').value, '{screenshot}');
      expect(e.field('WordAudio').value, '{audio}');
    });

    test('kanji fields', () {
      final k = DefaultNoteTypes.kanji();
      expect(k.field('Word').value, '{character}');
      expect(k.field('Reading').value, contains('{onyomi}'));
    });

    test('serialize roundtrip', () {
      final nt = AnkiNoteTypes.defaults();
      final raw = nt.serialize();
      final back = AnkiNoteTypes.deserialize(raw);
      expect(back.types.length, nt.types.length);
      expect(
        back.byType(AnkiNoteType.expression).field('Word').value,
        '{expression}',
      );
    });

    test('deserialize null returns defaults', () {
      expect(AnkiNoteTypes.deserialize(null).types.length, 4);
      expect(AnkiNoteTypes.deserialize('garbage{').types.length, 4);
    });

    test('field edit persists through copy', () {
      final e = DefaultNoteTypes.expression().copy();
      e.fields.removeWhere((f) => f.name == 'Word');
      e.fields.insert(0, AnkiFieldConfig('Word', '{expression} v2'));
      final raw = jsonEncode(e.toJson());
      final back = AnkiNoteTypeConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(back.field('Word').value, '{expression} v2');
    });
  });

  group('YomitanOptions', () {
    test('defaults', () {
      final o = YomitanOptions();
      expect(o.profiles.length, 1);
      expect(o.activeProfile.name, 'Default');
      expect(o.activeProfile.general.enabled, true);
      expect(o.activeProfile.general.language, 'ja');
      expect(o.activeProfile.scanning.scanModifierKey, ScanModifierKey.shift);
      expect(o.activeProfile.anki.serverAddress, 'http://127.0.0.1:8765');
      expect(o.activeProfile.popupPosition.width, 400);
    });

    test('serialize roundtrip', () {
      final o = YomitanOptions();
      o.activeProfile.general.maximumNumberOfResults = 16;
      o.activeProfile.anki.tags = 'jp mined';
      o.activeProfile.appearance.fontSize = 18.5;
      o.addProfile('Study');
      o.setActiveProfile('Study');
      final raw = o.serialize();
      final back = YomitanOptions.deserialize(raw);
      expect(back.profiles.length, 2);
      expect(back.activeProfileIndex, 1);
      expect(back.profiles[0].general.maximumNumberOfResults, 16);
      expect(back.profiles[0].anki.tags, 'jp mined');
      expect(back.profiles[0].appearance.fontSize, 18.5);
    });

    test('profile management', () {
      final o = YomitanOptions();
      o.addProfile('Kanji');
      expect(o.profiles.length, 2);
      o.setActiveProfile('Kanji');
      expect(o.activeProfile.name, 'Kanji');
      o.removeProfile('Kanji');
      expect(o.profiles.length, 1);
      expect(o.activeProfile.name, 'Default');
      // cannot remove last
      o.removeProfile('Default');
      expect(o.profiles.length, 1);
    });

    test('deserialize null/invalid returns defaults', () {
      expect(YomitanOptions.deserialize(null).profiles.length, 1);
      expect(YomitanOptions.deserialize('bad{').profiles.length, 1);
    });

    test('enum coverage', () {
      // every settings section survives roundtrip with non-defaults
      final o = YomitanOptions();
      final p = o.activeProfile;
      p.general.language = 'zh';
      p.storage.frequencySortingMode = FrequencySortingMode.avg;
      p.scanning.scanDelay = 50;
      p.popupBehavior.maximumNumberOfChildPopups = 2;
      p.appearance.theme = ThemePreset.black;
      p.popupPosition.scale = 1.5;
      p.searchWindow.useNativeWindow = true;
      p.audio.volume = 0.8;
      p.textParsing.parseMecab = true;
      p.translation.searchResolutionFull = false;
      p.clipboard.searchMode = ClipboardSearchMode.append;
      p.accessibility.googleDocsCompatibilityMode = true;
      p.security.useSecurePopupFrameUrl = true;
      p.resultDisplay.resultGroupingMode = ResultGroupingMode.noGrouping;
      p.anki.duplicateScope = DuplicateScope.global;
      p.anki.duplicateAction = DuplicateAction.overwrite;
      p.anki.screenshotFormat = ScreenshotFormat.png;

      final back = YomitanOptions.deserialize(o.serialize());
      final b = back.activeProfile;
      expect(b.general.language, 'zh');
      expect(b.storage.frequencySortingMode, FrequencySortingMode.avg);
      expect(b.scanning.scanDelay, 50);
      expect(b.popupBehavior.maximumNumberOfChildPopups, 2);
      expect(b.appearance.theme, ThemePreset.black);
      expect(b.popupPosition.scale, 1.5);
      expect(b.searchWindow.useNativeWindow, true);
      expect(b.audio.volume, 0.8);
      expect(b.textParsing.parseMecab, true);
      expect(b.translation.searchResolutionFull, false);
      expect(b.clipboard.searchMode, ClipboardSearchMode.append);
      expect(b.accessibility.googleDocsCompatibilityMode, true);
      expect(b.security.useSecurePopupFrameUrl, true);
      expect(b.resultDisplay.resultGroupingMode, ResultGroupingMode.noGrouping);
      expect(b.anki.duplicateScope, DuplicateScope.global);
      expect(b.anki.duplicateAction, DuplicateAction.overwrite);
      expect(b.anki.screenshotFormat, ScreenshotFormat.png);
    });
  });
}
