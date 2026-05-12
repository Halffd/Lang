import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/ocr_service.dart';

void main() {
  group('OcrEngine', () {
    test('has three engine options', () {
      expect(OcrEngine.values.length, 3);
      expect(OcrEngine.values, contains(OcrEngine.mlKit));
      expect(OcrEngine.values, contains(OcrEngine.tesseract));
      expect(OcrEngine.values, contains(OcrEngine.easyOcr));
    });
  });

  group('OcrService', () {
    late OcrService ocrService;

    setUp(() {
      ocrService = OcrService();
    });

    tearDown(() {
      ocrService.dispose();
    });

    test('getEngineName returns correct names', () {
      expect(ocrService.getEngineName(OcrEngine.mlKit), 'ML Kit');
      expect(ocrService.getEngineName(OcrEngine.tesseract), 'Tesseract');
      expect(ocrService.getEngineName(OcrEngine.easyOcr), 'EasyOCR');
    });

    test('getEngineDescription returns descriptions', () {
      final mlKitDesc = ocrService.getEngineDescription(OcrEngine.mlKit);
      final tesseractDesc = ocrService.getEngineDescription(OcrEngine.tesseract);
      final easyOcrDesc = ocrService.getEngineDescription(OcrEngine.easyOcr);

      expect(mlKitDesc, contains('ML Kit'));
      expect(mlKitDesc, contains('Google'));
      expect(tesseractDesc, contains('Tesseract'));
      expect(tesseractDesc, contains('open source'));
      expect(easyOcrDesc, contains('EasyOCR'));
      expect(easyOcrDesc, contains('AI-powered'));
    });

    test('initialize does not throw', () async {
      await expectLater(ocrService.initialize(), completes);
    });
  });

  group('OcrResult', () {
    test('creates successful result', () {
      final result = OcrResult(
        text: 'Hello World',
        blocks: [],
        confidence: 0.95,
      );

      expect(result.text, 'Hello World');
      expect(result.blocks, isEmpty);
      expect(result.confidence, 0.95);
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
    });

    test('creates result with error', () {
      final result = OcrResult(
        text: '',
        error: 'Failed to process image',
      );

      expect(result.text, isEmpty);
      expect(result.error, 'Failed to process image');
      expect(result.isSuccess, isFalse);
    });

    test('creates result with isEasyOcrUnavailable flag', () {
      final result = OcrResult(
        text: '',
        error: 'EasyOCR requires backend',
        isEasyOcrUnavailable: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isEasyOcrUnavailable, isTrue);
    });

    test('default confidence is 0.0', () {
      final result = OcrResult(text: 'test');
      expect(result.confidence, 0.0);
    });

    test('default blocks is empty list', () {
      final result = OcrResult(text: 'test');
      expect(result.blocks, isEmpty);
    });

    test('default isEasyOcrUnavailable is false', () {
      final result = OcrResult(text: 'test');
      expect(result.isEasyOcrUnavailable, isFalse);
    });
  });

  group('OcrTextBlock', () {
    test('creates block with required fields', () {
      final block = OcrTextBlock(
        text: 'Sample text block',
      );

      expect(block.text, 'Sample text block');
      expect(block.boundingBox, isNull);
      expect(block.lines, isEmpty);
    });

    test('creates block with bounding box', () {
      final block = OcrTextBlock(
        text: 'Text with position',
        boundingBox: Rect(left: 10, top: 20, right: 100, bottom: 50),
      );

      expect(block.boundingBox, isNotNull);
      expect(block.boundingBox!.left, 10);
      expect(block.boundingBox!.top, 20);
      expect(block.boundingBox!.right, 100);
      expect(block.boundingBox!.bottom, 50);
    });

    test('creates block with lines', () {
      final lines = [
        OcrLine(text: 'Line 1', words: ['Line', '1']),
        OcrLine(text: 'Line 2', words: ['Line', '2']),
      ];

      final block = OcrTextBlock(
        text: 'Multi-line text',
        lines: lines,
      );

      expect(block.lines.length, 2);
      expect(block.lines[0].text, 'Line 1');
      expect(block.lines[0].words, ['Line', '1']);
    });
  });

  group('OcrLine', () {
    test('creates line with required fields', () {
      final line = OcrLine(
        text: 'Hello',
        words: ['Hello'],
      );

      expect(line.text, 'Hello');
      expect(line.words, ['Hello']);
      expect(line.boundingBox, isNull);
    });

    test('creates line with bounding box', () {
      final line = OcrLine(
        text: 'Text line',
        boundingBox: Rect(left: 0, top: 0, right: 200, bottom: 30),
      );

      expect(line.boundingBox, isNotNull);
      expect(line.boundingBox!.width, 200);
      expect(line.boundingBox!.height, 30);
    });

    test('creates line with multiple words', () {
      final line = OcrLine(
        text: 'The quick brown fox',
        words: ['The', 'quick', 'brown', 'fox'],
      );

      expect(line.words.length, 4);
    });
  });

  group('Rect', () {
    test('creates rect with coordinates', () {
      final rect = Rect(left: 10, top: 20, right: 110, bottom: 70);

      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.right, 110);
      expect(rect.bottom, 70);
    });

    test('calculates width correctly', () {
      final rect = Rect(left: 10, top: 20, right: 110, bottom: 70);

      expect(rect.width, 100);
    });

    test('calculates height correctly', () {
      final rect = Rect(left: 10, top: 20, right: 110, bottom: 70);

      expect(rect.height, 50);
    });

    test('handles zero width', () {
      final rect = Rect(left: 50, top: 20, right: 50, bottom: 70);

      expect(rect.width, 0);
    });

    test('handles zero height', () {
      final rect = Rect(left: 10, top: 50, right: 110, bottom: 50);

      expect(rect.height, 0);
    });

    test('handles negative dimensions', () {
      final rect = Rect(left: 100, top: 70, right: 10, bottom: 20);

      expect(rect.width, 90);
      expect(rect.height, 50);
    });
  });

  group('OcrService initialization', () {
    test('can create multiple instances', () {
      final service1 = OcrService();
      final service2 = OcrService();

      expect(service1, isNot(same(service2)));

      service1.dispose();
      service2.dispose();
    });

    test('initialize can be called multiple times', () async {
      final service = OcrService();

      await service.initialize();
      await service.initialize();
      await service.initialize();

      service.dispose();
    });
  });

  group('OcrService engine selection', () {
    test('all engines have names', () {
      final service = OcrService();

      for (final engine in OcrEngine.values) {
        final name = service.getEngineName(engine);
        expect(name, isNotEmpty);
      }

      service.dispose();
    });

    test('all engines have descriptions', () {
      final service = OcrService();

      for (final engine in OcrEngine.values) {
        final desc = service.getEngineDescription(engine);
        expect(desc, isNotEmpty);
        expect(desc.length, greaterThan(10));
      }

      service.dispose();
    });

    test('descriptions are unique per engine', () {
      final service = OcrService();

      final mlKitDesc = service.getEngineDescription(OcrEngine.mlKit);
      final tesseractDesc = service.getEngineDescription(OcrEngine.tesseract);
      final easyOcrDesc = service.getEngineDescription(OcrEngine.easyOcr);

      expect(mlKitDesc, isNot(equals(tesseractDesc)));
      expect(mlKitDesc, isNot(equals(easyOcrDesc)));
      expect(tesseractDesc, isNot(equals(easyOcrDesc)));

      service.dispose();
    });
  });

  group('OcrResult with blocks', () {
    test('result with full block structure', () {
      final blocks = [
        OcrTextBlock(
          text: 'First paragraph',
          boundingBox: Rect(left: 0, top: 0, right: 300, bottom: 50),
          lines: [
            OcrLine(
              text: 'First line',
              boundingBox: Rect(left: 0, top: 0, right: 300, bottom: 25),
              words: ['First', 'line'],
            ),
            OcrLine(
              text: 'Second line',
              boundingBox: Rect(left: 0, top: 25, right: 300, bottom: 50),
              words: ['Second', 'line'],
            ),
          ],
        ),
        OcrTextBlock(
          text: 'Second paragraph',
          boundingBox: Rect(left: 0, top: 60, right: 300, bottom: 110),
          lines: [
            OcrLine(
              text: 'Third line',
              boundingBox: Rect(left: 0, top: 60, right: 300, bottom: 85),
              words: ['Third', 'line'],
            ),
          ],
        ),
      ];

      final result = OcrResult(
        text: 'First paragraph\nSecond paragraph',
        blocks: blocks,
        confidence: 0.92,
      );

      expect(result.blocks.length, 2);
      expect(result.blocks[0].lines.length, 2);
      expect(result.blocks[1].lines.length, 1);
      expect(result.blocks[0].lines[0].words.length, 2);
      expect(result.confidence, 0.92);
    });

    test('empty blocks is valid', () {
      final result = OcrResult(
        text: '',
        blocks: [],
      );

      expect(result.blocks, isEmpty);
      expect(result.isSuccess, isTrue);
    });
  });

  group('OcrService dispose', () {
    test('dispose does not throw', () {
      final service = OcrService();
      expect(() => service.dispose(), returnsNormally);
    });

    test('dispose can be called multiple times', () {
      final service = OcrService();
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}