// Regression test for the live-OCR overlay integration in the app
// shell: the screen must still fill the body when the overlay's Stack
// is introduced, and the overlay must sit above it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/presentation/widgets/live_ocr_overlay.dart';

/// Key of the Stack the app shell puts the screen and the overlay in.
const _bodyStack = Key('body-stack');

/// Key of the container standing in for the screen widget.
const _screenBox = Key('screen-box');

void main() {
  testWidgets('the screen still fills the body under the overlay stack', (
    tester,
  ) async {
    // mirrors the app shell: the screen and the overlay share a Stack
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            key: _bodyStack,
            fit: StackFit.expand,
            children: [
              Container(key: _screenBox, child: const Text('screen')),
              const LiveOcrOverlay(sourceText: 'overlay'),
            ],
          ),
        ),
      ),
    );

    final body = tester.getSize(find.byKey(_bodyStack));
    final screen = tester.getSize(find.byKey(_screenBox));
    expect(screen.width, body.width);
    expect(screen.height, body.height);
  });

  testWidgets('the overlay is painted above the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            key: _bodyStack,
            fit: StackFit.expand,
            children: [
              const SizedBox.expand(
                child: ColoredBox(color: Color(0xFF000000)),
              ),
              const LiveOcrOverlay(sourceText: 'overlay'),
            ],
          ),
        ),
      ),
    );

    // the overlay is the last child, so it is the topmost
    final stack = tester.widget<Stack>(find.byKey(_bodyStack));
    expect(stack.children.last, isA<LiveOcrOverlay>());
  });
}
