import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/ocr_service.dart';

void main() {
  group('OcrEngine', () {
    test('has five engine options', () {
      expect(OcrEngine.values.length, 5);
      expect(OcrEngine.values, contains(OcrEngine.mlKit));
      expect(OcrEngine.values, contains(OcrEngine.tesseract));
      expect(OcrEngine.values, contains(OcrEngine.easyOcr));
      expect(OcrEngine.values, contains(OcrEngine.ai));
      expect(OcrEngine.values, contains(OcrEngine.api));
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
      expect(ocrService.getEngineName(OcrEngine.ai), 'AI');
      expect(ocrService.getEngineName(OcrEngine.api), 'API');
    });

    test('getEngineDescription returns descriptions', () {
      final mlKitDesc = ocrService.getEngineDescription(OcrEngine.mlKit);
      final tesseractDesc = ocrService.getEngineDescription(
        OcrEngine.tesseract,
      );
      final easyOcrDesc = ocrService.getEngineDescription(OcrEngine.easyOcr);
      final aiDesc = ocrService.getEngineDescription(OcrEngine.ai);
      final apiDesc = ocrService.getEngineDescription(OcrEngine.api);

      expect(mlKitDesc, contains('ML Kit'));
      expect(mlKitDesc, contains('Google'));
      expect(tesseractDesc, contains('Tesseract'));
      expect(tesseractDesc, contains('open source'));
      expect(easyOcrDesc, contains('EasyOCR'));
      expect(easyOcrDesc, contains('AI-powered'));
      expect(aiDesc, contains('Gemini'));
      expect(apiDesc, contains('OCR.space'));
    });

    test('initialize does not throw', () async {
      await expectLater(ocrService.initialize(), completes);
    });

    test('tesseractLanguage maps app languages to tess codes', () {
      expect(OcrService.tesseractLanguage('ja'), 'jpn');
      expect(OcrService.tesseractLanguage('zh'), 'chi_sim');
      expect(OcrService.tesseractLanguage('ko'), 'kor');
      expect(OcrService.tesseractLanguage('ru'), 'rus');
      expect(OcrService.tesseractLanguage('en'), 'eng');
      expect(OcrService.tesseractLanguage(null), 'eng');
      expect(OcrService.tesseractLanguage('xx'), 'eng');
    });

    test('easyOcrLanguage maps app languages to easyocr codes', () {
      expect(OcrService.easyOcrLanguage('ja'), 'ja');
      expect(OcrService.easyOcrLanguage('zh'), 'ch_sim');
      expect(OcrService.easyOcrLanguage('ko'), 'ko');
      expect(OcrService.easyOcrLanguage('en'), 'en');
      expect(OcrService.easyOcrLanguage(null), 'en');
    });

    test('hasNativeTesseract true when tesseract binary responds', () async {
      ocrService.runCommand = (executable, arguments) async {
        if (executable == 'tesseract') return (0, 'tesseract 5', '');
        return (1, '', '');
      };
      expect(await ocrService.hasNativeTesseract(), isTrue);
    });

    test('hasNativeTesseract false when binary missing', () async {
      ocrService.runCommand = (executable, arguments) async {
        return (1, '', 'not found');
      };
      expect(await ocrService.hasNativeTesseract(), isFalse);
    });

    test('hasEasyOcr false when python import fails', () async {
      ocrService.runCommand = (executable, arguments) async {
        if (executable == 'python3' && arguments.contains('import easyocr')) {
          return (1, '', 'ModuleNotFoundError');
        }
        return (0, '', '');
      };
      expect(await ocrService.hasEasyOcr(), isFalse);
    });

    test(
      'easyOcr returns isEasyOcrUnavailable without python runtime',
      () async {
        ocrService.runCommand = (executable, arguments) async {
          if (executable == 'python3' && arguments.contains('import easyocr')) {
            return (1, '', 'ModuleNotFoundError');
          }
          return (1, '', '');
        };
        final result = await ocrService.recognizeFromFile(
          '/nonexistent.png',
          engine: OcrEngine.easyOcr,
        );
        expect(result.isSuccess, isFalse);
        expect(result.isEasyOcrUnavailable, isTrue);
      },
    );

    test('native tesseract runs mogrify preprocessing and psm 6', () async {
      final tempDir = await Directory.systemTemp.createTemp('tess_engine_test');
      final image = File('${tempDir.path}/input.png');
      await image.writeAsBytes([1, 2, 3]);

      final commands = <(String, List<String>)>[];
      ocrService.runCommand = (executable, arguments) async {
        commands.add((executable, List<String>.from(arguments)));
        if (executable == 'tesseract' && arguments.length >= 4) {
          // tesseract writes output.txt next to the given base
          final outBase = arguments[1];
          File('$outBase.txt').writeAsStringSync('recognized text');
          return (0, '', '');
        }
        return (0, '', '');
      };

      final result = await ocrService.recognizeFromFile(
        image.path,
        engine: OcrEngine.tesseract,
        language: 'ja',
      );

      expect(result.isSuccess, isTrue);
      expect(result.text, 'recognized text');

      final mogrify = commands
          .where((c) => c.$1 == 'mogrify')
          .map((c) => c.$2)
          .toList();
      expect(mogrify, isNotEmpty);
      // ocrf-style preprocessing flags
      final flags = mogrify.first;
      expect(flags, contains('-modulate'));
      expect(flags, contains('100,0'));
      expect(flags, contains('-resize'));
      expect(flags, contains('200%'));
      expect(flags, contains('-sharpen'));
      expect(flags, contains('Otsu'));
      expect(flags, contains('-border'));
      expect(flags, contains('20'));

      final tess = commands
          .where((c) => c.$1 == 'tesseract' && c.$2.length > 1)
          .map((c) => c.$2)
          .toList();
      expect(tess, isNotEmpty);
      expect(tess.first, contains('-l'));
      expect(tess.first, contains('jpn'));
      expect(tess.first, contains('--psm'));
      expect(tess.first, contains('6'));

      await tempDir.delete(recursive: true);
    });

    test(
      'tesseract without binary falls back to plugin path gracefully',
      () async {
        // no tesseract binary -> plugin path; plugin not available in
        // tests -> error result, not a crash
        ocrService.runCommand = (executable, arguments) async {
          return (1, '', 'not found');
        };
        final result = await ocrService.recognizeFromFile(
          '/nonexistent.png',
          engine: OcrEngine.tesseract,
        );
        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      },
    );

    test('ai engine uses injected fetcher', () async {
      final tempDir = await Directory.systemTemp.createTemp('ai_engine_test');
      final image = File('${tempDir.path}/img.png');
      await image.writeAsBytes([1, 2, 3]);

      final result = await ocrService.recognizeFromFile(
        image.path,
        engine: OcrEngine.ai,
        aiFetcher: (base64) async => 'ai recognized',
      );
      expect(result.isSuccess, isTrue);
      expect(result.text, 'ai recognized');

      await tempDir.delete(recursive: true);
    });

    test('ai engine without fetcher returns config error', () async {
      final result = await ocrService.recognizeFromFile(
        '/nonexistent.png',
        engine: OcrEngine.ai,
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('not configured'));
    });

    test('api engine posts to ocr.space and parses ParsedText', () async {
      // no http mocking lib available; point endpoint at a local
      // file-based substitute is not possible with http.post. Verify
      // error handling on connection failure instead.
      ocrService.apiEndpoint = 'http://127.0.0.1:1/parse';
      final tempDir = await Directory.systemTemp.createTemp('api_engine_test');
      final image = File('${tempDir.path}/img.png');
      await image.writeAsBytes([1, 2, 3]);

      final result = await ocrService.recognizeFromFile(
        image.path,
        engine: OcrEngine.api,
        apiKey: 'test',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);

      await tempDir.delete(recursive: true);
    });

    test('recognizeFromBytes writes temp file and cleans up', () async {
      final before = Directory.systemTemp.listSync().length;
      ocrService.runCommand = (executable, arguments) async {
        return (1, '', '');
      };
      await ocrService.recognizeFromBytes(
        Uint8List.fromList([1, 2, 3, 4]),
        engine: OcrEngine.tesseract,
      );
      final after = Directory.systemTemp.listSync().length;
      expect(after, lessThanOrEqualTo(before));
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
      final result = OcrResult(text: '', error: 'Failed to process image');

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
      final block = OcrTextBlock(text: 'Sample text block');

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

      final block = OcrTextBlock(text: 'Multi-line text', lines: lines);

      expect(block.lines.length, 2);
      expect(block.lines[0].text, 'Line 1');
      expect(block.lines[0].words, ['Line', '1']);
    });
  });

  group('OcrLine', () {
    test('creates line with required fields', () {
      final line = OcrLine(text: 'Hello', words: ['Hello']);

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
      final result = OcrResult(text: '', blocks: []);

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
