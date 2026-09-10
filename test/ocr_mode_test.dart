import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/search_screen.dart';

void main() {
  group('OcrMode', () {
    test('has five OCR modes', () {
      expect(OcrMode.values.length, 5);
      expect(OcrMode.values, contains(OcrMode.mlKit));
      expect(OcrMode.values, contains(OcrMode.tesseract));
      expect(OcrMode.values, contains(OcrMode.easyOcr));
      expect(OcrMode.values, contains(OcrMode.ai));
      expect(OcrMode.values, contains(OcrMode.api));
    });

    test('OcrMode can be compared', () {
      expect(OcrMode.mlKit, equals(OcrMode.mlKit));
      expect(OcrMode.mlKit, isNot(equals(OcrMode.tesseract)));
      expect(OcrMode.tesseract, isNot(equals(OcrMode.easyOcr)));
      expect(OcrMode.easyOcr, isNot(equals(OcrMode.ai)));
      expect(OcrMode.ai, isNot(equals(OcrMode.api)));
    });

    test('OcrMode has correct index values', () {
      expect(OcrMode.mlKit.index, 0);
      expect(OcrMode.tesseract.index, 1);
      expect(OcrMode.easyOcr.index, 2);
      expect(OcrMode.ai.index, 3);
      expect(OcrMode.api.index, 4);
    });

    test('OcrMode can be switched with index', () {
      final mode = OcrMode.values[0];
      expect(mode, OcrMode.mlKit);
    });
  });

  group('OcrMode names', () {
    test('mlKit name is mlKit', () {
      expect(OcrMode.mlKit.name, 'mlKit');
    });

    test('tesseract name is tesseract', () {
      expect(OcrMode.tesseract.name, 'tesseract');
    });

    test('easyOcr name is easyOcr', () {
      expect(OcrMode.easyOcr.name, 'easyOcr');
    });

    test('ai name is ai', () {
      expect(OcrMode.ai.name, 'ai');
    });

    test('api name is api', () {
      expect(OcrMode.api.name, 'api');
    });
  });

  group('OcrMode iteration', () {
    test('can iterate through all modes', () {
      final modes = OcrMode.values;

      expect(modes.length, 5);
      expect(modes[0], OcrMode.mlKit);
      expect(modes[1], OcrMode.tesseract);
      expect(modes[2], OcrMode.easyOcr);
      expect(modes[3], OcrMode.ai);
      expect(modes[4], OcrMode.api);
    });

    test('forEach iterates all modes', () {
      int count = 0;
      for (var mode in OcrMode.values) {
        count++;
      }
      expect(count, 5);
    });
  });
}
