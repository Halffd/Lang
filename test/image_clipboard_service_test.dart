// Tests for the image clipboard writer: the tool is picked by the
// session in use, not by which binaries happen to be installed, and a
// failing tool must fall through to the next one.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/image_clipboard_service.dart';

void main() {
  tearDown(() {
    ImageClipboardService.override = null;
    ImageClipboardService.binaryExists = null;
    ImageClipboardService.toolRun = null;
    ImageClipboardService.envProvider = null;
    ImageClipboardService.executableResolver = null;
  });

  test('a missing tool makes the copy fail', () async {
    ImageClipboardService.binaryExists = (_) async => false;

    final ok = await ImageClipboardService.copyPng(
      Uint8List.fromList([1, 2, 3]),
    );

    expect(ok, isFalse);
  });

  test('the override replaces the whole copy', () async {
    var called = false;
    ImageClipboardService.override = (bytes) async {
      called = true;
      expect(bytes, isNotEmpty);
      return true;
    };

    final ok = await ImageClipboardService.copyPng(
      Uint8List.fromList([1, 2, 3]),
    );

    expect(ok, isTrue);
    expect(called, isTrue);
  });

  test('empty bytes are rejected without touching the clipboard', () async {
    var called = false;
    ImageClipboardService.override = (bytes) async {
      called = true;
      return true;
    };

    final ok = await ImageClipboardService.copyPng(Uint8List(0));

    expect(ok, isFalse);
    expect(called, isFalse);
  });

  group('linux tool selection', () {
    test('an X11 session uses xclip, never wl-copy', () {
      final tools = ImageClipboardService.linuxToolsFor({
        'DISPLAY': ':0',
      });

      expect(tools.map((t) => t.binary), ['xclip']);
    });

    test('a Wayland session uses wl-copy', () {
      final tools = ImageClipboardService.linuxToolsFor({
        'WAYLAND_DISPLAY': 'wayland-0',
      });

      expect(tools.map((t) => t.binary), ['wl-copy']);
    });

    test('a Wayland session falls back to xclip for XWayland', () {
      final tools = ImageClipboardService.linuxToolsFor({
        'WAYLAND_DISPLAY': 'wayland-0',
        'DISPLAY': ':0',
      });

      expect(tools.map((t) => t.binary), ['wl-copy', 'xclip']);
    });

    test('a session with no display still tries xclip', () {
      final tools = ImageClipboardService.linuxToolsFor({});

      expect(tools.map((t) => t.binary), ['xclip']);
    });

    test('an empty display is not a display', () {
      // wl-copy exits 0 without copying anything when WAYLAND_DISPLAY
      // is unset, so an empty value must not select it either
      final tools = ImageClipboardService.linuxToolsFor({
        'WAYLAND_DISPLAY': '',
        'DISPLAY': ':0',
      });

      expect(tools.map((t) => t.binary), ['xclip']);
    });

    test('an empty X11 display is not a display', () {
      final tools = ImageClipboardService.linuxToolsFor({'DISPLAY': ''});

      expect(tools.map((t) => t.binary), ['xclip']);
    });

    test('xclip is told to read the PNG from stdin', () {
      final tools = ImageClipboardService.linuxToolsFor({'DISPLAY': ':0'});

      expect(tools.single.args, contains('image/png'));
      expect(tools.single.args, contains('-i'));
    });

    test('wl-copy is told to offer the data as an image', () {
      // without the type, wl-copy infers text/plain from the piped
      // bytes and the clipboard holds the PNG as text
      final tools = ImageClipboardService.linuxToolsFor({
        'WAYLAND_DISPLAY': 'wayland-0',
      });

      expect(tools.single.args, containsAll(['--type', 'image/png']));
    });
  });

  group('linux tool execution', () {
    test('a failing tool falls through to the next one', () async {
      // a Wayland session with XWayland: wl-copy first, xclip second
      ImageClipboardService.envProvider = () => {
        'WAYLAND_DISPLAY': 'wayland-0',
        'DISPLAY': ':0',
      };
      ImageClipboardService.binaryExists = (_) async => true;
      final tried = <String>[];
      ImageClipboardService.toolRun = (tool, bytes) async {
        tried.add(tool.binary);
        // the first tool fails; the second one works
        return tool.binary != 'wl-copy';
      };

      final ok = await ImageClipboardService.copyPng(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(ok, isTrue);
      expect(tried, ['wl-copy', 'xclip']);
    });

    test('a tool that fails every time makes the copy fail', () async {
      ImageClipboardService.envProvider = () => {'DISPLAY': ':0'};
      ImageClipboardService.binaryExists = (_) async => true;
      ImageClipboardService.toolRun = (tool, bytes) async => false;

      final ok = await ImageClipboardService.copyPng(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(ok, isFalse);
    });

    test('the copy does not hang on a tool that forks into the '
        'background', () async {
      // xclip and wl-copy fork to own the selection, keeping the
      // inherited pipes open. The copy must still return promptly
      // instead of waiting for those pipes to close.
      final dir = await Directory.systemTemp.createTemp('imgclip_tool');
      addTearDown(() => dir.delete(recursive: true));
      final tool = File('${dir.path}/fake-copy');
      await tool.writeAsString('''
#!/bin/sh
# read the payload, then fork a child that holds the inherited output
# pipes open, the way the real clipboard tools do
cat > "${dir.path}/payload"
sleep 30 &
exit 0
''');
      await Process.run('chmod', ['+x', tool.path]);

      ImageClipboardService.envProvider = () => {'DISPLAY': ':0'};
      ImageClipboardService.binaryExists = (b) async => b == 'xclip';
      ImageClipboardService.executableResolver = (b) => tool.path;

      final ok = await ImageClipboardService.copyPng(
        Uint8List.fromList([1, 2, 3]),
      ).timeout(const Duration(seconds: 20));

      expect(await File('${dir.path}/payload').readAsBytes(), [1, 2, 3]);
      expect(ok, isTrue);
    });
  });
}
