import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// OCR backends available in the OCR screen.
enum OcrEngine {
  /// Google ML Kit on-device recognizer.
  mlKit,

  /// Native tesseract binary with mogrify preprocessing (desktop),
  /// tesseract_ocr plugin on mobile.
  tesseract,

  /// EasyOCR through a local Python runtime.
  easyOcr,

  /// Gemini vision through the AI provider (injected callback).
  ai,

  /// Remote OCR HTTP API (OCR.space compatible by default).
  api,
}

/// Injectable command execution for tests. Returns
/// (exitCode, stdout, stderr).
typedef OcrCommandRunner =
    Future<(int, String, String)> Function(
      String executable,
      List<String> arguments,
    );

/// Hook the screen injects to run Gemini vision OCR without
/// coupling OcrService to the AI repository.
typedef AiImageTextFetcher = Future<String> Function(String imageBase64);

class OcrService {
  // Lazy: constructing ML Kit's recognizer needs the widget binding
  // (platform channels), so only create it when OCR actually runs.
  TextRecognizer? _mlKitRecognizer;
  bool _isInitialized = false;

  /// Injectable command runner for tests.
  OcrCommandRunner runCommand = _realRunner;

  /// Python executable used for the easyOcr engine.
  String pythonCommand = 'python3';

  static Future<(int, String, String)> _realRunner(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return (
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  /// Resolve a persisted engine name back to an [OcrEngine]
  /// (unknown/empty falls back to mlKit).
  static OcrEngine engineFromName(String? name) {
    return OcrEngine.values.where((e) => e.name == name).firstOrNull ??
        OcrEngine.mlKit;
  }

  /// Map an app language code to a tesseract language code.
  static String tesseractLanguage(String? appLanguage) {
    const map = {
      'ja': 'jpn',
      'zh': 'chi_sim',
      'ko': 'kor',
      'en': 'eng',
      'ru': 'rus',
      'uk': 'ukr',
      'bg': 'bul',
      'sr': 'srp_latn',
      'el': 'ell',
      'ka': 'kat',
      'hy': 'hye',
      'he': 'heb',
      'ar': 'ara',
      'hi': 'hin',
      'th': 'tha',
      'fr': 'fra',
      'es': 'SPA',
      'de': 'DEU',
      'it': 'ITA',
      'pt': 'POR',
      'vi': 'VIE',
    };
    return map[appLanguage] ?? 'eng';
  }

  /// Map an app language code to easyocr language codes.
  static String easyOcrLanguage(String? appLanguage) {
    const map = {
      'ja': 'ja',
      'zh': 'ch_sim',
      'ko': 'ko',
      'en': 'en',
      'ru': 'ru',
      'uk': 'uk',
      'bg': 'bg',
      'el': 'el',
      'hy': 'hy',
      'ar': 'ar',
      'hi': 'hi',
      'th': 'th',
      'fr': 'fr',
      'es': 'es',
      'de': 'de',
      'it': 'it',
      'pt': 'pt',
    };
    return map[appLanguage] ?? 'en';
  }

  TextRecognizer get _recognizer => _mlKitRecognizer ??= TextRecognizer();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void dispose() {
    _mlKitRecognizer?.close();
    _mlKitRecognizer = null;
  }

  /// Whether the tesseract binary is usable on this machine.
  Future<bool> hasNativeTesseract() async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return false;
    }
    try {
      final (code, _, _) = await runCommand('tesseract', ['--version']);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  /// Whether a python runtime with easyocr is usable.
  Future<bool> hasEasyOcr() async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return false;
    }
    try {
      final (code, _, _) = await runCommand(pythonCommand, [
        '-c',
        'import easyocr',
      ]);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<OcrResult> recognizeFromFile(
    String imagePath, {
    OcrEngine engine = OcrEngine.mlKit,
    String? language,
    String? apiKey,
    AiImageTextFetcher? aiFetcher,
    bool preprocess = true,
  }) async {
    switch (engine) {
      case OcrEngine.mlKit:
        return _recognizeWithMlKit(File(imagePath));
      case OcrEngine.tesseract:
        return _recognizeWithTesseract(
          imagePath,
          language: language,
          preprocess: preprocess,
        );
      case OcrEngine.easyOcr:
        return _recognizeWithEasyOcr(
          imagePath,
          language: language,
          preprocess: preprocess,
        );
      case OcrEngine.ai:
        return _recognizeWithAi(imagePath, aiFetcher);
      case OcrEngine.api:
        return _recognizeWithApi(imagePath, apiKey: apiKey);
    }
  }

  Future<OcrResult> recognizeFromBytes(
    Uint8List bytes, {
    OcrEngine engine = OcrEngine.mlKit,
    String? language,
    String? apiKey,
    AiImageTextFetcher? aiFetcher,
    bool preprocess = true,
  }) async {
    switch (engine) {
      case OcrEngine.mlKit:
        return _recognizeWithMlKitFromBytes(bytes);
      case OcrEngine.tesseract:
        return _bytesViaTempFile(
          bytes,
          (path) => _recognizeWithTesseract(
            path,
            language: language,
            preprocess: preprocess,
          ),
        );
      case OcrEngine.easyOcr:
        return _bytesViaTempFile(
          bytes,
          (path) => _recognizeWithEasyOcr(
            path,
            language: language,
            preprocess: preprocess,
          ),
        );
      case OcrEngine.ai:
        return _bytesViaTempFile(
          bytes,
          (path) => _recognizeWithAi(path, aiFetcher),
        );
      case OcrEngine.api:
        return _bytesViaTempFile(
          bytes,
          (path) => _recognizeWithApi(path, apiKey: apiKey),
        );
    }
  }

  /// Write [bytes] to a temp png and delegate to [run].
  Future<OcrResult> _bytesViaTempFile(
    Uint8List bytes,
    Future<OcrResult> Function(String path) run,
  ) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(bytes)}.png',
    );
    try {
      await tempFile.writeAsBytes(bytes);
      return await run(tempFile.path);
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<OcrResult> _recognizeWithMlKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);

