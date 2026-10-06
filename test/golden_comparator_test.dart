// Threshold logic of FuzzyGoldenComparator: the part that decides whether a
// pixel change is a regression or noise.
//
// Images are built programmatically so every case is exact: a channel delta
// inside the tolerance must not count, a diff rate inside the threshold must
// pass, anything larger must fail and write failure artifacts.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

import 'golden/fuzzy_golden_comparator.dart';

/// Builds straight-RGBA pixels: [w]*[h], every pixel [color], with [paint]
/// invoked once for targeted overrides.
Uint8List pixels(
  int w,
  int h,
  List<int> color, [
  void Function(Uint8List bytes)? paint,
]) {
  final bytes = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    bytes[i * 4] = color[0];
    bytes[i * 4 + 1] = color[1];
    bytes[i * 4 + 2] = color[2];
    bytes[i * 4 + 3] = color[3];
  }
  paint?.call(bytes);
  return bytes;
}

Future<Uint8List> encodePng(Uint8List rgba, int w, int h) async {
  final image = await imageFromPixels(rgba, w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('golden_comparator_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Comparator with its basedir in [tempDir] and explicit thresholds. The
  /// constructor takes a test file path and derives the basedir from it, so
  /// point it at a synthetic file inside the temp dir.
  FuzzyGoldenComparator makeComparator({
    double maxDiffRate = 0.002,
    int channelDelta = 12,
  }) {
    return FuzzyGoldenComparator(
      Uri.file('${tempDir.path}/comparator.dart'),
      maxDiffRate: maxDiffRate,
      channelDelta: channelDelta,
    );
  }

  /// Writes [png] as the baseline and returns the golden-relative URI.
  Future<Uri> writeBaseline(Uint8List png) async {
    final file = File('${tempDir.path}/baseline.png');
    await file.writeAsBytes(png, flush: true);
    return Uri.parse('baseline.png');
  }

  test('byte-identical renders pass without decoding', () async {
    final png = await encodePng(pixels(16, 16, [0, 128, 255, 255]), 16, 16);
    final comparator = makeComparator();
    final golden = await writeBaseline(png);
    expect(await comparator.compare(png, golden), isTrue);
  });

  test('channel deltas within tolerance do not count', () async {
    // Master 100,100,100; test 110,110,110. Every pixel moved by 10, less
    // than the channel delta of 12, so zero pixels count as differing.
    final master = await encodePng(
      pixels(16, 16, [100, 100, 100, 255]),
      16,
      16,
    );
    final test = await encodePng(pixels(16, 16, [110, 110, 110, 255]), 16, 16);
    final comparator = makeComparator();
    final golden = await writeBaseline(master);
    expect(await comparator.compare(test, golden), isTrue);
  });

  test('a diff rate under the threshold passes', () async {
    // 16x16 = 256 pixels; 2 pixels fully inverted = 0.78%... keep it under
    // 0.002: use 1 pixel of 1024 (32x32) = 0.098%.
    final masterPixels = pixels(32, 32, [255, 255, 255, 255]);
    final testPixels = pixels(32, 32, [255, 255, 255, 255], (bytes) {
      bytes[0] = 0;
      bytes[1] = 0;
      bytes[2] = 0;
    });
    final master = await encodePng(masterPixels, 32, 32);
    final test = await encodePng(testPixels, 32, 32);
    final comparator = makeComparator();
    final golden = await writeBaseline(master);
    expect(await comparator.compare(test, golden), isTrue);
  });

  test('a diff rate over the threshold fails and writes artifacts', () async {
    // 8x8 = 64 pixels; 4 fully inverted = 6.25%, far over 0.2%.
    final masterPixels = pixels(8, 8, [255, 255, 255, 255]);
    final testPixels = pixels(8, 8, [255, 255, 255, 255], (bytes) {
      for (final px in [0, 9, 18, 27]) {
        bytes[px * 4] = 0;
        bytes[px * 4 + 1] = 0;
        bytes[px * 4 + 2] = 0;
      }
    });
    final master = await encodePng(masterPixels, 8, 8);
    final test = await encodePng(testPixels, 8, 8);
    final comparator = makeComparator();
    final golden = await writeBaseline(master);

    await expectLater(
      comparator.compare(test, golden),
      throwsA(
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          allOf([
            contains('pixel diff 6.250%'),
            contains('exceeded the threshold of 0.200%'),
          ]),
        ),
      ),
    );

    final failures = Directory('${tempDir.path}/failures');
    expect(failures.existsSync(), isTrue, reason: 'failure images written');
    final names =
        failures
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList()
          ..sort();
    expect(names, [
      'baseline_isolatedDiff.png',
      'baseline_maskedDiff.png',
      'baseline_masterImage.png',
      'baseline_testImage.png',
    ]);
  });

  test('size mismatch fails and writes the two renders', () async {
    final master = await encodePng(pixels(8, 8, [255, 255, 255, 255]), 8, 8);
    final test = await encodePng(pixels(16, 16, [255, 255, 255, 255]), 16, 16);
    final comparator = makeComparator();
    final golden = await writeBaseline(master);

    await expectLater(
      comparator.compare(test, golden),
      throwsA(
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('image sizes do not match'),
        ),
      ),
    );

    final names =
        Directory('${tempDir.path}/failures')
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList()
          ..sort();
    expect(names, ['baseline_masterImage.png', 'baseline_testImage.png']);
  });

  test('channel delta zero is byte-level strictness', () async {
    // channelDelta 0: any nonzero delta counts. 1 of 256 pixels = 0.39%,
    // over the 0.002 threshold -> fails. With delta 12 the single-pixel
    // delta of 10 would not count at all and pass.
    final masterPixels = pixels(16, 16, [100, 100, 100, 255]);
    final testPixels = pixels(16, 16, [100, 100, 100, 255], (bytes) {
      bytes[0] = 110;
    });
    final master = await encodePng(masterPixels, 16, 16);
    final test = await encodePng(testPixels, 16, 16);
    final strict = makeComparator(channelDelta: 0);
    final golden = await writeBaseline(master);
    await expectLater(
      strict.compare(test, golden),
      throwsA(isA<FlutterError>()),
    );
  });

  test('raising the diff-rate threshold tolerates the same change', () async {
    // Same single-pixel change, but a 1% threshold: passes.
    final masterPixels = pixels(16, 16, [100, 100, 100, 255]);
    final testPixels = pixels(16, 16, [100, 100, 100, 255], (bytes) {
      bytes[0] = 110;
    });
    final master = await encodePng(masterPixels, 16, 16);
    final test = await encodePng(testPixels, 16, 16);
    final tolerant = makeComparator(maxDiffRate: 0.01, channelDelta: 0);
    final golden = await writeBaseline(master);
    expect(await tolerant.compare(test, golden), isTrue);
  });
}
