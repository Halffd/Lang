// End-to-end verification: drives the REAL OcrService against the REAL
// native tesseract binary on Linux, proving the platform fallback
// actually produces text (not just that it does not hang).
//
// The test is skipped when no native tesseract binary is present.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lang/data/services/ocr_service.dart';

/// Render "HELLO OCR WORLD" into a PNG the OCR engine can read.
String _writeProbeImage(String path) {
  final image = img.Image(1000, 240);
  img.fill(image, img.getColor(255, 255, 255));
  img.drawString(
    image,
    img.arial_48,
    40,
    80,
    'HELLO OCR WORLD',
    color: img.getColor(0, 0, 0),
  );
  File(path).writeAsBytesSync(img.encodePng(image));
  return path;
}

void main() {
  test('the Linux fallback recognizes real text with native tesseract', () async {
    // This test covers the desktop fallback, so it only makes sense
    // where ML Kit cannot run.
    if (OcrService.isMlKitAvailable) {
      markTestSkipped('ML Kit is available here; this covers the desktop path');
      return;
    }

    // Locate a tesseract binary.
    final probe = await Process.run('which', ['tesseract']);
    if (probe.exitCode != 0) {
      markTestSkipped('no native tesseract binary on this machine');
      return;
    }
    expect((probe.stdout as String).trim(), isNotEmpty);

    final tmpDir = await Directory.systemTemp.createTemp('ocr_e2e_');
    final imagePath = _writeProbeImage('${tmpDir.path}/probe.png');
    expect(File(imagePath).existsSync(), isTrue);

    final service = OcrService();

    // 1. The platform default on Linux must be tesseract, not mlKit.
    expect(OcrService.resolveEngine(null), OcrEngine.tesseract);
    expect(OcrService.engineFromName(''), OcrEngine.tesseract);

    // 2. A persisted "mlKit" choice must fall back to tesseract when used.
    expect(OcrService.engineFromName('mlKit'), OcrEngine.mlKit);
    expect(
      OcrService.resolveEngine(OcrService.engineFromName('mlKit')),
      OcrEngine.tesseract,
    );
    expect(OcrService.resolveEngine(OcrEngine.mlKit), OcrEngine.tesseract);

    // 3. Asking for mlKit explicitly still yields real text, because the
    //    fallback rewrites it to tesseract.
    final result = await service.recognizeFromFile(
      imagePath,
      engine: OcrEngine.mlKit,
      preprocess: false,
    );

    // ignore: avoid_print
    print('RESULT success=${result.isSuccess} text=${result.text}');

    expect(result.isSuccess, isTrue, reason: 'error was: ${result.error}');
    expect(result.text.toUpperCase(), contains('HELLO OCR WORLD'));

    service.dispose();
    await tmpDir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
