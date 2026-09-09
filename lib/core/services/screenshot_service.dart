import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  const ScreenshotItem({
    required this.id,
    required this.path,
    required this.kind,
    required this.timestamp,
    this.ocrText,
    this.geometry,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'kind': kind.name,
    'timestamp': timestamp,
    'ocrText': ocrText,
    'geometry': geometry,
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
  );

  ScreenshotItem copyWith({String? ocrText, String? geometry}) =>
      ScreenshotItem(
        id: id,
        path: path,
        kind: kind,
        timestamp: timestamp,
        ocrText: ocrText ?? this.ocrText,
        geometry: geometry ?? this.geometry,
      );

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

/// Abstraction over Process.run so tests can inject fake command
/// runners without spawning real screenshot tools.
typedef CommandRunner =
    Future<(int, String, String)> Function(
      String executable,
      List<String> arguments,
    );

enum ScreenshotPlatform { x11, wayland, windows, macos, unsupported }

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

  /// Directory where screenshots are written.
  Future<Directory> _shotsDir() async {
    final dir = await dirProvider();
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
  }

  /// Detect the screenshot backend usable on this machine.
  Future<ScreenshotPlatform> detectPlatform() async {
    if (Platform.isWindows) return ScreenshotPlatform.windows;
    if (Platform.isMacOS) return ScreenshotPlatform.macos;
    if (Platform.isLinux) {
      // Wayland tools take priority when a Wayland session is active.
      if (Platform.environment['WAYLAND_DISPLAY'] != null &&
          (await _which('grim')) != null) {
        return ScreenshotPlatform.wayland;
      }
      if (Platform.environment['DISPLAY'] != null &&
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
      final dir = await _shotsDir();
      final file = File('${dir.path}/$_prefsFile');
      if (file.existsSync()) {
        final decoded =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
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
      final dir = await _shotsDir();
      final file = File('${dir.path}/$_prefsFile');
      file.writeAsStringSync(jsonEncode({'items': _items}));
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
    final ok = switch (platform) {
      ScreenshotPlatform.x11 => await _captureX11(path, kind, monitor),
      ScreenshotPlatform.wayland => await _captureWayland(path, kind, monitor),
      ScreenshotPlatform.windows => await _captureWindows(path, kind, monitor),
      ScreenshotPlatform.macos => await _captureMacos(path, kind),
      ScreenshotPlatform.unsupported => false,
    };
    if (!ok) return null;

    // remember interactive region geometry for previousRegion
    if (kind == ScreenshotKind.region) {
      geometry = await _lastRegionGeometry();
    }

    final item = ScreenshotItem(
      id: id,
      path: path,
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
          // maim captures monitor n natively
          if (await _tryRun(['-m', '$monitor', path])) return true;
          return _tryRun([path]);
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
          final geometry = await _monitorGeometryX11(monitor);
          if (geometry == null) return _tryRunScrot([path]);
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
      final flag = switch (kind) {
        ScreenshotKind.window => '-w',
        ScreenshotKind.region || ScreenshotKind.previousRegion => '-a',
        _ => '-p', // full screen (with pointer effects)
      };
      return _tryRunGnome(['--file=$path', flag]);
    }
    final imagemagick = await _which('import');
    if (imagemagick != null) {
      if (kind == ScreenshotKind.region ||
          kind == ScreenshotKind.previousRegion) {
        return _tryRunImport(['-window', 'root', path]);
      }
      return _tryRunImport([path]);
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

  Future<bool> _captureRegionX11(String path, ScreenshotKind kind) async {
    // previous region: reuse saved geometry with maim -g
    if (kind == ScreenshotKind.previousRegion) {
      final saved = await _loadSavedRegion();
      if (saved == null) return false;
      return _tryRun(['-g', saved, path]);
    }
    // interactive selection: slop prints geometry for maim
    final slop = await _which('slop');
    if (slop != null) {
      final (code, out, _) = await runCommand('slop', ['-f', '%g']);
      if (code == 0 && out.trim().isNotEmpty) {
        final geometry = out.trim(); // "WxH+X+Y"
        await _saveRegion(geometry);
        return _tryRun(['-g', geometry, path]);
      }
      return false;
    }
    // maim has its own interactive selection without slop
    return _tryRun(['-s', path]);
  }

  Future<String?> _activeWindowId() async {
    try {
      final (code, out, _) = await runCommand('xdotool', ['getactivewindow']);
      if (code == 0) return out.trim();
    } catch (_) {}
    return null;
  }

  Future<String?> _monitorGeometryX11(int monitor) async {
    try {
      final (code, out, _) = await runCommand('xrandr', ['--query']);
      if (code != 0) return null;
      final connected = RegExp(
        r'connected(?: primary)?\s+(\d+)x(\d+)\+(\d+)\+(\d+)',
        multiLine: true,
      );
      final matches = connected.allMatches(out).toList();
      if (monitor < matches.length) {
        final m = matches[monitor];
        // imagemagick-style geometry "WxH+X+Y"
        return '${m.group(1)}x${m.group(2)}+${m.group(3)}+${m.group(4)}';
      }
    } catch (_) {}
    return null;
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
        if (output == null) return _tryRunGrim([path]);
        return _tryRunGrim(['-o', output, path]);
      case ScreenshotKind.region:
      case ScreenshotKind.previousRegion:
        return await _captureRegionWayland(path, kind);
    }
  }

  /// grim -o wants an output *name* (e.g. HDMI-A-1), not an index.
  /// List them via wlr-randr and pick by position.
  Future<String?> _waylandOutputName(int monitor) async {
    try {
      final (code, out, _) = await runCommand('wlr-randr', []);
      if (code != 0) return null;
      final names = RegExp(r'^([A-Za-z0-9-]+)', multiLine: true)
          .allMatches(out)
          .map((m) => m.group(1)!)
          .where((n) => !n.startsWith('Position:') && !n.startsWith('Mode:'))
          .toList();
      if (monitor < names.length) return names[monitor];
    } catch (_) {}
    return null;
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
      final (code, out, _) = await runCommand('slurp', ['-f', '%wx%h+%x+%y']);
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
    final script =
        '''
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
\$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
\$bmp = New-Object System.Drawing.Bitmap \$b.Width, \$b.Height
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.CopyFromScreen(\$b.X, \$b.Y, 0, 0, \$bmp.Size)
\$g.Dispose()
\$bmp.Save("$path", [System.Drawing.Imaging.ImageFormat]::Png)
''';
    try {
      final (code, _, _) = await runCommand('powershell', [
        '-NoProfile',
        '-Command',
        script,
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
    Future<String?> Function(String path)? ocrRunner,
    Future<void> Function(String path)? copyImageRunner,
    Future<void> Function(String text)? copyTextRunner,
  }) async {
    final item = await capture(kind, monitor: monitor);
    if (item == null) return null;

    if (copyImage && copyImageRunner != null) {
      await copyImageRunner(item.path);
    }

    if (autoOcr && ocrRunner != null) {
      final text = await ocrRunner(item.path);
      final trimmed = text?.trim() ?? '';
      if (trimmed.isNotEmpty) {
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

  /// Delete one screenshot (file + registry entry).
  void remove(String id) {
    final item = _items.where((i) => i.id == id).firstOrNull;
    _items.removeWhere((i) => i.id == id);
    if (item != null) {
      try {
        final f = File(item.path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
    _persist();
  }

  void clear() {
    for (final item in _items) {
      try {
        final f = File(item.path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    _items = [];
    notifyListeners();
    _persist();
  }

  /// Monitor count for the settings UI.
  Future<int> monitorCount() async {
    final platform = await detectPlatform();
    switch (platform) {
      case ScreenshotPlatform.x11:
        try {
          final (code, out, _) = await runCommand('xrandr', ['--query']);
          if (code == 0) {
            return RegExp(r'connected', multiLine: true).allMatches(out).length;
          }
        } catch (_) {}
        return 1;
      case ScreenshotPlatform.wayland:
        final name = await _waylandOutputName(0);
        return name == null ? 1 : await _waylandOutputCount();
      default:
        return 1;
    }
  }

  Future<int> _waylandOutputCount() async {
    try {
      final (code, out, _) = await runCommand('wlr-randr', []);
      if (code == 0) {
        return RegExp(r'^[A-Z]', multiLine: true).allMatches(out).length;
      }
    } catch (_) {}
    return 1;
  }

  /// Raw image bytes of a stored screenshot.
  Future<Uint8List?> readImage(String id) async {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item == null) return null;
    try {
      return await File(item.path).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
