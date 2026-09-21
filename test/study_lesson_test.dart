import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/presentation/screens/study/lesson_page.dart';
import 'package:lang/presentation/screens/study/lesson_widgets.dart';

Future<SRSService> _srs() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return SRSService(storage);
}

void main() {
  group('MultipleChoiceView', () {
    testWidgets('shows options and routes tap', (tester) async {
      var picked = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipleChoiceView(
              word: '食べる',
              meanings: const ['to eat', 'to run', 'to sleep', 'red'],
              correctIndex: 0,
              onPick: (i) => picked = i,
            ),
          ),
        ),
      );
      expect(find.text('to eat'), findsOneWidget);
      await tester.tap(find.text('to eat'));
      expect(picked, 0);
    });

    testWidgets('wrong choice returns wrong index', (tester) async {
      var picked = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultipleChoiceView(
              word: '猫',
              meanings: const ['cat', 'dog', 'bird', 'fish'],
              correctIndex: 0,
              onPick: (i) => picked = i,
            ),
          ),
        ),
      );
      await tester.tap(find.text('dog'));
      expect(picked, 1);
    });
  });

  group('WrittenEntryField', () {
    testWidgets('submit triggers onSubmit', (tester) async {
      var submitted = 0;
      final ctrl = TextEditingController(text: 'て');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WrittenEntryField(
              label: 'え',
              controller: ctrl,
              onSubmit: () => submitted++,
            ),
          ),
        ),
      );
      final checkBtn = find.text('Check');
      await tester.ensureVisible(checkBtn);
      await tester.tap(checkBtn);
      expect(submitted, 1);
    });
  });

  group('LessonPage', () {
    testWidgets('flashcard shows word and can flip', (tester) async {
      final srs = await _srs();
      final card = SRSCard(
        id: 'a1',
        word: '食べる',
        meaning: 'to eat',
        nextReview: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(cards: [card], type: LessonType.flashcard, srs: srs),
        ),
      );
      expect(find.text('食べる'), findsOneWidget);
      expect(find.text('to eat'), findsNothing);
      // flip
      await tester.tap(find.text('食べる'));
      await tester.pumpAndSettle();
      expect(find.text('to eat'), findsOneWidget);
    });

    testWidgets('multiple choice passes through signing', (tester) async {
      final srs = await _srs();
      final cards = [
        SRSCard(id: 'a', word: '犬', meaning: 'dog', nextReview: DateTime.now()),
        SRSCard(
          id: 'b',
          word: '魚',
          meaning: 'fish',
          nextReview: DateTime.now(),
        ),
        SRSCard(
          id: 'c',
          word: '鳥',
          meaning: 'bird',
          nextReview: DateTime.now(),
        ),
        SRSCard(
          id: 'd',
          word: '馬',
          meaning: 'horse',
          nextReview: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(
            cards: cards,
            type: LessonType.multipleChoice,
            srs: srs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Should show progress "1 / 4"
      expect(find.text('1 / 4'), findsOneWidget);
    });
  });
}
