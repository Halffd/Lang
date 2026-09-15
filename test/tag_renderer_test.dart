// TagRenderer: yomichan part-of-speech tag chips - color/name
// mapping and rendered widget output.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/presentation/widgets/tag_renderer.dart';

void main() {
  group('tagNames', () {
    test('core grammar tags have friendly names', () {
      expect(TagRenderer.tagNames['v1'], 'ichidan verb');
      expect(TagRenderer.tagNames['v5'], 'godan verb');
      expect(TagRenderer.tagNames['n'], 'noun');
      expect(TagRenderer.tagNames['prt'], 'particle');
      expect(TagRenderer.tagNames['adj-na'], 'na-adjective');
      expect(TagRenderer.tagNames['vt'], 'transitive');
    });

    test('godan row variants all mapped', () {
      for (final t in [
        'v5k',
        'v5g',
        'v5s',
        'v5t',
        'v5n',
        'v5b',
        'v5m',
        'v5r',
        'v5u',
      ]) {
        expect(TagRenderer.tagNames[t], isNotNull, reason: t);
      }
    });
  });

  group('getColorForTag', () {
    test('distinct families get distinct colors', () {
      final verb = TagRenderer.getColorForTag('v5');
      final noun = TagRenderer.getColorForTag('n');
      final particle = TagRenderer.getColorForTag('prt');
      expect(verb, isNot(noun));
      expect(noun, isNot(particle));
      expect(verb, isNot(particle));
    });

    test('case insensitive', () {
      expect(
        TagRenderer.getColorForTag('V5'),
        TagRenderer.getColorForTag('v5'),
      );
      expect(TagRenderer.getColorForTag('N'), TagRenderer.getColorForTag('n'));
    });

    test('unknown tag falls back to grey', () {
      expect(TagRenderer.getColorForTag('zzz'), Colors.grey);
    });
  });

  group('renderTag widget', () {
    testWidgets('shows friendly name for known tag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TagRendererStub())),
      );
      expect(find.text('godan verb'), findsOneWidget);
    });

    testWidgets('unknown tag shows raw code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TagRendererUnknownStub())),
      );
      expect(find.text('xyz-unknown'), findsOneWidget);
    });
  });
}

class TagRendererStub extends StatelessWidget {
  const TagRendererStub();

  @override
  Widget build(BuildContext context) {
    return TagRenderer.renderTag('v5');
  }
}

class TagRendererUnknownStub extends StatelessWidget {
  const TagRendererUnknownStub();

  @override
  Widget build(BuildContext context) {
    return TagRenderer.renderTag('xyz-unknown');
  }
}