      return OcrResult(
        text: recognizedText.text,
        blocks: recognizedText.blocks.map(_blockFromMlKit).toList(),
        confidence: _calculateConfidence(recognizedText.blocks),
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  OcrTextBlock _blockFromMlKit(TextBlock block) => OcrTextBlock(
    text: block.text,
    boundingBox: Rect(
      left: block.boundingBox.left,
      top: block.boundingBox.top,
      right: block.boundingBox.right,
      bottom: block.boundingBox.bottom,
    ),
    lines: block.lines
        .map(
          (line) => OcrLine(
            text: line.text,
            boundingBox: Rect(
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
            words: line.elements.map((e) => e.text).toList(),
          ),
        )
        .toList(),
  );

  Future<OcrResult> _recognizeWithMlKitFromBytes(Uint8List bytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: const Size(0, 0),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 0,
        ),
      );
      final recognizedText = await _recognizer.processImage(inputImage);

      return OcrResult(
        text: recognizedText.text,
        blocks: recognizedText.blocks.map(_blockFromMlKit).toList(),
        confidence: _calculateConfidence(recognizedText.blocks),
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  // --------------------------------------------------------------
  // Tesseract: native binary with mogrify preprocessing (desktop),
  // tesseract_ocr plugin elsewhere.
  // --------------------------------------------------------------

  Future<OcrResult> _recognizeWithTesseract(
    String imagePath, {
    String? language,
    bool preprocess = true,
  }) async {
    final tessLanguage = tesseractLanguage(language);

    if (await hasNativeTesseract()) {
      return _runNativeTesseract(imagePath, tessLanguage, preprocess);
    }

    // mobile / no binary: fall back to the plugin
    try {
      final result = await TesseractOcr.extractText(
        imagePath,
        config: OCRConfig(language: tessLanguage),
      );
      return OcrResult(text: result, blocks: [], confidence: 0.8);
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  /// Mirror of the ocrf shell script: mogrify preprocessing then
  /// tesseract with --psm 6 into a temp txt file.
  Future<OcrResult> _runNativeTesseract(
    String imagePath,
    String tessLanguage,
    bool preprocess,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp('tess_ocr');
    try {
      final workPath = '${tempDir.path}/input.png';
      await File(imagePath).copy(workPath);

      // preprocessing: grayscale, upscale 200%, sharpen, otsu
      // threshold, white border (per ocrf script)
      if (preprocess) {
        final (code, _, stderr) = await runCommand('mogrify', [
          '+repage',
          '-modulate',
          '100,0',
          '-resize',
          '200%',
          '-sharpen',
          '0x1',
          '-auto-threshold',
          'Otsu',
          '-bordercolor',
          'white',
          '-border',
          '20',
          '+repage',
          workPath,
        ]);
        if (code != 0) {
          // preprocessing is an optimization; continue with the
          // unprocessed image
          debugPrint('tesseract preprocess failed: $stderr');
        }
      }

      final outBase = '${tempDir.path}/output';
      final (code, _, stderr) = await runCommand('tesseract', [
        workPath,
        outBase,
        '-l',
        tessLanguage,
        '--psm',
        '6',
      ]);
      if (code != 0) {
        return OcrResult(text: '', error: 'tesseract failed: $stderr');
      }

      final outFile = File('$outBase.txt');
      if (!await outFile.exists()) {
        return OcrResult(text: '', error: 'tesseract produced no output');
      }
      final text = (await outFile.readAsString()).trim();
      return OcrResult(text: text, blocks: [], confidence: 0.8);
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------
  // EasyOCR: local python runtime
  // --------------------------------------------------------------

  Future<OcrResult> _recognizeWithEasyOcr(
    String imagePath, {
    String? language,
    bool preprocess = true,
  }) async {
    final easyLang = easyOcrLanguage(language);

    if (!await hasEasyOcr()) {
      return OcrResult(
        text: '',
        error:
            'EasyOCR requires a Python runtime with the easyocr package '
            '(pip install easyocr). Use ML Kit or Tesseract for local OCR.',
        isEasyOcrUnavailable: true,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('easy_ocr');
    try {
      var workPath = imagePath;

      // same preprocessing as tesseract (helps recognition a lot)
      if (preprocess) {
        final preprocessedPath = '${tempDir.path}/input.png';
        await File(imagePath).copy(preprocessedPath);
        final (code, _, stderr) = await runCommand('mogrify', [
          '+repage',
          '-modulate',
          '100,0',
          '-resize',
          '200%',
          '-sharpen',
          '0x1',
          '-auto-threshold',
          'Otsu',
          '-bordercolor',
          'white',
          '-border',
          '20',
          '+repage',
          preprocessedPath,
        ]);
        if (code == 0) {
          workPath = preprocessedPath;
        } else {
          debugPrint('easyocr preprocess failed: $stderr');
        }
      }

      // reader.recognize prints JSON lines; we parse the text field
      final script =
          '''
import json, sys
import easyocr
reader = easyocr.Reader(['$easyLang'], gpu=False, verbose=False)
result = reader.recognize(r'$workPath', detail=0, paragraph=True)
sys.stdout.write(json.dumps(result))
''';
      final (code, stdout_, stderr) = await runCommand(pythonCommand, [
        '-c',
        script,
      ]);
      if (code != 0) {
        return OcrResult(text: '', error: 'easyocr failed: $stderr');
      }

      try {
        final decoded = jsonDecode(stdout_.trim());
        if (decoded is List) {
          final text = decoded.whereType<String>().join('\n').trim();
          return OcrResult(text: text, blocks: [], confidence: 0.9);
        }
        return OcrResult(text: '', error: 'easyocr unexpected output');
      } catch (e) {
        return OcrResult(text: '', error: 'easyocr output parse: $e');
      }
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------
  // AI (Gemini vision) through injected fetcher
  // --------------------------------------------------------------

  Future<OcrResult> _recognizeWithAi(
    String imagePath,
    AiImageTextFetcher? aiFetcher,
  ) async {
    if (aiFetcher == null) {
      return OcrResult(
        text: '',
        error: 'AI OCR is not configured (no AI provider available)',
      );
    }
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final text = await aiFetcher(base64Image);
      return OcrResult(text: text.trim(), blocks: [], confidence: 0.95);
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }

  // --------------------------------------------------------------
  // Remote OCR API (OCR.space compatible)
  // --------------------------------------------------------------

  /// OCR.space endpoint; overridable for self-hosted compatible APIs.
  String apiEndpoint = 'https://api.ocr.space/parse/image';

  Future<OcrResult> _recognizeWithApi(
    String imagePath, {
    String? apiKey,
  }) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'apikey': apiKey ?? 'helloworld'},
        body: {
          'base64Image': 'data:image/png;base64,$base64Image',
          'OCREngine': '2',
          'scale': 'true',
          'isTable': 'true',
        },
      );

      if (response.statusCode != 200) {
        return OcrResult(
          text: '',
          error: 'OCR API failed (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = data['ParsedResults'] as List?;
      if (parsed == null || parsed.isEmpty) {
        return OcrResult(
          text: '',
          error:
              'OCR API returned no results '
              '(${data['IsErroredOnProcessing'] == true ? data['ErrorMessage'] : 'empty'})',
        );
      }
      final text = parsed
          .map((e) => ((e as Map)['ParsedText'] ?? '').toString())
          .join('\n')
          .trim();
      return OcrResult(text: text, blocks: [], confidence: 0.9);
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
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
      case OcrEngine.ai:
        return 'AI';
      case OcrEngine.api:
        return 'API';
    }
  }

  String getEngineDescription(OcrEngine engine) {
    switch (engine) {
      case OcrEngine.mlKit:
        return 'Google ML Kit - Fast and accurate, supports multiple languages';
      case OcrEngine.tesseract:
        return 'Tesseract - The open source OCR engine, excellent for documents';
      case OcrEngine.easyOcr:
        return 'EasyOCR - An AI-powered engine, great for complex images (requires backend)';
      case OcrEngine.ai:
        return 'AI - Gemini vision extraction through the configured AI provider';
      case OcrEngine.api:
        return 'API - Remote OCR.space-compatible HTTP endpoint';
    }
  }
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

  OcrTextBlock({required this.text, this.boundingBox, this.lines = const []});
}

class OcrLine {
  final String text;
  final Rect? boundingBox;
  final List<String> words;

  OcrLine({required this.text, this.boundingBox, this.words = const []});
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

  /// Width as an absolute value (handles inverted coordinates).
  double get width => (right - left).abs();

  /// Height as an absolute value (handles inverted coordinates).
  double get height => (bottom - top).abs();
}
