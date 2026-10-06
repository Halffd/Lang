// Test configuration run before every test file (flutter_test standard hook).
//
// Installs FuzzyGoldenComparator so `matchesGoldenFile` tolerates
// antialiasing noise instead of failing on a single pixel, and writes
// master/test/masked/isolated diff images on failure.
//
// Threshold knobs (env, same pattern as WIKTIONARY_LIVE):
//   GOLDEN_MAX_DIFF_RATE  fraction of pixels allowed to differ (default 0.002)
//   GOLDEN_CHANNEL_DELTA   per-channel tolerance 0..255 (default 12)
//
// Update baselines deliberately:
//   flutter test --update-goldens test/ui_golden_test.dart
// then review the changed PNGs before committing.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'golden/fuzzy_golden_comparator.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = FuzzyGoldenComparator.fromCurrent();
  await testMain();
}
