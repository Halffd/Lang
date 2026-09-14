import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects device shake events from the accelerometer stream and
/// reports them through [onShake]. Gravity is subtracted from each
/// sample and the net acceleration magnitude is compared against
/// [threshold]; a burst of consecutive spikes inside a short
/// window counts as one shake.
class ShakeDetector {
  /// Net acceleration (m/s^2) a sample must exceed to count as a
  /// spike. Devices are ~9.8 m/s^2 at rest.
  final double threshold;

  /// Spike count within the window that fires a shake.
  final int spikeCount;

  /// Time window for counting spikes.
  final Duration window;

  /// Called once per detected shake (debounced by [debounce]).
  final void Function() onShake;

  /// Minimum time between two shake callbacks.
  final Duration debounce;

  StreamSubscription<AccelerometerEvent>? _sub;
  final List<DateTime> _spikes = [];
  DateTime? _lastShake;

  ShakeDetector({
    this.threshold = 18.0,
    this.spikeCount = 3,
    this.window = const Duration(milliseconds: 700),
    this.debounce = const Duration(milliseconds: 1200),
    required this.onShake,
  });

  bool get isRunning => _sub != null;

  /// Starts listening to the accelerometer. Safe to call twice;
  /// the previous subscription is replaced. Plugin/sensor errors
  /// (desktop hosts, test environments) are swallowed: shake stays
  /// inert where no accelerometer exists.
  Future<void> start() async {
    stop();
    _spikes.clear();
    runZonedGuarded(
      () {
        final stream = accelerometerEventStream();
        _sub = stream.listen(
          _onSample,
          onError: (Object e) {
            _sub?.cancel();
            _sub = null;
            assert(() {
              debugPrint('ShakeDetector: accelerometer stream error: $e');
              return true;
            }());
          },
          cancelOnError: true,
        );
      },
      (e, st) {
        _sub?.cancel();
        _sub = null;
        assert(() {
          debugPrint('ShakeDetector: accelerometer unavailable: $e');
          return true;
        }());
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _spikes.clear();
  }

  void _onSample(AccelerometerEvent event) {
    // gravity is subtracted with a high-pass approximation: compare
    // against threshold + 9.8 so the resting baseline is ~0
    final net = _magnitude(event.x, event.y, event.z) - 9.8;
    if (net < threshold) return;

    final now = DateTime.now();
    _spikes.add(now);
    _prune(now);

    if (_spikes.length < spikeCount) return;

    final last = _lastShake;
    if (last != null && now.difference(last) < debounce) return;

    _lastShake = now;
    _spikes.clear();
    onShake();
  }

  void _prune(DateTime now) {
    _spikes.removeWhere((t) => now.difference(t) > window);
  }

  static double _magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);

  /// Feeds a synthetic sample; exposed for tests on hosts without
  /// accelerometer hardware.
  @visibleForTesting
  void debugSample(double x, double y, double z) =>
      _onSample(AccelerometerEvent(x, y, z, DateTime.now()));
}
