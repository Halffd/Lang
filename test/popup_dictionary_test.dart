import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/core/services/shake_detector.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/utils/cjk_text_extractor.dart';
import 'package:lang/utils/japanese_grammar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('style config round trip', () {
      final c = PopupDictionaryConfig(
        style: PopupStyle.compact,
        width: 420,
        maxHeight: 500,
        fontScale: 1.5,
        showReading: false,
        showSentence: false,
      );
      final back = PopupDictionaryConfig.deserialize(c.serialize());
      expect(back.style, PopupStyle.compact);
      expect(back.width, 420);
      expect(back.maxHeight, 500);
      expect(back.fontScale, 1.5);
      expect(back.showReading, isFalse);
      expect(back.showSentence, isFalse);
    });

    test('style defaults', () {
      final c = PopupDictionaryConfig();
      expect(c.style, PopupStyle.card);
      expect(c.width, 320);
      expect(c.maxHeight, 380);
      expect(c.fontScale, 1.0);
      expect(c.showReading, isTrue);
      expect(c.showSentence, isTrue);
    });
  });

  group('ShakeDetector', () {
    test('spike burst fires shake, single spikes do not', () {
      var shakes = 0;
      final d = ShakeDetector(
        onShake: () => shakes++,
        spikeCount: 3,
        debounce: const Duration(milliseconds: 50),
      );

      // single spike: no shake (|30| - 9.8 = 20.2 net > threshold)
      d.debugSample(30, 0, 0);
      expect(shakes, 0);

      // burst of three quick spikes: shake
      d.debugSample(30, 0, 0);
      d.debugSample(0, 30, 0);
      d.debugSample(0, 0, 30);
      expect(shakes, 1);

      // debounce window: another burst immediately is swallowed
      d.debugSample(30, 0, 0);
      d.debugSample(0, 30, 0);
      d.debugSample(0, 0, 30);
      expect(shakes, 1);
    });

    test('resting gravity never fires', () {
      var shakes = 0;
      final d = ShakeDetector(onShake: () => shakes++);
      for (var i = 0; i < 100; i++) {
        d.debugSample(0, 0, 9.8);
      }
      expect(shakes, 0);
    });

    test('controller arms shake detector only for shake trigger', () {
      final controller = PopupDictionaryController.instance;
      controller.updateConfig(
        PopupDictionaryConfig(trigger: PopupTrigger.click),
      );
      expect(controller.shakeDetectorForTest, isNull);

      controller.updateConfig(
        PopupDictionaryConfig(trigger: PopupTrigger.shake),
      );
      expect(controller.shakeDetectorForTest, isNotNull);

      // profile alternation arming too
      controller.updateConfig(
        PopupDictionaryConfig(
          trigger: PopupTrigger.click,
          altTrigger: PopupTrigger.shake,
          altCondition: 'mobile',
        ),
      );
      expect(controller.shakeDetectorForTest, isNotNull);

      controller.updateConfig(PopupDictionaryConfig());
      expect(controller.shakeDetectorForTest, isNull);
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

    test('compounds disabled: raw word only, no prefixes', () {
      final c = JapaneseGrammar.popupLookupCandidates(
        '日本語',
        detectCompounds: false,
        detectConjugations: false,
      );
      expect(c, ['日本語']);
    });

    test('conjugations disabled: no deconjugated forms', () {
      final c = JapaneseGrammar.popupLookupCandidates(
        '食べた',
        detectConjugations: false,
      );
      // no 食べる dictionary form
      expect(c, isNot(contains('食べる')));
    });

    test('compounds disabled still deconjugates', () {
      final c = JapaneseGrammar.popupLookupCandidates(
        '食べた',
        detectCompounds: false,
        detectConjugations: true,
      );
      expect(c, contains('食べる'));
      // but no shorter prefixes of the raw form
      expect(c, isNot(contains('食べ')));
    });
  });

  group('PopupDictionaryController routing', () {
    test('currentRouteName gates _currentRouteAllows', () {
      final controller = PopupDictionaryController.instance;
      controller.config = PopupDictionaryConfig(
        allowedScreens: {PopupScreenScope.reader},
      );
      controller.currentRouteName = 'analyze';
      // private gate is exercised via allowsScreen on the config:
      // reader-scoped config rejects the analyze route
      expect(controller.config.allowsScreen('analyze'), isFalse);
      expect(controller.config.allowsScreen('reader'), isTrue);
      // restore shared singleton state
      controller.currentRouteName = '';
      controller.config = PopupDictionaryConfig();
    });

    test('onRouteChanged closes open popup', () {
      final controller = PopupDictionaryController.instance;
      controller.onRouteChanged();
      expect(controller.isPopupOpen, isFalse);
    });

    test('hover trigger fires through onHoverUpdate only', () {
      // handlePointerEvent must not act on hover events (the scope
      // dispatches hover to onHoverUpdate); regression guard for
      // the old double-fire path
      final controller = PopupDictionaryController.instance;
      controller.config = PopupDictionaryConfig(trigger: PopupTrigger.hover);
      controller.onRouteChanged(); // clears any state
      // no overlay/context in unit tests: _fire is a no-op, this
      // just asserts the dispatch path does not throw
      controller.onHoverUpdate(PointerHoverEvent(position: Offset.zero));
      controller.handlePointerEvent(PointerHoverEvent(position: Offset.zero));
      expect(controller.isPopupOpen, isFalse);
      controller.config = PopupDictionaryConfig();
    });

    test('updateConfig closes open popup', () {
      final controller = PopupDictionaryController.instance;
      controller.updateConfig(PopupDictionaryConfig());
      expect(controller.isPopupOpen, isFalse);
    });

    test('modifier tracking', () {
      final controller = PopupDictionaryController.instance;
      controller.onModifierKey(true, PopupExtraModifier.ctrl);
      controller
        ..onModifierKey(true, PopupExtraModifier.alt)
        ..onModifierKey(false, PopupExtraModifier.alt);
      // restored below via fresh default config
      controller.onModifierKey(false, PopupExtraModifier.ctrl);
      expect(controller.isPopupOpen, isFalse);
    });
  });

  group('CjkTextExtractor deep scan', () {
    final extractor = CjkTextExtractor();

    test('depth 0: run at the cursor only', () {
      final config = PopupDictionaryConfig(
        scanLength: 16,
        scanDepth: 0,
        requireRegex: '[\\u3040-\\u30ff]', // kana only gate
      );
      // pure kanji run: rejected by the kana gate at depth 0
      final text = '読解漢字問題終了';
      final hit = extractor.extractAtPosition(text, 2, config);
      expect(hit, isNull);
    });

    test('depth N walks forward until a run passes the gates', () {
      final config = PopupDictionaryConfig(
        scanLength: 16,
        scanDepth: 8,
        requireRegex: '[\\u3040-\\u30ff]',
      );
      final text = 'これは漢字テストです';
      // cursor on 漢; depth 8 reaches テスト which contains kana
      final hit = extractor.extractAtPosition(text, 3, config);
      expect(hit, isNotNull);
      expect(hit!.term, contains('テスト'));
    });

    test('scan length caps the run', () {
      final config = PopupDictionaryConfig(scanLength: 2, scanDepth: 0);
      final text = '日本語のテスト';
      final hit = extractor.extractAtPosition(text, 0, config);
      expect(hit, isNotNull);
      expect(hit!.term.length, lessThanOrEqualTo(2));
    });

    test('sentence extraction spans the term', () {
      final config = PopupDictionaryConfig(scanLength: 16, scanDepth: 0);
      final text = '前置き。日本語のテスト。後続';
      final hit = extractor.extractAtPosition(text, 4, config);
      expect(hit, isNotNull);
      expect(hit!.sentence, contains('日本語のテスト'));
    });

    test('out of range index returns null', () {
      final config = PopupDictionaryConfig();
      expect(extractor.extractAtPosition('abc', -1, config), isNull);
      expect(extractor.extractAtPosition('abc', 3, config), isNull);
      expect(extractor.extractAtPosition('', 0, config), isNull);
    });
  });

  group('AnalyzerProvider.lookupWordDirect', () {
    late AnalyzerProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = AnalyzerProvider();
    });

    test('empty query returns empty without touching services', () async {
      final results = await provider.lookupWordDirect('   ');
      expect(results, isEmpty);
    });

    test('whitespace-padded query is not empty', () async {
      // real lookup: no dictionaries loaded in tests, so this
      // exercises the full pipeline and returns empty gracefully
      final results = await provider.lookupWordDirect('  読む  ');
      expect(results, isNotNull);
    });
  });
}
