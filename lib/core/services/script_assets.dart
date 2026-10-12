import 'package:flutter/services.dart' show rootBundle;

/// Loader for the standalone helper scripts in `assets/scripts/`.
///
/// The Python/PowerShell snippets the services run used to live as
/// string literals inside the Dart sources; they now ship as separate
/// files (easier to lint, test and edit) and are read from the asset
/// bundle at runtime.
class ScriptAssets {
  ScriptAssets._();

  static const String easyOcrRecognize = 'assets/scripts/easyocr_recognize.py';
  static const String trocrRecognize = 'assets/scripts/trocr_recognize.py';
  static const String screenshotWindows =
      'assets/scripts/screenshot_windows.ps1';

  static final Map<String, String> _cache = {};

  /// Content of [assetPath]; cached per path. Throws when the asset is
  /// missing from the bundle (a packaging bug, surfaced loudly).
  static Future<String> load(String assetPath) async {
    final hit = _cache[assetPath];
    if (hit != null) return hit;
    final content = await rootBundle.loadString(assetPath);
    _cache[assetPath] = content;
    return content;
  }

  /// Test hook: pre-seed a script so services can run without the
  /// asset bundle.
  static void seed(String assetPath, String content) =>
      _cache[assetPath] = content;

  static void clearCache() => _cache.clear();
}
