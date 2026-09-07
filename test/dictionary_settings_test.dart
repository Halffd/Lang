import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/dictionary_settings.dart';
import 'package:lang/domain/entities/yomitan_options.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/utils/recursive_lookup.dart';

void main() {
  group('DictionarySettings conditions', () {
    test('defaults match everything', () {
      final s = DictionarySettings();
      expect(s.enabled, true);
      expect(s.hasNoConditions, true);
      expect(
        s.matches(term: 'anything', reading: 'x', lookupLanguage: 'ko'),
        true,
      );
    });

    test('language condition', () {
      final s = DictionarySettings()..languages = ['ja'];
      expect(s.hasNoConditions, false);
      expect(s.matches(term: '読む', lookupLanguage: 'ja'), true);
      expect(s.matches(term: '読む', lookupLanguage: 'zh'), false);
      expect(s.matches(term: '読む', lookupLanguage: null), false);
    });

    test('reading patterns exact and wildcard', () {
      final s = DictionarySettings()..readingPatterns = ['よむ', 'た*'];
      expect(s.matches(term: 'x', reading: 'よむ'), true);
      expect(s.matches(term: 'x', reading: 'たべる'), true);
      expect(s.matches(term: 'x', reading: 'みる'), false);
      expect(s.matches(term: 'x', reading: null), false);
    });

    test('term regex condition', () {
      final s = DictionarySettings()..termRegex = r'^[\u3040-\u309F]+$';
      expect(s.matches(term: 'よむ'), true);
      expect(s.matches(term: '読む'), false);
    });

    test('invalid regex never blocks', () {
      final s = DictionarySettings()..termRegex = '[unclosed';
      expect(s.matches(term: 'anything'), true);
    });

    test('part-of-speech tags case-insensitive', () {
      final s = DictionarySettings()..partOfSpeechTags = ['noun', 'v5'];
      expect(s.matches(term: 'x', tags: ['Noun', 'common']), true);
      expect(s.matches(term: 'x', tags: ['verb']), false);
      expect(s.matches(term: 'x', tags: []), false);
    });

    test('multiple conditions must all match', () {
      final s = DictionarySettings()
        ..languages = ['ja']
        ..partOfSpeechTags = ['noun'];
      expect(s.matches(term: 'x', lookupLanguage: 'ja', tags: ['noun']), true);
      expect(s.matches(term: 'x', lookupLanguage: 'ja', tags: ['verb']), false);
      expect(s.matches(term: 'x', lookupLanguage: 'en', tags: ['noun']), false);
    });

    test('serialize roundtrip', () {
      final s = DictionarySettings()
        ..priority = 5
        ..enabled = false
        ..languages = ['ja', 'zh']
        ..readingPatterns = ['よ*']
        ..termRegex = '^x'
        ..partOfSpeechTags = ['noun'];
      final back = DictionarySettings.deserialize(s.toJson());
      expect(back.priority, 5);
      expect(back.enabled, false);
      expect(back.languages, ['ja', 'zh']);
      expect(back.readingPatterns, ['よ*']);
      expect(back.termRegex, '^x');
      expect(back.partOfSpeechTags, ['noun']);
    });
  });

  group('ProfileDictionarySettings', () {
    test('sortedByPriority orders enabled first then priority', () {
      final p = ProfileDictionarySettings();
      p.forDictionary('a').priority = 10;
      p.forDictionary('b').priority = 1;
      p.forDictionary('c').priority = 5;
      p.forDictionary('d').priority = 0;
      p.forDictionary('disabled').priority = 0;
      p.forDictionary('disabled').enabled = false;

      final sorted = p.sortedByPriority({'a', 'b', 'c', 'd', 'disabled'});
      expect(sorted, ['d', 'b', 'c', 'a', 'disabled']);
    });

    test('sortResults by source priority', () {
      final p = ProfileDictionarySettings();
      p.forDictionary('dictA').priority = 2;
      p.forDictionary('dictB').priority = 1;

      final results = ['dictA-r1', 'dictB-r1', 'dictA-r2', 'dictB-r2'];
      final sorted = p.sortResults(results, (r) => r.split('-').first);
      expect(sorted, ['dictB-r1', 'dictB-r2', 'dictA-r1', 'dictA-r2']);
    });

    test('profile roundtrip keeps dictionary settings', () {
      final profile = YomitanProfile('Test');
      profile.dictionarySettings.forDictionary('JMdict').priority = 3;
      profile.dictionarySettings.forDictionary('JMdict').languages = ['ja'];
      profile.dictionarySettings.forDictionary('KireiCake').enabled = false;

      final raw = profile.toJson();
      final restored = YomitanProfile.fromJson(raw);
      final jm = restored.dictionarySettings.forDictionary('JMdict');
      expect(jm.priority, 3);
      expect(jm.languages, ['ja']);
      expect(
        restored.dictionarySettings.forDictionary('KireiCake').enabled,
        false,
      );
    });

    test('YomitanOptions roundtrip with profiles keeps dict settings', () {
      final o = YomitanOptions();
      o.activeProfile.dictionarySettings.forDictionary('X').priority = 7;
      final back = YomitanOptions.deserialize(o.serialize());
      expect(
        back.activeProfile.dictionarySettings.forDictionary('X').priority,
        7,
      );
    });
  });

  group('RecursiveLookup', () {
    DictionaryEntry entry(String term, List<String> defs) => DictionaryEntry(
      dictionaryId: 1,
      term: term,
      reading: '',
      definitions: defs,
      popularity: 0,
    );

    test('extractSubTerms finds CJK runs and latin words', () {
      final e = entry('word', ['日本語を勉強する studying language']);
      final terms = RecursiveLookup.extractSubTerms(e);
      // CJK runs are captured whole (lookup resolves them)
      expect(terms, contains('日本語を勉強する'));
      expect(terms, contains('studying'));
      expect(terms, contains('language'));
    });

    test('extractSubTerms skips the entry term itself', () {
      final e = entry('word', ['word appears in its own definition']);
      final terms = RecursiveLookup.extractSubTerms(e);
      expect(terms, isNot(contains('word')));
    });

    test('extractSubTerms flattens structured content', () {
      final structured =
          '[{"tag":"span","content":"日本語の"},{"tag":"ruby","content":["漢",{"tag":"rt","content":"かん"}]}]';
      final e = entry('test', [structured]);
      final terms = RecursiveLookup.extractSubTerms(e);
      // spans and ruby bases flatten into one continuous CJK run
      expect(terms.any((t) => t.contains('日本語の')), true);
      expect(terms.any((t) => t.contains('漢')), true);
    });

    test('lookup returns null for unknown term', () async {
      final result = await RecursiveLookup.lookup(
        'nothing',
        (t) async => <DictionaryEntry>[],
      );
      expect(result, isNull);
    });

    test('lookup builds one level of children', () async {
      final db = {
        '親': [
          entry('親', ['日本語 parent word']),
        ],
        '日本語': [
          entry('日本語', ['the Japanese language']),
        ],
      };
      final result = await RecursiveLookup.lookup(
        '親',
        (t) async => db[t] ?? <DictionaryEntry>[],
      );
      expect(result, isNotNull);
      expect(result!.entry.term, '親');
      expect(result.children, isNotEmpty);
      expect(result.children.first.entry.term, '日本語');
    });

    test('lookup stops at max depth 3', () async {
      // CJK chain: 一 -> 二 -> 三 -> 四 -> 五; maxDepth=3 caps at 3 levels
      final db = {
        '一': [
          entry('一', ['next is 二']),
        ],
        '二': [
          entry('二', ['next is 三']),
        ],
        '三': [
          entry('三', ['next is 四']),
        ],
        '四': [
          entry('四', ['next is 五']),
        ],
        '五': [
          entry('五', ['the end']),
        ],
      };
      final result = await RecursiveLookup.lookup(
        '一',
        (t) async => db[t] ?? <DictionaryEntry>[],
      );
      expect(result, isNotNull);
      // level 0: 一
      expect(result!.entry.term, '一');
      // level 1: 二
      final lvl1 = result.children.first;
      expect(lvl1.entry.term, '二');
      // level 2: 三 (maxDepth-1 = 2, so no children)
      final lvl2 = lvl1.children.first;
      expect(lvl2.entry.term, '三');
      expect(lvl2.children, isEmpty);
    });

    test('lookup breaks cycles', () async {
      final db = {
        '親': [
          entry('親', ['child is 子']),
        ],
        '子': [
          entry('子', ['parent is 親']),
        ],
      };
      final result = await RecursiveLookup.lookup(
        '親',
        (t) async => db[t] ?? <DictionaryEntry>[],
      );
      expect(result, isNotNull);
      expect(result!.children.first.entry.term, '子');
      // 子's definition mentions 親, which is already visited
      expect(result.children.first.children, isEmpty);
    });

    test('lookup respects maxChildrenPerEntry', () async {
      final e = entry('big', [
        'one two three four five six seven eight nine ten',
      ]);
      final db = {
        'big': [e],
      };
      var lookups = 0;
      final result = await RecursiveLookup.lookup('big', (t) async {
        lookups++;
        return db[t] ?? <DictionaryEntry>[];
      });
      expect(result, isNotNull);
      // sub-term lookups are capped per entry (1 for 'big' itself
      // + at most maxChildrenPerEntry children)
      expect(
        lookups,
        lessThanOrEqualTo(1 + RecursiveLookup.maxChildrenPerEntry),
      );
    });
  });
}
