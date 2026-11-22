import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/script_assets.dart';
import 'package:path_provider/path_provider.dart';

/// How a screenshot was taken.
enum ScreenshotKind {
  fullscreen,
  monitor,
  window,
  region,
  previousRegion,
  auto,
}

/// One stored screenshot and its (optional) OCR text.
class ScreenshotItem {
  final String id;
  final String path;
  final ScreenshotKind kind;
  final int timestamp;

  /// Recognized text, filled when auto-OCR ran. Null until OCR completes.
  final String? ocrText;

  /// Region geometry "x,y w,h" for the last interactive selection.
  final String? geometry;

  /// User-set display name. Empty means the file name is used.
  final String name;

  /// Hidden items stay in the registry but are filtered out of the
  /// album and history views.
  final bool hidden;

  const ScreenshotItem({
    required this.id,
    required this.path,
    required this.kind,
    required this.timestamp,
    this.ocrText,
    this.geometry,
    this.name = '',
    this.hidden = false,
  });

  /// The name shown in the UI: the user's name, or the file name.
  String get displayName {
    if (name.isNotEmpty) return name;
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'kind': kind.name,
    'timestamp': timestamp,
    'ocrText': ocrText,
    'geometry': geometry,
    'name': name,
    'hidden': hidden,
  };

  static ScreenshotItem fromJson(Map<String, dynamic> json) => ScreenshotItem(
    id: json['id'] as String,
    path: json['path'] as String,
    kind: ScreenshotKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => ScreenshotKind.fullscreen,
    ),
    timestamp: (json['timestamp'] as num).toInt(),
    ocrText: json['ocrText'] as String?,
    geometry: json['geometry'] as String?,
    name: json['name'] as String? ?? '',
    hidden: json['hidden'] == true,
  );

  ScreenshotItem copyWith({
    String? path,
    String? ocrText,
    String? geometry,
    String? name,
    bool? hidden,
  }) => ScreenshotItem(
    id: id,
    path: path ?? this.path,
    kind: kind,
    timestamp: timestamp,
    ocrText: ocrText ?? this.ocrText,
    geometry: geometry ?? this.geometry,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
  );

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

/// A rectangle in image pixels, used by the crop action.
class ScreenshotCropRect {
  final int left;
  final int top;
  final int width;
  final int height;

  const ScreenshotCropRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  int get right => left + width;
  int get bottom => top + height;
}

/// Abstraction over Process.run so tests can inject fake command
/// runners without spawning real screenshot tools.
typedef CommandRunner =
    Future<(int, String, String)> Function(
      String executable,
      List<String> arguments,
    );

enum ScreenshotPlatform { x11, wayland, windows, macos, unsupported }

/// One monitor the app can capture.
class ScreenshotMonitor {
  /// The platform's name for the output (e.g. "HDMI-1"). Empty when
  /// the platform does not name its outputs.
  final String name;

  /// The output's pixel size, when the platform reports it.
  final int? width;
  final int? height;

  /// Whether this is the primary output.
  final bool isPrimary;

  const ScreenshotMonitor({
    this.name = '',
    this.width,
    this.height,
    this.isPrimary = false,
  });

  /// A label for the UI: the output name and its resolution.
  String get label {
    if (name.isEmpty) return isPrimary ? 'Primary' : 'Monitor';
    if (width != null && height != null) {
      return '$name ($width×$height)';
    }
    return name;
  }
}

/// One monitor reported by xrandr.
class X11Monitor {
  /// The output name (e.g. "HDMI-1").
  final String name;

  final int width;
  final int height;

  /// The output's position in the virtual screen.
  final int x;
  final int y;

  /// Whether this is the primary output.
  final bool isPrimary;

  const X11Monitor({
    required this.name,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    this.isPrimary = false,
  });

  /// The geometry in imagemagick style ("WxH+X+Y").
  String get geometry => '${width}x$height+$x+$y';

  @override
  String toString() => 'X11Monitor($name, $geometry)';
}

/// Captures screenshots through native tools and keeps a persistent
/// registry of taken shots (history + album).
///
/// Platform tools:
/// - X11: maim (with slop for interactive region), fallbacks scrot /
///   gnome-screenshot / import
/// - Wayland: grim + slurp (best effort; falls back to X11 tools when
///   Xwayland is available)
/// - Windows: powershell CopyFromScreen (fullscreen/monitor only)
/// - macOS: screencapture
///
/// All command execution goes through [runCommand] which is injectable
/// for tests.
class ScreenshotService extends ChangeNotifier {
  /// Shared instance used by UI and hotkeys; fresh instances are
  /// safe (each gets its own registry directory contents).
  static final ScreenshotService instance = ScreenshotService();

  ScreenshotService();

