import 'dart:typed_data';

import 'package:lang/core/services/live_ocr/live_ocr_service.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/translation_model.dart';

/// Binds [LiveOcrService] to the app's capture, OCR and translation
/// services.
///
/// The settings are read from [AppState] at call time, so a changed
/// setting takes effect on the next pass without rebuilding the
/// adapter.
class LiveOcrAdapter {
  LiveOcrAdapter({
    required this.appState,
    required this.screenshotService,
    required this.ocrService,
    required this.translationService,
  });

  /// The live settings the loop follows.
  final AppState appState;
  final ScreenshotService screenshotService;
  final OcrService ocrService;
  final TranslationService translationService;

  /// Language the recognized text is in. 'auto' and an empty setting
  /// follow the app learning language.
  String get sourceLanguage {
    final lang = appState.ocrLanguage;
    if (lang.isEmpty || lang == 'auto') return appState.learningLanguage;
    return lang;
  }

  /// The OCR engine to use. The `ai` engine is not usable here — it
  /// needs the AI provider from the search screen's context — so it
  /// falls back to the platform default. [OcrService.resolveEngine]
  /// then moves `mlKit` off desktop, where it has no implementation.
  OcrEngine resolveEngine() {
    final engine = OcrService.engineFromName(appState.ocrEngine);
    if (engine == OcrEngine.ai) {
      return OcrService.resolveEngine(null);
    }
    return OcrService.resolveEngine(engine);
  }

  /// The capture kind the current target maps to.
  ScreenshotKind get captureKind => appState.liveOcrUseFullscreen
      ? ScreenshotKind.fullscreen
      : ScreenshotKind.previousRegion;

  /// Captures one frame.
  Future<LiveOcrFrame> capture() async {
    final bytes = await screenshotService.captureTransient(captureKind);
    if (bytes == null) return const LiveOcrFrame();
    return LiveOcrFrame(bytes: bytes);
  }

  /// Recognizes the text in [bytes].
  Future<OcrResult> recognize(Uint8List bytes) async {
    final endpoint = appState.ocrApiEndpoint;
    if (endpoint.isNotEmpty) ocrService.apiEndpoint = endpoint;
    return ocrService.recognizeFromBytes(
      bytes,
      engine: resolveEngine(),
      language: sourceLanguage,
      apiKey: appState.ocrApiKey,
    );
  }

  /// Translates [text] into the app learning language.
  Future<String> translate(String text) async {
    final result = await translationService.translate(
      TranslationRequest(
        sourceText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: appState.learningLanguage,
      ),
    );
    return result.fullTranslation;
  }
}
