// Golden baselines for the core UI pieces.
//
// Each subject is wrapped in a keyed RepaintBoundary at a fixed logical
// surface (800x600, DPR 1.0) so the captured pixels are exactly the subject,
// stable across runs. Baselines live in test/goldens/ and are committed; a
// failing compare writes master/test/masked/isolated diff images into
// test/goldens/failures/ so a regression is visible without re-running.
//
// Regenerate deliberately after an intended visual change:
//   flutter test --update-goldens test/ui_golden_test.dart
// and review the changed PNGs in the commit diff.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/presentation/widgets/dictionary_entry_card.dart';
import 'package:lang/presentation/widgets/tag_renderer.dart';
import 'package:lang/presentation/widgets/search/search_bar_widget.dart';

import 'golden/test_fonts.dart';

class _MockStorage extends StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getSavedWords() async => <String>{};

  @override
  Future<Set<String>> getFavoriteWords() async => <String>{};

  @override
  Future<Set<String>> getAnkiWords() async => <String>{};

  @override
  String getStringSync(String key) => '';

  @override
  Future<String?> getString(String key) async => '';

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
}

DictionaryEntry makeEntry() => DictionaryEntry(
  dictionaryId: 1,
  term: '読む',
  reading: 'よむ',
  definitions: ['to read', 'to study'],
  definitionTags: [],
  rules: [],
  popularity: 100,
);

void main() {
  setUpAll(() async {
    // Real glyphs for the baselines: widget tests default to the Ahem block
    // font. Loaded here, not in flutter_test_config, so the rest of the suite
    // keeps its existing text metrics. Each test file runs in its own
    // isolate, so this only affects this file.
    await loadAppFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('golden: dictionary entry card', (tester) async {
    final key = GlobalKey();
    await _pumpSurface(
      tester,
      RepaintBoundary(
        key: key,
        child: ChangeNotifierProvider.value(
          value: AppState(_MockStorage()),
          child: DictionaryEntryCard(
            entry: makeEntry(),
            isSaved: false,
            isFavorite: false,
            isInAnki: false,
            onSaveToggle: () {},
            onFavoriteToggle: () {},
            onAnkiToggle: () {},
            onSRSToggle: () {},
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/dictionary_entry_card.png'),
    );
  });

  testWidgets('golden: part-of-speech tag chips', (tester) async {
    final key = GlobalKey();
    await _pumpSurface(
      tester,
      RepaintBoundary(
        key: key,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [TagChip('v5'), TagChip('n'), TagChip('prt')]),
                Row(children: [TagChip('xyz-unknown'), TagChip('adj-i')]),
              ],
            ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/tag_chips.png'),
    );
  });

  testWidgets('golden: search bar', (tester) async {
    final key = GlobalKey();
    final controller = TextEditingController(text: 'dictionary');
    addTearDown(controller.dispose);
    await _pumpSurface(
      tester,
      RepaintBoundary(
        key: key,
        child: SearchBarWidget(
          controller: controller,
          onSubmitted: (_) {},
          hintText: 'Search',
          onClear: () {},
        ),
      ),
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/search_bar.png'),
    );
  });
}

/// Renders [child] on a fixed 800x600 surface inside a Roboto-themed
/// Material app. Real fonts come from flutter_test_config.dart.
Future<void> _pumpSurface(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

class TagChip extends StatelessWidget {
  const TagChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TagRenderer.renderTag(code),
    );
  }
}
