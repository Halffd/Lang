import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lang/core/services/live_ocr/live_ocr_result.dart';
import 'package:lang/core/services/live_ocr/live_ocr_stability_gate.dart';
import 'package:lang/data/services/ocr_service.dart';

/// What one capture step of the live-OCR loop produced.
///
/// [bytes] are the raw PNG bytes of the captured frame; null when the
/// capture failed.
class LiveOcrFrame {
  final Uint8List? bytes;

  const LiveOcrFrame({this.bytes});

  bool get isEmpty => bytes == null;
}

/// Captures a single frame for the live-OCR loop.
///
/// Implemented over [ScreenshotService] in production; injected in
/// tests so the loop can run without a display server.
typedef LiveOcrFrameSource = Future<LiveOcrFrame> Function();

/// Recognizes text in a frame.
///
/// Implemented over [OcrService] in production; injected in tests.
typedef LiveOcrRecognizer = Future<OcrResult> Function(Uint8List bytes);

/// Translates recognized text.
typedef LiveOcrTranslator = Future<String> Function(String text);

/// How the live-OCR loop selects the region it reads.
enum LiveOcrCaptureTarget {
  /// The region the user last selected interactively.
  previousRegion,

  /// The whole screen.
  fullscreen,
}

/// The messages the live-OCR loop reports its own failures with.
///
/// Injected so the service layer stays free of [BuildContext] while
/// the user still sees the failures in their own language.
class LiveOcrErrorMessages {
  /// Shown when the loop has no capture source or recognizer.
  final String notConfigured;

  /// Shown when the screen capture produced no frame.
  final String captureFailed;

  /// Shown when the OCR backend failed without a message of its own.
  final String ocrFailed;

  const LiveOcrErrorMessages({
    this.notConfigured = 'Live OCR is not configured',
    this.captureFailed = 'Screen capture failed',
    this.ocrFailed = 'OCR failed',
  });
}

/// Continuous screen capture -> OCR -> translation loop.
///
/// The loop captures a frame on a fixed interval, recognizes it, and
/// feeds the reading through a [LiveOcrStabilityGate]. Only text that
/// passes the gate is translated, which keeps the translation API from
/// being called on every jittery frame and stops the output from
/// flickering.
///
/// Translation runs concurrently with capture: a slow translation never
/// stalls the loop, and a newer stable reading supersedes an older
/// in-flight one when it finally lands.
class LiveOcrService extends ChangeNotifier {
  LiveOcrService();

  /// The capture source. Null until the controller wires it up.
  LiveOcrFrameSource? frameSource;

  /// The recognizer. Null until the controller wires it up.
  LiveOcrRecognizer? recognizer;

  /// The translator. Null until the controller wires it up.
  LiveOcrTranslator? translator;

  /// The messages the loop reports its own failures with.
  ///
  /// The service has no [BuildContext], so the controller hands it
  /// localized strings; the defaults are the English originals.
  LiveOcrErrorMessages errorMessages = LiveOcrErrorMessages();

  /// Interval between capture attempts.
  Duration interval = const Duration(seconds: 2);

  /// Which region the loop reads.
  LiveOcrCaptureTarget target = LiveOcrCaptureTarget.previousRegion;

  /// The stability gate. Its [LiveOcrStabilityGate.requiredRepeats] is
  /// driven by the user setting.
  final LiveOcrStabilityGate gate = LiveOcrStabilityGate();

  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  int _epoch = 0;

  LiveOcrResult? _result;
  String? _lastError;

  /// The text whose translation is currently installed in [_result].
  String? _translatedText;

  /// The text whose translation is currently in flight.
  String? _translationInFlightText;

  /// Completes when the in-flight translation finishes.
  ///
  /// Tests and callers that need the translated text to be installed
  /// await this instead of guessing at a delay.
  Future<void>? _pendingTranslation;

  /// Completes when the current in-flight translation finishes, or
  /// immediately when no translation is in flight.
  Future<void> get translationPending =>
      _pendingTranslation ?? Future<void>.value();

  /// The most recent pass result.
  LiveOcrResult? get result => _result;

  /// The last error message, or null.
  String? get lastError => _lastError;

  /// Whether the loop is running.
  bool get isRunning => _running;

  /// The text currently considered stable and worth showing.
  String? get stableText {
    final r = _result;
    if (r == null || !r.stable || !r.hasText) return null;
    return r.sourceText;
  }

  /// The translation of the stable text, when it has arrived.
  String? get stableTranslation {
    final r = _result;
    if (r == null || !r.stable) return null;
    // the translation belongs to the text it was made from
    if (_translatedText != gate.normalize(r.sourceText)) return null;
    return r.translation;
  }

