// Tests for the video tab's reading annotations and word definitions.
//
// Two features are covered:
//  - furigana / pinyin on the subtitles (over the picture and in the
//    draggable caption bubble), driven by the user's reading style;
//  - the per-word definition popup on the transcript, which needs the
//    popup dictionary to allow the video route and the transcript to
//    resolve the word under the pointer.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/reader/video_tab.dart';
import 'package:lang/presentation/widgets/annotated_line.dart';
import 'package:lang/utils/cjk_text_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  // the popup dictionary controller is a singleton
  final PopupDictionaryController controller =
      PopupDictionaryController.instance;

  Future<void> pumpApp(
    WidgetTester tester, {
    String readingStyle = 'off',
    bool hoverDefinitions = true,
    String routeName = 'video',
  }) async {
    SharedPreferences.setMockInitialValues({
      'reading_style': readingStyle,
      'show_hover_definitions': hoverDefinitions,
    });
    final storage = StorageService();
    await storage.init();
    state = AppState(storage);

    controller.config = PopupDictionaryConfig(
      trigger: PopupTrigger.click,
      allowedScreens: {PopupScreenScope.video},
    );
    controller.currentRouteName = routeName;
    controller.lookupBuilder =
        (context, lookup) async => Text('def:${lookup.term}');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoTab()),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() {
    // the controller is a singleton: reset it through the instance, not
    // through the local, which is only assigned by pumpApp and so is
    // still uninitialised in the tests that never pump the app
    final singleton = PopupDictionaryController.instance;
    singleton.lookupBuilder = null;
    singleton.config = PopupDictionaryConfig();
    singleton.currentRouteName = '';
    singleton.hide();
  });

  group('reading annotations', () {
    testWidgets('subtitles over the picture stay plain when reading is off', (
      tester,
    ) async {
      await pumpApp(tester, readingStyle: 'off');

      // no media loaded: the empty state shows, and no annotated
      // subtitle can be on screen
      expect(find.text('Pick a video to play with a subtitle track.'),
          findsOneWidget);
      expect(state.readingStyle, 'off');
    });

    testWidgets('reading style furigana is kept for the subtitles', (
      tester,
    ) async {
      await pumpApp(tester, readingStyle: 'furigana');

      expect(state.readingStyle, 'furigana');
    });

    testWidgets('reading style pinyin is kept for the subtitles', (
      tester,
    ) async {
      await pumpApp(tester, readingStyle: 'pinyin');

      expect(state.readingStyle, 'pinyin');
    });
  });

  group('reading style selection', () {
    // Kanji are shared between Chinese and Japanese, so the reading
    // style has to know which script the line is in. Without it a
    // Japanese kanji word gets a Chinese pinyin reading, and a Chinese
    // line gets the dictionary's Japanese kana reading.
    test('furigana draws only on Japanese tokens', () {
      const japanese = AnnotatedToken(text: '日本語', reading: 'にほんご');
      const chinese = AnnotatedToken(text: '中文', reading: 'zhōng wén');

      expect(
        AnnotatedLine.hasReadingFor('furigana', japanese, isChinese: false),
        isTrue,
      );
      expect(
        AnnotatedLine.hasReadingFor('furigana', chinese, isChinese: true),
        isFalse,
      );
    });

    test('pinyin draws only on Chinese tokens', () {
      const japanese = AnnotatedToken(text: '日本語', reading: 'にほんご');
      const chinese = AnnotatedToken(text: '中文', reading: 'zhōng wén');

      expect(
        AnnotatedLine.hasReadingFor('pinyin', japanese, isChinese: false),
        isFalse,
      );
      expect(
        AnnotatedLine.hasReadingFor('pinyin', chinese, isChinese: true),
        isTrue,
      );
    });

    test('pinyin draws on a multi-character Chinese word', () {
      // Chinese tokens are words, not single characters, so the gate
      // must not require a one-character token.
      const word = AnnotatedToken(text: '中国', reading: 'zhōng guó');

      expect(
        AnnotatedLine.hasReadingFor('pinyin', word, isChinese: true),
        isTrue,
      );
      expect(
        AnnotatedLine.hasReadingFor('pinyin', word, isChinese: false),
        isFalse,
      );
    });

    test('off never draws a reading', () {
      const japanese = AnnotatedToken(text: '日本語', reading: 'にほんご');

      expect(
        AnnotatedLine.hasReadingFor('off', japanese, isChinese: false),
        isFalse,
      );
    });

    test('auto draws a reading whenever one is known', () {
      const japanese = AnnotatedToken(text: '日本語', reading: 'にほんご');
      const unknown = AnnotatedToken(text: '日本語');

      expect(
        AnnotatedLine.hasReadingFor('auto', japanese, isChinese: false),
        isTrue,
      );
      expect(
        AnnotatedLine.hasReadingFor('auto', unknown, isChinese: false),
        isFalse,
      );
    });
  });

  group('popup dictionary scope', () {
    test('the video route is allowed by the video screen scope', () {
      final scoped = PopupDictionaryConfig(
        allowedScreens: {PopupScreenScope.video},
      );

      expect(scoped.allowsScreen('video'), isTrue);
      expect(scoped.allowsScreen('analyze'), isFalse);
    });

    test('the video scope survives a config round-trip', () {
      final config = PopupDictionaryConfig(
        allowedScreens: {PopupScreenScope.video, PopupScreenScope.reader},
      );

      final restored = PopupDictionaryConfig.fromJson(config.toJson());

      expect(restored.allowedScreens, {
        PopupScreenScope.video,
        PopupScreenScope.reader,
      });
      expect(restored.allowsScreen('video'), isTrue);
    });
  });

  group('transcript hover definitions', () {
    // The video tab offers a modifier-free hover: resting the pointer
    // on a transcript word opens its definition. It rides on the
    // popup dictionary's own global pointer listener, so the video tab
    // needs no widget of its own.
    Future<void> pumpScope(WidgetTester tester) async {
      // the shell sets the active route; the popup only opens on an
      // allowed screen, and the video route is what this group covers
      controller.currentRouteName = 'video';
      await tester.pumpWidget(
        const MaterialApp(
          home: PopupDictionaryScope(
            child: Scaffold(body: Center(child: Text('日本語のテスト'))),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hovering a word opens its definition', (tester) async {
      await pumpApp(tester);
      controller.plainHoverEnabled = true;
      await pumpScope(tester);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('日本語のテスト')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isPopupOpen, isTrue);
      expect(find.text('def:日本語のテスト'), findsOneWidget);
    });

    testWidgets('no modifier is needed for the plain hover', (tester) async {
      await pumpApp(tester);
      // the default trigger needs a modifier; the plain hover does not
      controller.config = PopupDictionaryConfig(
        trigger: PopupTrigger.shift,
        allowedScreens: {PopupScreenScope.video},
      );
      controller.plainHoverEnabled = true;
      await pumpScope(tester);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('日本語のテスト')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isPopupOpen, isTrue);
    });

    testWidgets('hover definitions are off when the setting is off', (
      tester,
    ) async {
      await pumpApp(tester, hoverDefinitions: false);
      controller.plainHoverEnabled = false;
      await pumpScope(tester);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('日本語のテスト')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isPopupOpen, isFalse);
      expect(find.text('def:日本語のテスト'), findsNothing);
    });

    testWidgets('disabling the plain hover closes an open popup', (
      tester,
    ) async {
      await pumpApp(tester);
      controller.plainHoverEnabled = true;
      await pumpScope(tester);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('日本語のテスト')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isPopupOpen, isTrue);

      controller.plainHoverEnabled = false;

      expect(controller.isPopupOpen, isFalse);
    });
  });

  group('annotated text extraction', () {
    // A reading annotation draws the kana above the kanji with a
    // WidgetSpan, so the kanji ends up inside an inline widget rather
    // than in the paragraph's span tree. The paragraph's plain text
    // then holds only the object-replacement placeholder, and the
    // pointer never reaches the inner text either. The extractor has to
    // look the annotated text up in the inline children, otherwise the
    // lookup runs on the placeholder and finds nothing.
    testWidgets('a word inside a reading annotation is found', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('にほんご', style: TextStyle(fontSize: 8)),
                            Text('日本語', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      TextSpan(text: 'の'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('てすと', style: TextStyle(fontSize: 8)),
                            Text('テスト', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final extractor = CjkTextExtractor();
      final kanji = tester.getRect(find.text('日本語'));
      final hit = extractor.extractAt(kanji.center, PopupDictionaryConfig());

      expect(hit, isNotNull);
      expect(hit!.term, '日本語');
    });

    testWidgets('pointing at the reading looks the word up', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('にほんご', style: TextStyle(fontSize: 8)),
                            Text('日本語', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final extractor = CjkTextExtractor();
      final reading = tester.getRect(find.text('にほんご'));
      final hit = extractor.extractAt(reading.center, PopupDictionaryConfig());

      expect(hit, isNotNull);
      expect(hit!.term, '日本語');
    });
  });
}
