import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lang/core/services/live_ocr/live_ocr_adapter.dart';
import 'package:lang/core/services/live_ocr/live_ocr_service.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/data/datasources/local_translation_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';

/// Owns the live-OCR loop and keeps it in sync with the app settings.
///
/// The loop reads the OCR engine, the OCR source language, the capture
/// interval and the stability threshold from [AppState], so changing a
/// setting takes effect on the next pass without restarting the app.
class LiveOcrController extends ChangeNotifier {
  LiveOcrController({LiveOcrService? service, Future<bool> Function()? isSupported})
    : service = service ?? LiveOcrService(),
      _supportCheck = isSupported {
    this.service.addListener(_onServiceChanged);
  }

  /// The loop this controller drives.
  final LiveOcrService service;

  AppState? _appState;
  LiveOcrAdapter? _adapter;
  Timer? _settingsTimer;
  bool _unsupported = false;

  /// Overrides the platform probe. Null means "ask the screenshot
  /// service"; tests set it to exercise both outcomes.
  final Future<bool> Function()? _supportCheck;

  /// Whether this machine cannot capture the screen, so the live-OCR
  /// loop cannot run here.
  bool get isUnsupported => _unsupported;

  /// The most recent error, or null.
  String? get lastError => service.lastError;

  /// Whether the loop is running.
  bool get isRunning => service.isRunning;

  /// The stable source text, or null.
  String? get stableText => service.stableText;

  /// The stable translation, or null.
  String? get stableTranslation => service.stableTranslation;

  /// Binds the controller to the app state and starts or stops the
  /// loop to match the persisted "live OCR enabled" setting.
  void attach({
    required AppState appState,
    required OcrService ocrService,
    required TranslationService translationService,
    LiveOcrAdapter? adapter,
    LiveOcrErrorMessages? errorMessages,
  }) {
    _appState = appState;
    _adapter =
        adapter ??
        LiveOcrAdapter(
          appState: appState,
          screenshotService: ScreenshotService.instance,
          ocrService: ocrService,
          translationService: translationService,
        );
    if (errorMessages != null) service.errorMessages = errorMessages;
    _wireCallbacks();
    _reconfigure();
    appState.addListener(_onAppStateChanged);
    // probe the platform up front so the settings screen can say the
    // loop cannot run here instead of the toggle doing nothing
    unawaited(_checkSupport());
    if (appState.liveOcrEnabled) {
      // the capture tools are desktop-only: on mobile there is nothing
      // to read, so the loop must not spin
      unawaited(_startWhenSupported());
    }
  }

  /// Probes whether this machine can capture the screen and records
  /// the answer.
  Future<void> _checkSupport() async {
    _setUnsupported(!await isSupported());
  }

  /// Starts the loop once the machine is known to support screen
  /// capture.
  Future<void> _startWhenSupported() async {
    if (!await isSupported()) {
      _setUnsupported(true);
      return;
    }
    _setUnsupported(false);
    start();
  }

  void _setUnsupported(bool value) {
    if (_unsupported == value) return;
    _unsupported = value;
    notifyListeners();
  }

  /// Starts the loop.
  void start() {
    _reconfigure();
    service.start();
    notifyListeners();
  }

  /// Whether this machine can capture the screen at all.
  ///
  /// The capture tools are desktop-only; on mobile the live-OCR loop
  /// has nothing to read.
  Future<bool> isSupported() async {
    final check = _supportCheck;
    if (check != null) return await check();
    return await ScreenshotService.instance.detectPlatform() !=
        ScreenshotPlatform.unsupported;
  }

  /// Stops the loop.
  void stop() {
    service.stop();
    notifyListeners();
  }

  /// Starts or stops the loop to match [AppState.liveOcrEnabled].
  void applyEnabledSetting() {
    final enabled = _appState?.liveOcrEnabled ?? false;
    if (enabled && !service.isRunning) {
      // the capture tools are desktop-only: on mobile there is nothing
      // to read, so the loop must not spin
      unawaited(_startWhenSupported());
    } else if (!enabled && service.isRunning) {
      stop();
    }
  }

  void _onAppStateChanged() {
    // The settings that affect the running loop are applied on the
    // next pass rather than immediately: a slider drag must not restart
    // the loop on every pixel.
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 400), () {
      _reconfigure();
      applyEnabledSetting();
    });
  }

  /// Applies the current app settings to the loop.
  void _reconfigure() {
    final appState = _appState;
    if (appState == null) return;
    final interval = Duration(seconds: appState.liveOcrIntervalSec);
    // a running timer keeps its original period: restart it so the
    // new interval takes effect
    final periodChanged = service.interval != interval;
    service.interval = interval;
    service.gate.requiredRepeats = appState.liveOcrRequiredRepeats;
    service.target = appState.liveOcrUseFullscreen
        ? LiveOcrCaptureTarget.fullscreen
        : LiveOcrCaptureTarget.previousRegion;
    // the translation service is built once, so the provider choice
    // has to be pushed into it when the setting changes
    _adapter?.translationService.provider = appState.translationProvider;
    if (periodChanged && service.isRunning) {
      service.restartTimer();
    }
  }

  /// Rebuilds the capture/recognize/translate callbacks.
  void _wireCallbacks() {
    final adapter = _adapter;
    if (adapter == null) return;
    service.frameSource = adapter.capture;
    service.recognizer = adapter.recognize;
    service.translator = adapter.translate;
  }

  void _onServiceChanged() => notifyListeners();

  @override
  void dispose() {
    _settingsTimer?.cancel();
    _appState?.removeListener(_onAppStateChanged);
    service.removeListener(_onServiceChanged);
    service.dispose();
    super.dispose();
  }
}

/// Builds the translation service the live-OCR loop uses.
TranslationService buildLiveOcrTranslationService({
  required AppState appState,
  String? geminiApiKey,
}) => TranslationService(
  localService: LocalTranslationService(),
  geminiApiKey: (geminiApiKey?.isNotEmpty ?? false) ? geminiApiKey : null,
  provider: appState.translationProvider,
);
