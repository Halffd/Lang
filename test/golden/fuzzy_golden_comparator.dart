import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError, listEquals;
import 'package:flutter_test/flutter_test.dart';

/// Golden comparator with a tunable pixel-diff threshold.
///
/// The stock [LocalFileComparator] fails on a single differing pixel. That is
/// too strict to be useful across SDK or font upgrades, where text
/// antialiasing shifts by one or two channel values and every golden goes
/// red at once. This comparator:
///
///  * counts a pixel as differing only when a channel moved by more than
///    [channelDelta],
///  * fails only when more than [maxDiffRate] of the image differs. A moved
///    or recolored widget is thousands of pixels and still trips immediately;
///    sub-visual noise does not.
///
/// On failure it writes master, test, masked-diff and isolated-diff images
/// into a `failures/` directory beside the golden (inherited behavior from
/// [LocalComparisonOutput]), so the regression is visible without re-running
/// anything.
///
/// Tune via environment variables (same pattern as WIKTIONARY_LIVE):
///
///  * `GOLDEN_MAX_DIFF_RATE` - fraction of pixels allowed to differ
///    (default 0.002, i.e. 0.2%)
///  * `GOLDEN_CHANNEL_DELTA` - per-channel tolerance, 0..255 (default 12)
///
/// Re-baseline deliberately with `flutter test --update-goldens` and review
/// the changed PNGs before committing them.
class FuzzyGoldenComparator extends LocalFileComparator {
  FuzzyGoldenComparator(
    super.testFile, {
    this.maxDiffRate = defaultMaxDiffRate,
    this.channelDelta = defaultChannelDelta,
  });

  /// Fraction of pixels allowed to differ before the golden fails.
  static const double defaultMaxDiffRate = 0.002;

  /// Per-channel tolerance: a pixel counts as differing only when a channel
  /// moved by more than this.
  static const int defaultChannelDelta = 12;

  /// Wraps the currently installed comparator, keeping its basedir, with
  /// thresholds from the environment.
  ///
  /// The constructor derives the basedir from a test file path, so the
  /// existing basedir is turned back into a synthetic file inside it.
  factory FuzzyGoldenComparator.fromCurrent() {
    final current = goldenFileComparator;
    final Uri testFile = current is LocalFileComparator
        ? current.basedir.resolve('_.dart')
        : Uri.directory(Directory.current.path).resolve('_.dart');
    final env = Platform.environment;
    return FuzzyGoldenComparator(
      testFile,
      maxDiffRate:
          double.tryParse(env['GOLDEN_MAX_DIFF_RATE'] ?? '') ??
          defaultMaxDiffRate,
      channelDelta:
          int.tryParse(env['GOLDEN_CHANNEL_DELTA'] ?? '') ??
          defaultChannelDelta,
    );
  }

  final double maxDiffRate;
  final int channelDelta;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);

    // Byte-equal fast path: renders in the same environment are
    // pixel-identical, so the common case never decodes anything.
    if (listEquals<int>(imageBytes, goldenBytes)) {
      return true;
    }

    final actual = await decodePng(imageBytes);
    final master = await decodePng(Uint8List.fromList(goldenBytes));

    if (actual.width != master.width || actual.height != master.height) {
      await _fail(
        golden: golden,
        master: master,
        actual: actual,
        diffPercent: 1.0,
        error:
            'image sizes do not match '
            '(master ${master.width}x${master.height}, '
            'test ${actual.width}x${actual.height}). '
            'A size change is a layout regression; re-baseline deliberately.',
      );
    }

    final diff = await diffPixels(master, actual, channelDelta);
    final total = actual.width * actual.height;
    final diffRate = diff.count / total;

    if (diffRate <= maxDiffRate) {
      actual.dispose();
      master.dispose();
      diff.dispose();
      return true;
    }

    await _fail(
      golden: golden,
      master: master,
      actual: actual,
      maskedDiff: diff.masked,
      isolatedDiff: diff.isolated,
      diffPercent: diffRate,
      error:
          'pixel diff ${(diffRate * 100).toStringAsFixed(3)}% '
          '(${diff.count} of $total pixels) exceeded the threshold of '
          '${(maxDiffRate * 100).toStringAsFixed(3)}% '
          '(channel delta $channelDelta).',
    );
  }

  /// Throws a [FlutterError] carrying the failure message and writes the
  /// diff images beside the golden. Mirrors [LocalFileComparator.compare],
  /// which throws rather than returning false.
  Future<Never> _fail({
    required Uri golden,
    required ui.Image master,
    required ui.Image actual,
    ui.Image? maskedDiff,
    ui.Image? isolatedDiff,
    required double diffPercent,
    required String error,
  }) async {
    final result = ComparisonResult(
      passed: false,
      diffPercent: diffPercent,
      error: 'Golden "$golden": $error',
      diffs: <String, ui.Image>{
        'masterImage': master,
        'testImage': actual,
        'maskedDiff': ?maskedDiff,
        'isolatedDiff': ?isolatedDiff,
      },
    );
    final message = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(message);
  }
}

/// Decodes PNG bytes to a [ui.Image]. The caller owns the returned image.
Future<ui.Image> decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class PixelDiff {
  PixelDiff({required this.count, this.masked, this.isolated});

  /// Number of pixels whose channel deltas all stayed within the tolerance.
  final int count;

  /// Diff image: the test render with differing pixels highlighted red.
  final ui.Image? masked;

  /// Diff image: differing pixels highlighted red on white.
  final ui.Image? isolated;

  void dispose() {
    masked?.dispose();
    isolated?.dispose();
  }
}

/// Counts pixels where any channel of [actual] differs from [master] by more
/// than [channelDelta], and builds [PixelDiff.masked] and
/// [PixelDiff.isolated] highlight images.
Future<PixelDiff> diffPixels(
  ui.Image master,
  ui.Image actual,
  int channelDelta,
) async {
  assert(
    master.width == actual.width && master.height == actual.height,
    'diffPixels requires equal dimensions',
  );
  final width = master.width;
  final height = master.height;
  final masterData = await master.toByteData();
  final actualData = await actual.toByteData();
  final masterBytes = masterData!.buffer.asUint8List();

  final maskedBytes = Uint8List.fromList(actualData!.buffer.asUint8List());
  final isolatedBytes = Uint8List(width * height * 4);
  for (var i = 0; i < isolatedBytes.length; i += 4) {
    isolatedBytes[i] = 255;
    isolatedBytes[i + 1] = 255;
    isolatedBytes[i + 2] = 255;
    isolatedBytes[i + 3] = 255;
  }

  var count = 0;
  for (var i = 0; i < maskedBytes.length; i += 4) {
    var differs = false;
    for (var c = 0; c < 4; c++) {
      if ((maskedBytes[i + c] - masterBytes[i + c]).abs() > channelDelta) {
        differs = true;
        break;
      }
    }
    if (differs) {
      count++;
      maskedBytes[i] = 255;
      maskedBytes[i + 1] = 0;
      maskedBytes[i + 2] = 0;
      maskedBytes[i + 3] = 255;
      isolatedBytes[i] = 255;
      isolatedBytes[i + 1] = 0;
      isolatedBytes[i + 2] = 0;
      isolatedBytes[i + 3] = 255;
    }
  }

  return PixelDiff(
    count: count,
    masked: await imageFromPixels(maskedBytes, width, height),
    isolated: await imageFromPixels(isolatedBytes, width, height),
  );
}

/// Builds a [ui.Image] from straight RGBA bytes. The caller owns the image.
Future<ui.Image> imageFromPixels(Uint8List rgba, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
