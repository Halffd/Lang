import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Writes image bytes to the system clipboard.
///
/// The Flutter clipboard API only carries text, and the rich-clipboard
/// route (super_clipboard) is unreliable for images on X11: the GTK
/// selection owner lives on the GLib main loop, which a Flutter
/// application does not pump, so the selection is offered but never
/// answers the paste request. The command-line tools do own the
/// selection in their own process, so they are the reliable path.
class ImageClipboardService {
  const ImageClipboardService._();

  /// Test seam: replaces the whole copy implementation.
  static Future<bool> Function(Uint8List bytes)? override;

  /// Test seam: replaces the "is this binary available" probe.
  static Future<bool> Function(String binary)? binaryExists;

  /// Test seam: replaces the whole "run this clipboard tool" step.
  static Future<bool> Function(LinuxCopyTool tool, Uint8List bytes)? toolRun;

  /// Test seam: replaces the session environment used to pick the
  /// Linux clipboard tool.
  static Map<String, String> Function()? envProvider;

  /// Test seam: maps a tool name to the executable that is actually
  /// started, so a stand-in can be used in place of the real binary.
  static String Function(String binary)? executableResolver;

  /// Copies [bytes] as PNG to the clipboard. Returns true when a tool
  /// accepted the data.
  static Future<bool> copyPng(Uint8List bytes) async {
    // empty data is never a valid clipboard image, whatever the
    // session or the tool
    if (bytes.isEmpty) return false;

    final o = override;
    if (o != null) return await o(bytes);

    if (Platform.isLinux) return await _copyLinux(bytes);
    if (Platform.isMacOS) return await _copyMacos(bytes);
    if (Platform.isWindows) return await _copyWindows(bytes);
    return false;
  }

  /// Linux: the CLI tools own the X11/Wayland selection in their own
  /// process. The tool is picked by the session in use, not by which
  /// binaries happen to be installed — a machine with both wl-copy and
  /// xclip on an X11 session must not try Wayland first.
  static Future<bool> _copyLinux(Uint8List bytes) async {
    final env = envProvider != null ? envProvider!() : Platform.environment;
    for (final tool in linuxToolsFor(env)) {
      if (!await _exists(tool.binary)) continue;
      final runner = toolRun;
      final ok = runner != null
          ? await runner(tool, bytes)
          : await _run(tool, bytes);
      if (ok) return true;
    }
    return false;
  }

  /// The clipboard tools to try, in order, for a session with the
  /// given environment.
  ///
  /// The Wayland tool comes first because it is the native clipboard of
  /// a Wayland session, and it is the only tool that can serve the
  /// clipboard of a Wayland-only session. It is not offered on an
  /// X11-only session: `wl-copy` exits 0 without copying anything when
  /// it cannot reach a Wayland server, so trying it there would report
  /// a copy that never happened.
  ///
  /// A session with neither WAYLAND_DISPLAY nor DISPLAY can still
  /// reach an X server through xclip's default display, so xclip is
  /// kept as the last resort rather than dropping the copy entirely.
  @visibleForTesting
  static List<LinuxCopyTool> linuxToolsFor(Map<String, String> env) {
    final tools = <LinuxCopyTool>[];
    // an empty value is not a display: wl-copy treats a set-but-empty
    // WAYLAND_DISPLAY as a connection failure, and an unset one as a
    // silent no-op that still exits 0.
    final wayland = env['WAYLAND_DISPLAY'];
    final hasWayland = wayland != null && wayland.isNotEmpty;
    final hasX11 = (env['DISPLAY'] ?? '').isNotEmpty;

    if (hasWayland) tools.add(const LinuxCopyTool('wl-copy', waylandArgs));
    if (hasX11) tools.add(const LinuxCopyTool('xclip', x11Args));
    if (!hasWayland && !hasX11) {
      tools.add(const LinuxCopyTool('xclip', x11Args));
    }
    return tools;
  }

