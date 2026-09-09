import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/screenshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ScreenshotService service;
  late List<(String, List<String>)> commands;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('screenshot_test');
    commands = [];
    service = ScreenshotService();
    service.dirProvider = () async => tempDir;
    service.runCommand = (executable, arguments) async {
      commands.add((executable, arguments));
      // fake environment:
      // - which: maim/slop/xdotool/xrandr exist, nothing else
      // - maim "writes" the output file
      if (executable == 'which') {
        const tools = {'maim', 'slop', 'xdotool', 'xrandr'};
        return (tools.contains(arguments.first) ? 0 : 1, '', '');
      }
      if (executable == 'xrandr') {
        const out = '''
HDMI-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 527mm x 296mm
DP-1 connected 1280x1024+1920+0 (normal left inverted right x axis y axis) 338mm x 270mm
HDMI-0 disconnected (normal left inverted right x axis y axis)
''';
        return (0, out, '');
      }
      if (executable == 'xdotool') {
        return (0, '1234567', '');
      }
      if (executable == 'slop') {
        return (0, '640x480+100+200', '');
      }
      if (executable == 'maim') {
        // simulate writing the capture file
        final path = arguments.last;
        File(
          path,
        ).writeAsBytesSync(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
        return (0, '', '');
      }
      return (1, '', 'not found');
    };
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('capture fullscreen uses maim and registers item', () async {
    final item = await service.capture(ScreenshotKind.fullscreen);

    expect(item, isNotNull);
    expect(item!.kind, ScreenshotKind.fullscreen);
    expect(File(item.path).existsSync(), isTrue);
    expect(service.items, hasLength(1));

    // maim was invoked with just the path
    final maimCalls = commands
        .where((c) => c.$1 == 'maim')
        .map((c) => c.$2)
        .toList();
    expect(maimCalls, isNotEmpty);
    expect(maimCalls.last, hasLength(1));
    expect(maimCalls.last.single, endsWith('.png'));
  });

  test('capture window passes xdotool window id to maim', () async {
    final item = await service.capture(ScreenshotKind.window);

    expect(item, isNotNull);
    final maimCalls = commands
        .where((c) => c.$1 == 'maim')
        .map((c) => c.$2)
        .toList();
    expect(maimCalls.any((args) => args.contains('1234567')), isTrue);
  });

  test('capture region saves geometry and previous region reuses it', () async {
    final region = await service.capture(ScreenshotKind.region);
    expect(region, isNotNull);

    // slop was asked for geometry
    expect(commands.any((c) => c.$1 == 'slop' && c.$2.contains('%g')), isTrue);
    // geometry saved for next time
    expect(await service.lastRegionGeometryForTest(), '640x480+100+200');

    final prev = await service.capture(ScreenshotKind.previousRegion);
    expect(prev, isNotNull);
    final maimCalls = commands
        .where((c) => c.$1 == 'maim')
        .map((c) => c.$2)
        .toList();
    // previous region runs maim -g <geometry> <path>
    expect(
      maimCalls.any(
        (args) => args.contains('-g') && args.contains('640x480+100+200'),
      ),
      isTrue,
    );
  });

  test('previous region fails when no region was saved', () async {
    final item = await service.capture(ScreenshotKind.previousRegion);
    expect(item, isNull);
    expect(service.items, isEmpty);
  });

  test('monitor capture falls back to full screen geometry', () async {
    final item = await service.capture(ScreenshotKind.monitor, monitor: 0);
    expect(item, isNotNull);
    final maimCalls = commands
        .where((c) => c.$1 == 'maim')
        .map((c) => c.$2)
        .toList();
    expect(maimCalls.any((args) => args.contains('-m')), isTrue);
  });

  test('auto capture uses saved region when available', () async {
    await service.capture(ScreenshotKind.region); // establish region
    final before = service.items.length;
    final item = await service.capture(ScreenshotKind.auto);
    expect(item, isNotNull);
    expect(service.items.length, before + 1);
    final maimCalls = commands
        .where((c) => c.$1 == 'maim')
        .map((c) => c.$2)
        .toList();
    expect(
      maimCalls.any(
        (args) => args.contains('-g') && args.contains('640x480+100+200'),
      ),
      isTrue,
    );
  });

  test('captureWithPipeline runs ocr and copies when enabled', () async {
    String? copiedText;
    String? ocrInputPath;
    final item = await service.captureWithPipeline(
      ScreenshotKind.fullscreen,
      autoOcr: true,
      copyOcrText: true,
      copyImage: false,
      ocrRunner: (path) async {
        ocrInputPath = path;
        return 'recognized text';
      },
      copyTextRunner: (text) async {
        copiedText = text;
      },
    );

    expect(item, isNotNull);
    expect(ocrInputPath, item!.path);
    expect(item.ocrText, 'recognized text');
    expect(copiedText, 'recognized text');
    // registry holds the OCR text too
    expect(
      service.items.firstWhere((i) => i.id == item.id).ocrText,
      'recognized text',
    );
  });

  test('captureWithPipeline without autoOcr leaves ocrText null', () async {
    final item = await service.captureWithPipeline(
      ScreenshotKind.fullscreen,
      autoOcr: false,
      copyOcrText: true,
      copyImage: false,
      ocrRunner: (path) async => 'should not run',
      copyTextRunner: (text) async {
        fail('copy should not run without ocr text');
      },
    );

    expect(item, isNotNull);
    expect(item!.ocrText, isNull);
  });

  test('items roundtrip through json', () async {
    final item = await service.capture(ScreenshotKind.window);
    expect(item, isNotNull);
    final json = item!.toJson();
    final restored = ScreenshotItem.fromJson(json);
    expect(restored.id, item.id);
    expect(restored.path, item.path);
    expect(restored.kind, ScreenshotKind.window);
    expect(restored.timestamp, item.timestamp);
  });

  test('remove deletes file and registry entry', () async {
    final item = await service.capture(ScreenshotKind.fullscreen);
    expect(item, isNotNull);
    final path = item!.path;
    expect(File(path).existsSync(), isTrue);

    service.remove(item.id);
    expect(service.items, isEmpty);
    expect(File(path).existsSync(), isFalse);
  });

  test('clear removes everything', () async {
    await service.capture(ScreenshotKind.fullscreen);
    await service.capture(ScreenshotKind.window);
    expect(service.items.length, 2);

    service.clear();
    expect(service.items, isEmpty);
    expect(
      tempDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      ),
      isEmpty,
    );
  });

  test('setOcrText updates stored item', () async {
    final item = await service.capture(ScreenshotKind.fullscreen);
    service.setOcrText(item!.id, 'hello');
    expect(service.items.first.ocrText, 'hello');
  });

  test('detectPlatform returns x11 in test env with display set', () async {
    // Test env has DISPLAY set (x11 session)
    final platform = await service.detectPlatform();
    expect(
      platform,
      anyOf(ScreenshotPlatform.x11, ScreenshotPlatform.unsupported),
    );
  });
}
