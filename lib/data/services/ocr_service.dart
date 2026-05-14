import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

enum OcrEngine { mlKit, tesseract, easyOcr }

class OcrService {
  final TextRecognizer _mlKitRecognizer = TextRecognizer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void dispose() {
    _mlKitRecognizer.close();
  }

  Future<OcrResult> recognizeFromFile(
    String imagePath, {
    OcrEngine engine = OcrEngine.mlKit,
    String? language,
  }) async {
    switch (engine) {
      case OcrEngine.mlKit:
        return _recognizeWithMlKit(File(imagePath));
      case OcrEngine.tesseract:
        return _recognizeWithTesseract(imagePath, language: language);
      case OcrEngine.easyOcr:
        return _recognizeWithEasyOcr(imagePath, language: language);
    }
  }

  Future<OcrResult> recognizeFromBytes(
    Uint8List bytes, {
    OcrEngine engine = OcrEngine.mlKit,
    String? language,
  }) async {
    switch (engine) {
      case OcrEngine.mlKit:
        return _recognizeWithMlKitFromBytes(bytes);
      case OcrEngine.tesseract:
        return _recognizeWithTesseractFromBytes(bytes, language: language);
      case OcrEngine.easyOcr:
        return _recognizeWithEasyOcrFromBytes(bytes, language: language);
    }
  }

  Future<OcrResult> _recognizeWithMlKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _mlKitRecognizer.processImage(inputImage);

      return OcrResult(
        text: recognizedText.text,
        blocks: recognizedText.blocks
            .map((block) => OcrTextBlock(
                  text: block.text,
                  boundingBox: block.boundingBox,
                  lines: block.lines
                      .map((line) => OcrLine(
                            text: line.text,
                            boundingBox: line.boundingBox,
                            words: line.elements.map((e) => e.text).toList(),
                          ))
                      .toList(),
                ))
            .toList(),
        confidence: _calculateConfidence(recognizedText.blocks),
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  Future<OcrResult> _recognizeWithMlKitFromBytes(Uint8List bytes) async {
    try {
      final inputImage = InputImage.fromBytes(bytes: bytes);
      final recognizedText = await _mlKitRecognizer.processImage(inputImage);

      return OcrResult(
        text: recognizedText.text,
        blocks: recognizedText.blocks
            .map((block) => OcrTextBlock(
                  text: block.text,
                  boundingBox: block.boundingBox,
                  lines: block.lines
                      .map((line) => OcrLine(
                            text: line.text,
                            boundingBox: line.boundingBox,
                            words: line.elements.map((e) => e.text).toList(),
                          ))
                      .toList(),
                ))
            .toList(),
        confidence: _calculateConfidence(recognizedText.blocks),
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  Future<OcrResult> _recognizeWithTesseract(String imagePath, {String? language}) async {
    try {
      final tessLanguage = language ?? 'eng';

      final result = await TesseractOcr.extractText(
        imagePath,
        config: OCRConfig(language: tessLanguage),
      );

      return OcrResult(
        text: result,
        blocks: [],
        confidence: 0.8,
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  Future<OcrResult> _recognizeWithTesseractFromBytes(Uint8List bytes, {String? language}) async {
    try {
      final tessLanguage = language ?? 'eng';

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      final result = await TesseractOcr.extractText(
        tempFile.path,
        config: OCRConfig(language: tessLanguage),
      );

      tempFile.deleteSync();

      return OcrResult(
        text: result,
        blocks: [],
        confidence: 0.8,
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  Future<OcrResult> _recognizeWithEasyOcr(String imagePath, {String? language}) async {
    try {
      final result = await compute(_easyOcrIsolate, _EasyOcrParams(
        imagePath: imagePath,
        language: language ?? 'en',
      ));

      return result;
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  Future<OcrResult> _recognizeWithEasyOcrFromBytes(Uint8List bytes, {String? language}) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_ocr_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      final result = await _recognizeWithEasyOcr(tempFile.path, language: language);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return result;
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  static Future<OcrResult> _easyOcrIsolate(_EasyOcrParams params) async {
    // EasyOCR requires Python runtime with easyocr package installed
    // This is a placeholder that uses MLKit as fallback since there's no direct EasyOCR Flutter package
    // For actual EasyOCR support, you would need to use:
    // 1. A Python FFI approach
    // 2. A backend API that wraps EasyOCR
    // 3. Native platform channels

    // For now, return a message indicating EasyOCR needs backend setup
    return OcrResult(
      text: '',
      error: 'EasyOCR requires a Python backend or API. Use MLKit or Tesseract for local OCR.',
      isEasyOcrUnavailable: true,
    );
  }

  double _calculateConfidence(List<TextBlock> blocks) {
    if (blocks.isEmpty) return 0.0;

    double totalConfidence = 0;
    int count = 0;

    for (final block in blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          if (element.confidence != null) {
            totalConfidence += element.confidence!;
            count++;
          }
        }
      }
    }

    return count > 0 ? totalConfidence / count : 0.0;
  }

  String getEngineName(OcrEngine engine) {
    switch (engine) {
      case OcrEngine.mlKit:
        return 'ML Kit';
      case OcrEngine.tesseract:
        return 'Tesseract';
      case OcrEngine.easyOcr:
        return 'EasyOCR';
    }
  }

  String getEngineDescription(OcrEngine engine) {
    switch (engine) {
      case OcrEngine.mlKit:
        return 'Google ML Kit - Fast and accurate, supports multiple languages';
      case OcrEngine.tesseract:
        return 'Tesseract - Open source OCR, excellent for documents';
      case OcrEngine.easyOcr:
        return 'EasyOCR - AI-powered, great for complex images (requires backend)';
    }
  }
}

class _EasyOcrParams {
  final String imagePath;
  final String language;

  _EasyOcrParams({required this.imagePath, required this.language});
}

class OcrResult {
  final String text;
  final List<OcrTextBlock> blocks;
  final double confidence;
  final String? error;
  final bool isEasyOcrUnavailable;

  OcrResult({
    required this.text,
    this.blocks = const [],
    this.confidence = 0.0,
    this.error,
    this.isEasyOcrUnavailable = false,
  });

  bool get isSuccess => error == null && !isEasyOcrUnavailable;
}

class OcrTextBlock {
  final String text;
  final Rect? boundingBox;
  final List<OcrLine> lines;

  OcrTextBlock({
    required this.text,
    this.boundingBox,
    this.lines = const [],
  });
}

class OcrLine {
  final String text;
  final Rect? boundingBox;
  final List<String> words;

  OcrLine({
    required this.text,
    this.boundingBox,
    this.words = const [],
  });
}

class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}