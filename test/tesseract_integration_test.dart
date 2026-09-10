import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/ocr_service.dart';

// integration: runs the real tesseract binary + mogrify when
// available, skips otherwise (CI boxes without the tools)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native tesseract real smoke', () async {
    final service = OcrService();
    if (!await service.hasNativeTesseract()) {
      return; // no tesseract binary: skip
    }

    // generate a text image with ImageMagick when available
    final tempDir = await Directory.systemTemp.createTemp('tess_smoke');
    final imagePath = '${tempDir.path}/ocr_test.png';
    try {
      final gen = await Process.run('convert', [
        '-size',
        '400x80',
        'xc:white',
        '-font',
        'DejaVu-Sans',
        '-pointsize',
        '28',
        '-fill',
        'black',
        '-annotate',
        '+10+50',
        'Hello OCR 123',
        imagePath,
      ]);
      if (gen.exitCode != 0 || !File(imagePath).existsSync()) {
        return; // no ImageMagick: skip
      }

      final result = await service.recognizeFromFile(
        imagePath,
        engine: OcrEngine.tesseract,
        language: 'en',
      );

      expect(result.isSuccess, isTrue);
      expect(result.text, contains('Hello'));
      expect(result.text, contains('123'));
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });
}
