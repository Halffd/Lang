import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/utils/japanese_grammar.dart';

void main() {
  group('PopupDictionaryConfig', () {
    test('defaults', () {
      final c = PopupDictionaryConfig();
      expect(c.trigger, PopupTrigger.shift);
      expect(c.extraModifier, PopupExtraModifier.none);
      expect(c.delayMs, 300);
      expect(c.scanLength, 16);
      expect(c.scanDepth, 8);
      expect(c.detectCompounds, isTrue);
      expect(c.detectConjugations, isTrue);
      expect(c.allowedScreens, {PopupScreenScope.all});
      expect(c.languages, isEmpty);
    });

    test('serialize round trip', () {
      final c = PopupDictionaryConfig(
        trigger: PopupTrigger.doubleClick,
        extraModifier: PopupExtraModifier.ctrl,
        delayMs: 500,
        scanLength: 32,
        scanDepth: 4,
        autoCopy: true,
        autoAnki: true,
        ankiDeck: 'My Deck',
        requireRegex: '[\\u4e00-\\u9fff]',
        excludeRegex: '^[0-9]+\$',
        detectCompounds: false,
        detectConjugations: false,
        allowedScreens: {PopupScreenScope.analyze, PopupScreenScope.reader},
        altTrigger: PopupTrigger.hover,
        altCondition: 'kana learner',
        languages: {'ja'},
      );
      final restored = PopupDictionaryConfig.deserialize(c.serialize());
      expect(restored.trigger, PopupTrigger.doubleClick);
      expect(restored.extraModifier, PopupExtraModifier.ctrl);
      expect(restored.delayMs, 500);
      expect(restored.scanLength, 32);
      expect(restored.scanDepth, 4);
      expect(restored.autoCopy, isTrue);
      expect(restored.autoAnki, isTrue);
      expect(restored.ankiDeck, 'My Deck');
      expect(restored.requireRegex, '[\\u4e00-\\u9fff]');
      expect(restored.excludeRegex, '^[0-9]+\$');
      expect(restored.detectCompounds, isFalse);
      expect(restored.detectConjugations, isFalse);
      expect(restored.allowedScreens, {
        PopupScreenScope.analyze,
        PopupScreenScope.reader,
      });
      expect(restored.altTrigger, PopupTrigger.hover);
      expect(restored.altCondition, 'kana learner');
      expect(restored.languages, {'ja'});
    });

    test('deserialize garbage falls back to defaults', () {
      final c = PopupDictionaryConfig.deserialize('not json{');
      expect(c.trigger, PopupTrigger.shift);
      expect(c.delayMs, 300);
    });

    test('deserialize null/empty falls back to defaults', () {
      expect(
        PopupDictionaryConfig.deserialize(null).trigger,
        PopupTrigger.shift,
      );
      expect(PopupDictionaryConfig.deserialize('').delayMs, 300);
    });

    test('allowsText regex gates', () {
      final c = PopupDictionaryConfig(
        requireRegex: '[\\u3040-\\u30ff]',
        excludeRegex: '^[\\u3040-\\u30ff]+\$',
      );
      // mixed kanji+kana passes require, fails exclude
      expect(c.allowsText('食べる'), isTrue);
      // pure kana hits the exclude gate
      expect(c.allowsText('ひらがな'), isFalse);
      // pure romaji fails require gate
      expect(c.allowsText('romaji'), isFalse);
      // malformed regex ignored (gate disabled)
      expect(
        PopupDictionaryConfig(
          requireRegex: '([unclosed',
        ).allowsText('anything'),
        isTrue,
      );
      expect(
        PopupDictionaryConfig(excludeRegex: '[bad').allowsText('anything'),
        isTrue,
      );
    });

    test('allowsScreen scoping', () {
      final all = PopupDictionaryConfig();
      expect(all.allowsScreen('analyze_screen'), isTrue);
      expect(all.allowsScreen('whatever'), isTrue);

      final scoped = PopupDictionaryConfig(
        allowedScreens: {PopupScreenScope.reader, PopupScreenScope.srs},
      );
      expect(scoped.allowsScreen('reader_screen'), isTrue);
      expect(scoped.allowsScreen('srs_screen'), isTrue);
      expect(scoped.allowsScreen('analyze_screen'), isFalse);
    });

    test('effectiveTrigger profile alternation', () {
      final c = PopupDictionaryConfig(
        trigger: PopupTrigger.shift,
        altTrigger: PopupTrigger.click,
        altCondition: 'reader profile',
      );
      expect(c.effectiveTrigger(null), PopupTrigger.shift);
      expect(c.effectiveTrigger('other'), PopupTrigger.shift);
      expect(c.effectiveTrigger('reader profile'), PopupTrigger.click);
      // no alt configured: primary everywhere
      final plain = PopupDictionaryConfig();
      expect(plain.effectiveTrigger('reader profile'), PopupTrigger.shift);
    });
  });

  group('popupLookupCandidates', () {
    test('short word is itself', () {
      expect(JapaneseGrammar.popupLookupCandidates('犬'), ['犬']);
      expect(JapaneseGrammar.popupLookupCandidates('猫'), ['猫']);
    });

    test('long compound: full form first, prefixes after', () {
      final c = JapaneseGrammar.popupLookupCandidates('食べ物');
      expect(c.first, '食べ物');
      expect(c, containsAll(['食べ', '食べ物']));
      expect(c.indexOf('食べ物'), lessThan(c.indexOf('食べ')));
    });

    test('no duplicates', () {
      final c = JapaneseGrammar.popupLookupCandidates('日本語');
      expect(c.toSet().length, c.length);
    });

    test('deconjugated forms included', () {
      // past tense verb should yield dictionary form candidate
      final c = JapaneseGrammar.popupLookupCandidates('食べた');
      expect(c, contains('食べる'));
    });

    test('empty input yields nothing', () {
      expect(JapaneseGrammar.popupLookupCandidates(''), isEmpty);
    });
  });
}