  /// The Wayland arguments: read the PNG from stdin and offer it as
  /// image/png.
  ///
  /// The MIME type has to be stated. Without it wl-copy infers the
  /// type from the data, and a PNG arriving on a pipe is inferred as
  /// text/plain, so the clipboard would hold the bytes as text and no
  /// application would paste them as an image.
  static const List<String> waylandArgs = ['--type', 'image/png'];

  /// The xclip arguments: read the PNG from stdin into the clipboard
  /// selection as image/png.
  static const List<String> x11Args = [
    '-selection',
    'clipboard',
    '-t',
    'image/png',
    '-i',
  ];

  static Future<bool> _run(LinuxCopyTool tool, Uint8List bytes) async {
    Process? process;
    try {
      final executable = executableResolver?.call(tool.binary) ?? tool.binary;
      process = await Process.start(executable, tool.args);
      process.stdin.add(bytes);
      await process.stdin.flush();
      // The data has to be closed off, otherwise the tool waits on the
      // pipe forever and never reaches the clipboard.
      await process.stdin.close();
      // xclip and wl-copy fork into the background to own the
      // selection, so the process we started exits promptly. A tool
      // that stays in the foreground is serving the selection itself.
      // A tool that neither exits nor forks is hung (it is still
      // waiting on something it will never get); that is a failure,
      // not a success, so the process is killed and the copy fails.
      try {
        final code = await process.exitCode.timeout(
          const Duration(seconds: 5),
        );
        return code == 0;
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        debugPrint(
          'ImageClipboardService: ${tool.binary} hung, copy failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint('ImageClipboardService: ${tool.binary} failed: $e');
      return false;
    } finally {
      // The forked child keeps the inherited stdout and stderr pipes
      // open, so a caller that waits for them to close would wait
      // forever. Draining them in the background keeps the pipes from
      // filling up without ever blocking the copy.
      _drain(process?.stdout);
      _drain(process?.stderr);
    }
  }

  /// Consumes and discards a pipe of the tool's output.
  ///
  /// The forked clipboard owner holds these pipes open for as long as
  /// it serves the selection, so they are drained until the tool is
  /// done rather than awaited.
  static void _drain(Stream<List<int>>? stream) {
    if (stream == null) return;
    stream.listen(
      (_) {},
      onError: (_) {},
      cancelOnError: true,
    );
  }

  static Future<bool> _exists(String binary) async {
    final probe = binaryExists;
    if (probe != null) return await probe(binary);
    try {
      final r = await Process.run('which', [binary]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _copyMacos(Uint8List bytes) async {
    return await _withTempPng(bytes, (path) async {
      final script =
          'set the clipboard to (read (POSIX file "$path") as «class PNGf»)';
      return await _runProcess('osascript', ['-e', script]);
    });
  }

  static Future<bool> _copyWindows(Uint8List bytes) async {
    return await _withTempPng(bytes, (path) async {
      final windowsPath = path.replaceAll('\\', '/');
      final script =
          'Add-Type -AssemblyName System.Windows.Forms; '
          '[Windows.Forms.Clipboard]::SetImage('
          '[System.Drawing.Image]::FromFile("$windowsPath"))';
      return await _runProcess('powershell', [
        '-NoProfile',
        '-Command',
        script,
      ]);
    });
  }

  /// Runs [action] with a temporary PNG file and deletes it afterwards.
  static Future<bool> _withTempPng(
    Uint8List bytes,
    Future<bool> Function(String path) action,
  ) async {
    Directory? dir;
    try {
      dir = await Directory.systemTemp.createTemp('lang_clipimg');
      final file = File('${dir.path}/image.png');
      await file.writeAsBytes(bytes);
      return await action(file.path);
    } catch (e) {
      debugPrint('ImageClipboardService: clipboard write failed: $e');
      return false;
    } finally {
      try {
        if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  static Future<bool> _runProcess(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final r = await Process.run(executable, arguments);
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('ImageClipboardService: $executable failed: $e');
      return false;
    }
  }
}

/// A clipboard-writing command line tool and its arguments.
class LinuxCopyTool {
  final String binary;
  final List<String> args;

  const LinuxCopyTool(this.binary, this.args);

  @override
  String toString() => '$binary ${args.join(' ')}';
}