  /// Starts the loop. Does nothing when it is already running.
  void start() {
    if (_running) return;
    _running = true;
    _lastError = null;
    _epoch++;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
    // capture immediately so the first reading does not wait a whole
    // interval
    unawaited(_tick());
    notifyListeners();
  }

  /// Restarts the capture timer with the current [interval].
  ///
  /// A running [Timer.periodic] keeps its original period, so a changed
  /// interval only takes effect after a restart. Does nothing when the
  /// loop is not running.
  void restartTimer() {
    if (!_running) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  /// Stops the loop. In-flight work is abandoned: its results are
  /// discarded when it lands, and the current reading is dropped so the
  /// overlay stops showing text that is no longer being read.
  ///
  /// Stopping always clears the reading, even when the loop was not
  /// running: the reading belongs to the loop, not to the service.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    // bump the epoch so a pending translation cannot resurrect stale text
    _epoch++;
    _busy = false;
    gate.reset();
    _result = null;
    _translatedText = null;
    _translationInFlightText = null;
    notifyListeners();
  }

  /// Clears the current result and error, leaving the loop state alone.
  void clear() {
    _result = null;
    _lastError = null;
    _translatedText = null;
    _translationInFlightText = null;
    gate.reset();
    notifyListeners();
  }

  /// Runs one capture -> OCR -> (maybe translate) pass.
  ///
  /// Exposed for tests and for a manual "refresh now" action.
  Future<void> tick() => _tick();

  Future<void> _tick() async {
    if (_busy) return;
    final source = frameSource;
    final recognize = recognizer;
    if (source == null || recognize == null) {
      _setError(errorMessages.notConfigured);
      return;
    }
    _busy = true;
    final epoch = _epoch;
    try {
      final frame = await source();
      if (epoch != _epoch) return;
      if (frame.isEmpty || frame.bytes == null) {
        _setError(errorMessages.captureFailed);
        return;
      }
      final recognized = await recognize(frame.bytes!);
      if (epoch != _epoch) return;
      if (!recognized.isSuccess) {
        _setError(recognized.error ?? errorMessages.ocrFailed);
        return;
      }
      _installReading(recognized, epoch);
    } catch (e) {
      if (epoch != _epoch) return;
      _setError(e.toString());
    } finally {
      if (epoch == _epoch) _busy = false;
    }
  }

  /// Publishes a fresh reading and starts its translation when the
  /// reading is stable.
  void _installReading(OcrResult recognized, int epoch) {
    final text = recognized.text.trim();
    final stable = gate.add(text);
    // compare on the normalized form: a reading that only differs in
    // whitespace is the same text for the gate, so it must keep its
    // translation instead of triggering a new one
    final key = gate.normalize(text);
    final previous = _result;
    final sameText =
        previous != null && gate.normalize(previous.sourceText) == key;

    _lastError = null;
    _result = LiveOcrResult(
      sourceText: text,
      confidence: recognized.confidence,
      stable: stable,
      repeatCount: gate.repeatCount,
      timestamp: DateTime.now(),
      // a translation belongs to the text it was made from: keep it
      // only while the source text is unchanged
      translation: sameText ? previous.translation : null,
    );
    if (!sameText) _translatedText = null;
    notifyListeners();

    if (!stable || text.isEmpty) return;
    if (_translatedText == key) return;
    if (_translationInFlightText == key) return;
    // translation runs beside the capture loop, never blocking it
    _pendingTranslation = _translateStableText(text, key, epoch);
    unawaited(_pendingTranslation!);
  }

  /// Translates [text] in the background and installs the result when
  /// it lands, unless a newer reading has superseded it.
  ///
  /// [key] is the normalized form of [text]; it identifies the text
  /// across whitespace-only differences.
  Future<void> _translateStableText(String text, String key, int epoch) async {
    final translate = translator;
    if (translate == null) return;
    _translationInFlightText = key;
    try {
      final translated = await translate(text);
      if (epoch != _epoch) return;
      final current = _result;
      // the reading moved on while the translation was in flight
      if (current == null || gate.normalize(current.sourceText) != key) return;
      _result = current.copyWith(translation: translated);
      _translatedText = key;
      notifyListeners();
    } catch (e) {
      if (epoch != _epoch) return;
      // keep the source text; the next stable pass retries
      _setError(e.toString());
    } finally {
      if (_translationInFlightText == key) _translationInFlightText = null;
    }
  }

  void _setError(String message) {
    if (_lastError == message) return;
    _lastError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