  /// Production command runner. Returns (exitCode, stdout, stderr).
  static Future<(int, String, String)> _realRunner(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return (
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  /// Injectable for tests.
  CommandRunner runCommand = _realRunner;

  /// Injectable directory for tests (defaults to
  /// `<app docs>`/screenshots).
  Future<Directory> Function() dirProvider = _defaultDirProvider;

  /// The user-chosen directory screenshots are written to. Empty means
  /// the default (the app's documents folder). Set by the settings
  /// screen; read at capture time so a change takes effect on the next
  /// capture without a restart.
  String directoryOverride = '';

  /// Injectable environment for tests (defaults to
  /// [Platform.environment]). Real detection reads DISPLAY/WAYLAND_DISPLAY,
  /// which differs between headless CI boxes and desktop sessions, so tests
  /// inject an explicit map instead of depending on the host.
  Map<String, String> Function() envProvider = () => Platform.environment;

  /// Injectable platform probe for tests. Real detection reads
  /// DISPLAY/WAYLAND_DISPLAY from the process environment, which is
  /// unobservable from a headless CI box, so tests force the backend they
  /// exercise instead of getting [ScreenshotPlatform.unsupported].
  Future<ScreenshotPlatform> Function()? platformOverride;

  static Future<Directory> _defaultDirProvider() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/screenshots');
  }

  /// Resolve capture tool each call (tools may be installed later).
  Future<String?> _which(String tool) async {
    try {
      final (code, _, _) = await runCommand('which', [tool]);
      return code == 0 ? tool : null;
    } catch (_) {
      return null;
    }
  }

  List<ScreenshotItem> _items = [];
  bool _loaded = false;
  Timer? _autoTimer;

  static const String _prefsFile = 'screenshots.json';
  static const int _maxItems = 200;

  List<ScreenshotItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;
  bool get isAutoCaptureActive => _autoTimer != null;

  /// The directory screenshots are currently written to, without
  /// creating it.
  Future<Directory> currentDirectory() async {
    final override = directoryOverride.trim();
    if (override.isNotEmpty) return Directory(override);
    return await dirProvider();
  }

  /// Directory where screenshots are written.
  Future<Directory> _shotsDir() async {
    final dir = await currentDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @visibleForTesting
  void resetForTest() {
    _items = [];
    _loaded = false;
    _autoTimer?.cancel();
    _autoTimer = null;
    runCommand = _realRunner;
    dirProvider = _defaultDirProvider;
    envProvider = () => Platform.environment;
    platformOverride = null;
  }

  /// Detect the screenshot backend usable on this machine.
  Future<ScreenshotPlatform> detectPlatform() async {
    final override = platformOverride;
    if (override != null) return override();
    if (Platform.isWindows) return ScreenshotPlatform.windows;
    if (Platform.isMacOS) return ScreenshotPlatform.macos;
    if (Platform.isLinux) {
      // Wayland tools take priority when a Wayland session is active.
      final env = envProvider();
      if (env['WAYLAND_DISPLAY'] != null && (await _which('grim')) != null) {
        return ScreenshotPlatform.wayland;
      }
      if (env['DISPLAY'] != null &&
          ((await _which('maim')) != null ||
              (await _which('scrot')) != null ||
              (await _which('gnome-screenshot')) != null ||
              (await _which('import')) != null)) {
        return ScreenshotPlatform.x11;
      }
    }
    return ScreenshotPlatform.unsupported;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      // registry document follows the storage backend setting (SQLite or
      // local files); the PNGs stay on disk either way. Legacy registry
      // file next to the images imports on first access.
      var raw = await AppStorage.readWithMigration(_prefsFile);
      if (raw == null) {
        // legacy: JSON file in the shots dir
        final dir = await _shotsDir();
        final file = File('${dir.path}/$_prefsFile');
        if (file.existsSync()) {
          raw = file.readAsStringSync();
          await AppStorage.instance.write(_prefsFile, raw);
        }
      }
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final rawItems = decoded['items'] as List? ?? [];
        _items = rawItems
            .map((e) => ScreenshotItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('ScreenshotService load error: $e');
      _items = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await AppStorage.instance.write(
        _prefsFile,
        jsonEncode({'items': _items}),
      );
    } catch (e) {
      debugPrint('ScreenshotService persist error: $e');
    }
  }

  /// Capture a screenshot of [kind]. Returns the saved file path or
  /// null when capture failed.
  Future<ScreenshotItem?> capture(
    ScreenshotKind kind, {
    int monitor = 0,
  }) async {
    final platform = await detectPlatform();
    if (platform == ScreenshotPlatform.unsupported) return null;

    final dir = await _shotsDir();
    final now = DateTime.now();
    final id = '${kind.name}_${now.millisecondsSinceEpoch}_${now.microsecond}';
    final path =
        '${dir.path}/${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}_${kind.name}.png';

    String? geometry;
    final ok = await _captureToFile(path, kind, monitor, platform);
    if (!ok) return null;

    // remember interactive region geometry for previousRegion
    if (kind == ScreenshotKind.region) {
      geometry = await _lastRegionGeometry();
    }

    // image payload follows the storage backend: SQLite stores the PNG
    // as a BLOB ref (temp capture file removed), the files backend keeps
    // the file on disk. readMedia understands both ref forms and bare
    // legacy paths.
    var storedPath = path;
    if (AppStorage.isSqliteBackend) {
      try {
        final bytes = await File(path).readAsBytes();
        storedPath = await AppStorage.writeMedia(bytes);
        final tmp = File(path);
        if (tmp.existsSync() && path.contains(Directory.systemTemp.path)) {
          tmp.deleteSync();
        }
      } catch (e) {
        debugPrint('ScreenshotService: blob store failed, keeping file: $e');
      }
    }

    final item = ScreenshotItem(
      id: id,
      path: storedPath,
      kind: kind,
      timestamp: now.millisecondsSinceEpoch,
      geometry: geometry,
    );
    _items.insert(0, item);
    if (_items.length > _maxItems) {
      final removed = _items.sublist(_maxItems);
      _items = _items.sublist(0, _maxItems);
      for (final r in removed) {
        final f = File(r.path);
        if (f.existsSync()) f.deleteSync();
      }
    }
    notifyListeners();
    _persist();
    return item;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Runs the platform capture for [kind] into [path].
  Future<bool> _captureToFile(
    String path,
    ScreenshotKind kind,
    int monitor,
    ScreenshotPlatform platform,
  ) => switch (platform) {
    ScreenshotPlatform.x11 => _captureX11(path, kind, monitor),
    ScreenshotPlatform.wayland => _captureWayland(path, kind, monitor),
    ScreenshotPlatform.windows => _captureWindows(path, kind, monitor),
    ScreenshotPlatform.macos => _captureMacos(path, kind),
    ScreenshotPlatform.unsupported => Future.value(false),
  };

  /// Captures a frame without registering it in the screenshot history.
  ///
  /// The live-OCR loop polls continuously, so its captures must not
  /// pile up in the album, the registry file, or the storage backend.
  /// The frame is written to a temp file and returned as bytes; the
  /// caller owns it.
  Future<Uint8List?> captureTransient(
    ScreenshotKind kind, {
    int monitor = 0,
  }) async {
    final platform = await detectPlatform();
    if (platform == ScreenshotPlatform.unsupported) return null;

    final dir = await Directory.systemTemp.createTemp('lang_live_ocr');
    final path = '${dir.path}/frame.png';
    try {
      final ok = await _captureToFile(path, kind, monitor, platform);
      if (!ok) return null;
      return await File(path).readAsBytes();
    } catch (e) {
      debugPrint('ScreenshotService transient capture error: $e');
      return null;
    } finally {
      try {
        final d = Directory(dir.path);
        if (d.existsSync()) d.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------
  // X11 (maim primary; scrot / gnome-screenshot / import fallback)
  // --------------------------------------------------------------

  Future<bool> _captureX11(
    String path,
    ScreenshotKind kind,
    int monitor,
  ) async {
    final maim = await _which('maim');
    if (maim != null) {
      switch (kind) {
        case ScreenshotKind.fullscreen:
          return _tryRun([path]);
        case ScreenshotKind.monitor:
          // Capture the monitor by its exact xrandr geometry.
          //
          // maim's `-m` index is 1-based and its order does not
          // necessarily match xrandr's, so passing the app's 0-based
          // index picked the wrong output — and `maim -m 0` fails
          // outright, which sent the capture down the fallback path
          // and could hand back every monitor. The app's monitor list
          // comes from xrandr, so its geometry is the reliable handle.
          if (await _captureMonitorByGeometry(path, monitor)) return true;
          return false;
        case ScreenshotKind.window:
          final winId = await _activeWindowId();
          if (winId == null) return false;
          return _tryRun(['-i', winId, path]);
        case ScreenshotKind.region:
        case ScreenshotKind.previousRegion:
          return await _captureRegionX11(path, kind);
        case ScreenshotKind.auto:
          // interactive region remembered; auto uses previous region or
          // falls back to full screen
          if (await _hasSavedRegion()) {
            return _captureRegionX11(path, ScreenshotKind.previousRegion);
          }
          return _tryRun([path]);
      }
    }
    // fallbacks without maim
    final scrot = await _which('scrot');
    if (scrot != null) {
      switch (kind) {
        case ScreenshotKind.fullscreen:
        case ScreenshotKind.auto:
          return _tryRunScrot([path]);
        case ScreenshotKind.monitor:
          // scrot has no monitor mode; capture the monitor's geometry
          // with -a. There is no full-screen fallback here either.
          final geometry = await _monitorGeometryX11(monitor);
          if (geometry == null) return false;
          // scrot -a takes "x,y,w,h" (top-left + size)
          final (x, y, w, h) = _parseGeometry(geometry);
          return _tryRunScrot(['-a', '$x,$y,$w,$h', path]);
        case ScreenshotKind.window:
          // scrot has no window mode; capture full screen instead
          return _tryRunScrot([path]);
        case ScreenshotKind.region:
        case ScreenshotKind.previousRegion:
          return _tryRunScrot(['-s', path]);
      }
    }
    final gnome = await _which('gnome-screenshot');
    if (gnome != null) {
      if (kind == ScreenshotKind.monitor) {
        // gnome-screenshot has no monitor mode: capture the monitor's
        // geometry with -a
        final geometry = await _monitorGeometryX11(monitor);
        if (geometry == null) return false;
        final (x, y, w, h) = _parseGeometry(geometry);
        return _tryRunGnome([
          '--file=$path',
          '-a',
          '$x,$y,$w,$h',
        ]);
      }
      final flag = switch (kind) {
        ScreenshotKind.window => '-w',
        ScreenshotKind.region || ScreenshotKind.previousRegion => '-a',
        _ => '-p', // full screen (with pointer effects)
      };
      return _tryRunGnome(['--file=$path', flag]);
    }
    final imagemagick = await _which('import');
    if (imagemagick != null) {
      if (kind == ScreenshotKind.monitor) {
        // import -window with the output name captures one monitor
        final monitors = await _x11Monitors();
        if (monitor < 0 || monitor >= monitors.length) return false;
        return _tryRunImport([
          '-window',
          monitors[monitor].name,
          path,
        ]);
      }
      if (kind == ScreenshotKind.region ||
          kind == ScreenshotKind.previousRegion) {
        return _tryRunImport(['-window', 'root', path]);
      }
      return _tryRunImport([path]);
    }
    return false;
  }

  /// Capture one monitor by its geometry, using whichever tool is
  /// available.
  ///
  /// Used when the tool's native monitor selection fails: the
  /// geometry still identifies exactly one monitor, so the result is
  /// never the whole virtual screen.
  Future<bool> _captureMonitorByGeometry(String path, int monitor) async {
    final geometry = await _monitorGeometryX11(monitor);
    if (geometry == null) return false;
    final (x, y, w, h) = _parseGeometry(geometry);
    if (w <= 0 || h <= 0) return false;
    final maim = await _which('maim');
    if (maim != null) {
      // maim -g takes "WxH+X+Y"
      if (await _tryRun(['-g', geometry, path])) return true;
    }
    final scrot = await _which('scrot');
    if (scrot != null) {
      if (await _tryRunScrot(['-a', '$x,$y,$w,$h', path])) return true;
    }
    final gnome = await _which('gnome-screenshot');
    if (gnome != null) {
      if (await _tryRunGnome([
        '--file=$path',
        '-a',
        '$x,$y,$w,$h',
      ])) {
        return true;
      }
    }
    final imagemagick = await _which('import');
    if (imagemagick != null) {
      final monitors = await _x11Monitors();
      if (monitor >= 0 && monitor < monitors.length) {
        // grab the output's own screen: this is the exact monitor,
        // with no chance of picking up a neighbour
        if (await _tryRunImport([
          '-window',
          monitors[monitor].name,
          path,
        ])) {
          return true;
        }
      }
      // Fall back to cropping the root window. `+repage` drops the
      // virtual-desktop offset, so the saved image is the monitor's
      // pixels and not a canvas-sized frame with the content in a
      // corner.
      return _tryRunImport([
        '-window',
        'root',
        '-crop',
        geometry,
        '+repage',
        path,
      ]);
    }
    return false;
  }

  Future<bool> _tryRun(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('maim', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRunScrot(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('scrot', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRunGnome(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('gnome-screenshot', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRunImport(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('import', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  /// The region-selection styling the user asked for: a thick yellow
  /// border and a dark-grey background the selection text sits on.
  ///
  /// The values are the ones the selection tools take, so they are
  /// constants rather than settings: every user wants the same
  /// visible, high-contrast selection.
  ///
  /// The colours are `#rrggbbaa`, so "75% transparent" is an alpha of
  /// 0x40 (25% opaque).
  static const String regionBorderColor = '#FFFF00FF'; // yellow
  static const int regionBorderWidth = 4;
  static const String regionTextBackground = '#3C3C3C40'; // dark grey, 75% transparent
  static const String regionBackgroundColor = '#00000040'; // dimmed backdrop
  static const String regionSelectionColor = '#FFFF0040'; // yellow, 75% transparent
  static const int regionPointerSize = 48;

  /// The slop arguments that style the selection on X11.
  ///
  /// slop draws the border itself and prints the geometry, which
  /// maim then captures.
  ///
  /// slop 7.x takes the border thickness as `-b` and the colour as
  /// RGBA floats, not a hex string.
  static List<String> slopStyleArgs() => [
    '-b',
    '$regionBorderWidth',
    '-c',
    '1,1,0,1', // yellow, opaque
  ];

  /// The slurp arguments that style the selection on Wayland.
  ///
  /// `-B` is the option-box colour: the box the dimensions text is
  /// drawn on, which is the "text background" the user asked for.
  static List<String> slurpStyleArgs() => [
    '-b',
    regionBackgroundColor,
    '-c',
    regionBorderColor,
    '-s',
    regionSelectionColor,
    '-B',
    regionTextBackground,
    '-w',
    '$regionBorderWidth',
  ];

  Future<bool> _captureRegionX11(String path, ScreenshotKind kind) async {
    if (kind == ScreenshotKind.previousRegion) {
      final saved = await _loadSavedRegion();
      if (saved == null) return false;
      return _tryRun(['-g', saved, path]);
    }
    // interactive selection: slop prints geometry for maim
    final slop = await _which('slop');
    if (slop != null) {
      // slop draws its own crosshair, sized by the Xcursor theme. The
      // theme's size is an X resource, so it is raised for the
      // selection and put back afterwards.
      return _withBigCursor(() async {
        final (code, out, _) = await runCommand('slop', [
          '-f',
          '%g',
          ...slopStyleArgs(),
        ]);
        if (code != 0 || out.trim().isEmpty) return false;
        final geometry = out.trim(); // "WxH+X+Y"
        await _saveRegion(geometry);
        return _tryRun(['-g', geometry, path]);
      });
    }
    // maim has its own interactive selection without slop
    return _tryRun(['-s', path]);
  }

  /// Run [body] with a larger mouse cursor, then restore the old size.
  ///
  /// The Xcursor size lives in the X server's resource database, so it
  /// is a global, momentary change: the old value is read first and
  /// written back when the selection ends, whatever the outcome.
  Future<bool> _withBigCursor(Future<bool> Function() body) async {
    final xrdb = await _which('xrdb');
    if (xrdb == null) {
      return body();
    }
    String? previous;
    try {
      final (code, out, _) = await runCommand('xrdb', ['-query']);
      if (code == 0) {
        // the value looks like "Xcursor.size:\t32"
        for (final line in out.split('\n')) {
          if (line.startsWith('Xcursor.size:')) {
            previous = line.split(':').last.trim();
            break;
          }
        }
      }
    } catch (_) {}

    try {
      await runCommand('xrdb', [
        '-merge',
        'Xcursor.size: $regionPointerSize',
      ]);
    } catch (_) {}

    try {
      return await body();
    } finally {
      // put the old size back, or drop the resource if there was none
      try {
        if (previous == null) {
          await runCommand('xrdb', ['-remove', 'Xcursor.size']);
        } else {
          await runCommand('xrdb', [
            '-merge',
            'Xcursor.size: $previous',
          ]);
        }
      } catch (_) {}
    }
  }

  Future<String?> _activeWindowId() async {
    try {
      final (code, out, _) = await runCommand('xdotool', ['getactivewindow']);
      if (code == 0) return out.trim();
    } catch (_) {}
    return null;
  }

  /// The connected monitors reported by xrandr, in xrandr's order.
  ///
  /// Each entry is the output name and its geometry
  /// ("WxH+X+Y", imagemagick style).
  ///
  /// The "connected" match is anchored to the output name: a plain
  /// substring match also hits "disconnected", which inflated the
  /// monitor count and made the per-monitor capture pick the wrong
  /// output (or none at all).
  Future<List<X11Monitor>> _x11Monitors() async {
    try {
      final (code, out, _) = await runCommand('xrandr', ['--query']);
      if (code != 0) return const [];
      return parseXrandrMonitors(out);
    } catch (_) {
      return const [];
    }
  }

  /// The geometry of the monitor at [monitor], or null when there is
  /// no such monitor.
  Future<String?> _monitorGeometryX11(int monitor) async {
    final monitors = await _x11Monitors();
    if (monitor < 0 || monitor >= monitors.length) return null;
    return monitors[monitor].geometry;
  }

  /// Parse the monitor list out of `xrandr --query` output.
  ///
  /// Only connected outputs count, and only when they carry a current
  /// geometry. The "primary" flag is recorded but does not change the
  /// order: the monitor index in the UI follows xrandr's order, so the
  /// dropdown and the capture always agree.
  @visibleForTesting
  static List<X11Monitor> parseXrandrMonitors(String output) {
    final monitors = <X11Monitor>[];
    // "NAME connected [primary] WxH+X+Y (normal ...)"
    final pattern = RegExp(
      r'^(\S+)\s+connected(?:\s+primary)?\s+(\d+)x(\d+)\+(-?\d+)\+(-?\d+)',
      multiLine: true,
    );
    for (final m in pattern.allMatches(output)) {
      monitors.add(
        X11Monitor(
          name: m.group(1)!,
          width: int.parse(m.group(2)!),
          height: int.parse(m.group(3)!),
          x: int.parse(m.group(4)!),
          y: int.parse(m.group(5)!),
          isPrimary: RegExp(
            r'^${RegExp.escape(m.group(1)!)}\s+connected\s+primary',
            multiLine: true,
          ).hasMatch(output),
        ),
      );
    }
    return monitors;
  }

  // --------------------------------------------------------------
  // Wayland (grim + slurp)
  // --------------------------------------------------------------

  Future<bool> _captureWayland(
    String path,
    ScreenshotKind kind,
    int monitor,
  ) async {
    final grim = await _which('grim');
    if (grim == null) return false;
    switch (kind) {
      case ScreenshotKind.fullscreen:
      case ScreenshotKind.window:
      case ScreenshotKind.auto:
        return _tryRunGrim([path]);
      case ScreenshotKind.monitor:
        final output = await _waylandOutputName(monitor);
        // no output name: there is no monitor to capture. Falling back
        // to a full-screen grab would hand the user every monitor
        // when they asked for one.
        if (output == null) return false;
        return _tryRunGrim(['-o', output, path]);
      case ScreenshotKind.region:
      case ScreenshotKind.previousRegion:
        return await _captureRegionWayland(path, kind);
    }
  }

  /// grim -o wants an output *name* (e.g. HDMI-A-1), not an index.
  /// List them via wlr-randr and pick by position.
  Future<String?> _waylandOutputName(int monitor) async {
    final names = await _waylandOutputNames();
    if (monitor < 0 || monitor >= names.length) return null;
    return names[monitor];
  }

  Future<bool> _tryRunGrim(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('grim', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _captureRegionWayland(String path, ScreenshotKind kind) async {
    if (kind == ScreenshotKind.previousRegion) {
      final saved = await _loadSavedRegion();
      if (saved == null) return false;
      return _tryRunGrim(['-g', _geometryToGrim(saved), path]);
    }
    final slurp = await _which('slurp');
    if (slurp != null) {
      final (code, out, _) = await runCommand('slurp', [
        '-f',
        '%wx%h+%x+%y',
        ...slurpStyleArgs(),
      ]);
      if (code == 0 && out.trim().isNotEmpty) {
        final geometry = out.trim(); // "WxH+X+Y"
        await _saveRegion(geometry);
        return _tryRunGrim(['-g', _geometryToGrim(geometry), path]);
      }
      return false;
    }
    return false;
  }

  /// Convert "WxH+X+Y" (imagemagick/slop) to "X,Y WxH" (grim/slurp).
  static String _geometryToGrim(String geometry) {
    final m = RegExp(r'(\d+)x(\d+)\+(-?\d+)\+(-?\d+)').firstMatch(geometry);
    if (m == null) return geometry;
    return '${m.group(3)},${m.group(4)} ${m.group(1)}x${m.group(2)}';
  }

  // --------------------------------------------------------------
  // Windows (powershell CopyFromScreen)
  // --------------------------------------------------------------

  Future<bool> _captureWindows(
    String path,
    ScreenshotKind kind,
    int monitor,
  ) async {
    if (kind == ScreenshotKind.region ||
        kind == ScreenshotKind.previousRegion) {
      // interactive region selection is not supported on windows yet
      return false;
    }
    final script = await ScriptAssets.load(ScriptAssets.screenshotWindows);
    try {
      final (code, _, _) = await runCommand('powershell', [
        '-NoProfile',
        '-File',
        script,
        '-Path',
        path,
      ]);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------
  // macOS (screencapture)
  // --------------------------------------------------------------

  Future<bool> _captureMacos(String path, ScreenshotKind kind) async {
    // previous region: -R takes "x,y,w,h"
    if (kind == ScreenshotKind.previousRegion) {
      final saved = await _loadSavedRegion();
      if (saved == null) return false;
      final (x, y, w, h) = _parseGeometry(saved);
      return _tryRunScreencapture(['-R', '$x,$y,$w,$h', path]);
    }
    final args = switch (kind) {
      ScreenshotKind.window => ['-w'],
      ScreenshotKind.region => ['-i'],
      _ => ['-x'],
    };
    args.add(path);
    return _tryRunScreencapture(args);
  }

  Future<bool> _tryRunScreencapture(List<String> args) async {
    try {
      final (code, _, _) = await runCommand('screencapture', args);
      return code == 0;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------
  // saved region persistence (previous-region feature)
  // --------------------------------------------------------------

  Future<File> _regionFile() async {
    final dir = await _shotsDir();
    return File('${dir.path}/last_region.txt');
  }

  Future<bool> _hasSavedRegion() async => (await _loadSavedRegion()) != null;

  Future<String?> _loadSavedRegion() async {
    try {
      final f = await _regionFile();
      if (f.existsSync()) {
        final geo = f.readAsStringSync().trim();
        return geo.isEmpty ? null : geo;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveRegion(String geometry) async {
    try {
      final f = await _regionFile();
      f.writeAsStringSync(geometry);
    } catch (_) {}
  }

  @visibleForTesting
  Future<String?> lastRegionGeometryForTest() => _loadSavedRegion();

  Future<String?> _lastRegionGeometry() => _loadSavedRegion();

  (int, int, int, int) _parseGeometry(String geometry) {
    final m = RegExp(r'(\d+)x(\d+)\+(-?\d+)\+(-?\d+)').firstMatch(geometry);
    if (m == null) return (0, 0, 0, 0);
    return (
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    );
  }

  // --------------------------------------------------------------
  // auto capture on timer (timestamp-based)
  // --------------------------------------------------------------

  /// Runs the capture pipeline used by the UI and hotkeys:
  /// capture -> optional copy image -> optional OCR -> optional copy
  /// OCR text. Options come from [appState]. Returns the captured
  /// item (with OCR text applied) or null on failure.
  Future<ScreenshotItem?> captureWithPipeline(
    ScreenshotKind kind, {
    int monitor = 0,
    required bool autoOcr,
    required bool copyOcrText,
    required bool copyImage,
    bool autoTranslate = false,
    Future<String?> Function(String path)? ocrRunner,
    Future<void> Function(String path)? copyImageRunner,
    Future<void> Function(String text)? copyTextRunner,
    Future<String?> Function(String text)? translateRunner,
  }) async {
    final item = await capture(kind, monitor: monitor);
    if (item == null) return null;

    // runners take a file path; blob-stored payloads materialize to a
    // temp png for the duration of the call
    final toolPath = await materializePath(item);

    if (copyImage && copyImageRunner != null && toolPath != null) {
      await copyImageRunner(toolPath);
    }

    if (autoOcr && ocrRunner != null && toolPath != null) {
      var text = await ocrRunner(toolPath);
      var trimmed = text?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        if (autoTranslate && translateRunner != null) {
          final translated = await translateRunner(trimmed);
          if (translated != null && translated.trim().isNotEmpty) {
            text = translated;
            trimmed = translated.trim();
          }
        }
        setOcrText(item.id, trimmed);
        if (copyOcrText && copyTextRunner != null) {
          await copyTextRunner(trimmed);
        }
        return item.copyWith(ocrText: trimmed);
      }
    }
    return item;
  }

  /// Starts periodic capture every [intervalMinutes]. A zero or
  /// negative interval stops auto capture.
  void startAutoCapture({
    required int intervalMinutes,
    required Future<void> Function(ScreenshotItem item) onCaptured,
  }) {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (intervalMinutes <= 0) {
      notifyListeners();
      return;
    }
    _autoTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) async {
      final item = await capture(ScreenshotKind.auto);
      if (item != null) await onCaptured(item);
    });
    notifyListeners();
  }

  void stopAutoCapture() {
    _autoTimer?.cancel();
    _autoTimer = null;
    notifyListeners();
  }

  /// Update the OCR text of a stored item (after auto-OCR completes).
  void setOcrText(String id, String text) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(ocrText: text);
    notifyListeners();
    _persist();
  }

  /// Sets the user-facing name of an item.
  void rename(String id, String name) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(name: name.trim());
    notifyListeners();
    _persist();
  }

  /// Hides or shows an item. Hidden items stay in the registry but are
  /// filtered out of the views.
  void setHidden(String id, bool hidden) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(hidden: hidden);
    notifyListeners();
    _persist();
  }

  /// Replaces the OCR text of an item (the manager's edit action).
  void editOcrText(String id, String text) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(ocrText: text.trim());
    notifyListeners();
    _persist();
  }

  /// The absolute path of an item's image on disk. Blob-stored items
  /// are materialized into a temp file; the caller owns it.
  Future<String?> absolutePath(ScreenshotItem item) =>
      materializePath(item);

  /// The path of an item relative to the screenshot directory, for
  /// display. Null when the item does not live under that directory.
  String? relativePath(ScreenshotItem item) {
    if (!MediaRef.isFile(item.path)) return null;
    final dir = directoryOverride.trim();
    if (dir.isEmpty) return null;
    final normalized = dir.endsWith('/') ? dir : '$dir/';
    return item.path.startsWith(normalized)
        ? item.path.substring(normalized.length)
        : null;
  }

  /// The pixel dimensions of an item's image, or null when the payload
  /// cannot be decoded.
  Future<({int width, int height})?> imageSize(ScreenshotItem item) async {
    final bytes = await AppStorage.readMedia(item.path);
    if (bytes == null) return null;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return (width: decoded.width, height: decoded.height);
    } catch (_) {
      return null;
    }
  }

  /// Crops an item to [rect] and replaces the stored image with the
  /// cropped version. Returns the new item, or null when the crop
  /// failed.
  Future<ScreenshotItem?> crop(
    ScreenshotItem item,
    ScreenshotCropRect rect,
  ) async {
    final bytes = await AppStorage.readMedia(item.path);
    if (bytes == null) return null;
    final cropped = _cropBytes(bytes, rect);
    if (cropped == null) return null;

    final newRef = await AppStorage.writeMedia(cropped);
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index < 0) {
      await AppStorage.deleteMedia(newRef);
      return null;
    }
    final updated = _items[index].copyWith(path: newRef);
    _items[index] = updated;
    // the old payload is replaced, not kept
    unawaited(AppStorage.deleteMedia(item.path));
    notifyListeners();
    _persist();
    return updated;
  }

  /// Crops PNG bytes with the `image` package. Returns null when the
  /// crop is out of bounds or the bytes cannot be decoded.
  static Uint8List? _cropBytes(Uint8List bytes, ScreenshotCropRect rect) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      if (rect.left < 0 ||
          rect.top < 0 ||
          rect.width <= 0 ||
          rect.height <= 0 ||
          rect.right > decoded.width ||
          rect.bottom > decoded.height) {
        return null;
      }
      final cropped = img.copyCrop(
        decoded,
        rect.left,
        rect.top,
        rect.width,
        rect.height,
      );
      return Uint8List.fromList(img.encodePng(cropped));
    } catch (e) {
      debugPrint('ScreenshotService: crop failed: $e');
      return null;
    }
  }

  /// Delete one screenshot (file + registry entry).
  void remove(String id) {
    final item = _items.where((i) => i.id == id).firstOrNull;
    _items.removeWhere((i) => i.id == id);
    if (item != null) {
      unawaited(AppStorage.deleteMedia(item.path));
    }
    notifyListeners();
    _persist();
  }

  void clear() {
    for (final item in _items) {
      unawaited(AppStorage.deleteMedia(item.path));
    }
    _items = [];
    notifyListeners();
    _persist();
  }

  /// Materialize [item]'s image as a real file path for tools that need
  /// one (OCR runners, external copy helpers). Blob refs are written to
  /// a temp png; file refs return their path unchanged.
  Future<String?> materializePath(ScreenshotItem item) async {
    if (MediaRef.isFile(item.path)) return item.path;
    final bytes = await AppStorage.readMedia(item.path);
    if (bytes == null) return null;
    final dir = await Directory.systemTemp.createTemp('shot_ref');
    final f = File('${dir.path}/${item.id}.png');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  /// The monitors this machine has, in capture-index order.
  ///
  /// The list is empty when the platform cannot report its outputs;
  /// callers then fall back to a single, unnamed monitor.
  ///
  /// The X11 list comes from `xrandr --query` and only counts
  /// *connected* outputs: a plain "connected" substring match also
  /// hits "disconnected", which inflated the count and made the
  /// per-monitor capture pick the wrong output.
  Future<List<ScreenshotMonitor>> monitors() async {
    final platform = await detectPlatform();
    switch (platform) {
      case ScreenshotPlatform.x11:
        final x11 = await _x11Monitors();
        if (x11.isEmpty) return const [];
        return [
          for (final m in x11)
            ScreenshotMonitor(
              name: m.name,
              width: m.width,
              height: m.height,
              isPrimary: m.isPrimary,
            ),
        ];
      case ScreenshotPlatform.wayland:
        final names = await _waylandOutputNames();
        if (names.isEmpty) return const [];
        return [
          for (final n in names) ScreenshotMonitor(name: n),
        ];
      default:
        return const [];
    }
  }

  /// Monitor count for the settings UI.
  Future<int> monitorCount() async {
    final list = await monitors();
    if (list.isEmpty) return 1;
    return list.length;
  }

  /// The Wayland output names, in wlr-randr's order.
  ///
  /// wlr-randr prints one block per output: the output name starts at
  /// column 0 and its properties (`Position:`, `Mode:`, ...) are
  /// indented. Only the unindented lines are output names — matching
  /// every line picked up the properties as well, which inflated the
  /// monitor count and made the per-monitor capture pick the wrong
  /// output (or capture every output).
  Future<List<String>> _waylandOutputNames() async {
    try {
      final (code, out, _) = await runCommand('wlr-randr', []);
      if (code != 0) return const [];
      return parseWaylandOutputNames(out);
    } catch (_) {
      return const [];
    }
  }

  /// The output names in `wlr-randr` output.
  ///
  /// wlr-randr prints one block per output: the output name starts at
  /// column 0 and its properties (`Position:`, `Mode:`, `Transform:`)
  /// are indented. Only the unindented lines are output names.
  @visibleForTesting
  static List<String> parseWaylandOutputNames(String output) {
    final names = <String>[];
    for (final line in output.split('\n')) {
      if (line.isEmpty || line.startsWith(' ')) continue;
      final name = line.split(RegExp(r'\s')).first;
      if (name.isEmpty) continue;
      names.add(name);
    }
    return names;
  }

  /// Raw image bytes of a stored screenshot (blob or file ref).
  Future<Uint8List?> readImage(String id) async {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item == null) return null;
    return AppStorage.readMedia(item.path);
  }

  /// The file size of a stored screenshot, in bytes.
  ///
  /// Blob-stored screenshots have no file on disk, so their size comes
  /// from the stored bytes.
  Future<int> fileSize(ScreenshotItem item) async {
    final file = File(item.path);
    try {
      if (file.existsSync()) return await file.length();
    } catch (_) {}
    final bytes = await AppStorage.readMedia(item.path);
    return bytes?.length ?? 0;
  }

}
