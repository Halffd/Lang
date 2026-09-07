import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Callback type for OCR results of clipboard images.
typedef OnClipboardImageOcr = Future<void> Function(String recognizedText);

/// Polls the system clipboard and reacts to copied content according to
/// the clipboard settings:
///
/// - mode `historyOnly`: record text/images to activity history
/// - mode `autoSearch`: record and trigger [onClipboardChanged]
///   (text) or auto-OCR (images) when gates pass
/// - mode `off`: no monitoring
///
/// Gates for auto search / auto OCR:
/// - [AppState.clipboardAutoSearchFocusedOnly]: app window must have
///   focus
/// - [AppState.clipboardAutoSearchRegex]: custom regex the text must
///   match (a `ja` shorthand matches any Japanese character)
///
/// Images are detected through the rich clipboard (super_clipboard);
/// recognized text is recorded and searched in autoSearch mode.
class ClipboardMonitorService {
  /// Shared instance started from main.dart.
  static final ClipboardMonitorService instance = ClipboardMonitorService();

  Timer? _timer;
  String _lastClipboardContent = '';
  String? _lastImageHash;
  bool _isMonitoring = false;

  // Callback to notify when clipboard text should be searched
  Function(String)? onClipboardChanged;

  /// OCR engine hook, injected from main.dart. Returns recognized
  /// text or null on failure/no text.
  Future<String?> Function(Uint8List imageBytes)? onClipboardImage;

  /// Where the app is currently focused (overridable in tests).
  bool Function()? isAppFocused = _defaultIsAppFocused;

  static bool _defaultIsAppFocused() =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive;

  /// Default focus check (public for tests).
  static final bool Function() defaultIsAppFocused = _defaultIsAppFocused;

  /// Content hash exposed for tests.
  @visibleForTesting
  static String hashBytesForTest(Uint8List bytes) => _hashBytes(bytes);

  // Check clipboard every 500ms
  static const Duration _checkInterval = Duration(milliseconds: 500);

  /// Simple content hash to detect image changes (super_clipboard
  /// has no change notification, so compare bytes length + sample).
  static String _hashBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    var h = bytes.length;
    for (var i = 0; i < bytes.length; i += 997) {
      h = (h * 31 + bytes[i]) & 0x7fffffff;
    }
    return '$h';
  }

  void startMonitoring(AppState appState) {
    if (_isMonitoring) return;
    if (appState.clipboardAutoSearchMode == ClipboardAutoSearchMode.off) {
      return;
    }

    _isMonitoring = true;
    _timer = Timer.periodic(_checkInterval, (timer) async {
      if (!_isMonitoring) return;
      try {
        await _poll(appState);
      } catch (_) {
        // ignore clipboard read failures (e.g. platform channel issues)
      }
    });
  }

  Future<void> _poll(AppState appState) async {
    // 1) text clipboard
    final ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    final currentContent = clipboardData?.text ?? '';

    if (currentContent.isNotEmpty && currentContent != _lastClipboardContent) {
      _lastClipboardContent = currentContent;
      _lastImageHash = null;

      final trimmed = currentContent.trim();
      if (trimmed.isNotEmpty) {
        HistoryService.instance.record(
          HistoryCategory.clipboard,
          trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed,
          subtitle: trimmed,
        );

        if (appState.clipboardAutoSearchMode ==
                ClipboardAutoSearchMode.autoSearch &&
            onClipboardChanged != null &&
            gatesPass(appState, trimmed)) {
          onClipboardChanged!(trimmed);
        }
      }
      return;
    }

    // 2) image clipboard (only when no text was copied)
    if (_lastClipboardContent.isEmpty) {
      await _pollImage(appState);
    }
  }

  Future<void> _pollImage(AppState appState) async {
    try {
      final reader = await ClipboardReader.readClipboard();
      final format = reader.hasValue(Formats.png)
          ? Formats.png
          : (reader.hasValue(Formats.jpeg) ? Formats.jpeg : null);
      if (format == null) return;

      final bytes = await reader.readValue(format);
      if (bytes == null || bytes.isEmpty) return;

      final hash = _hashBytes(bytes);
      if (hash == _lastImageHash) return;
      _lastImageHash = hash;

      // record image with small thumbnail
      final thumb = await _makeThumbnail(bytes);
      HistoryService.instance.recordImage(thumb, subtitle: 'image');

      // auto OCR in autoSearch mode (gates apply to recognized text)
      if (appState.clipboardAutoSearchMode ==
              ClipboardAutoSearchMode.autoSearch &&
          onClipboardImage != null) {
        final text = await onClipboardImage!(bytes);
        final trimmedText = text?.trim() ?? '';
        if (trimmedText.isNotEmpty) {
          HistoryService.instance.record(
            HistoryCategory.clipboard,
            trimmedText.length > 60
                ? '${trimmedText.substring(0, 60)}…'
                : trimmedText,
            subtitle: trimmedText,
          );
          if (onClipboardChanged != null && gatesPass(appState, trimmedText)) {
            onClipboardChanged!(trimmedText);
          }
        }
      }
    } catch (_) {
      // rich clipboard not available on this platform
    }
  }

  /// Downscale to a small PNG thumbnail for the history list.
  static Future<List<int>> _makeThumbnail(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List().toList() ?? const [];
    } catch (_) {
      return bytes.length > 64 * 1024 ? const [] : bytes.toList();
    }
  }

  /// Focus and regex gates for auto search.
  @visibleForTesting
  static bool gatesPass(AppState appState, String text) {
    // focus gate
    if (appState.clipboardAutoSearchFocusedOnly &&
        !(instance.isAppFocused?.call() ?? true)) {
      return false;
    }

    // regex / language gate
    final pattern = appState.clipboardAutoSearchRegex.trim();
    if (pattern.isEmpty) return true;
    if (pattern == 'ja') {
      // any Japanese character (hiragana, katakana, CJK ideographs)
      return RegExp(
        r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\u30FC\uFF66-\uFF9D]',
      ).hasMatch(text);
    }
    try {
      return RegExp(pattern).hasMatch(text);
    } catch (_) {
      // invalid user regex: treat as no gate
      return true;
    }
  }

  /// Restart monitoring after settings changed.
  void restartMonitoring(AppState appState) {
    stopMonitoring();
    startMonitoring(appState);
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _timer?.cancel();
    _timer = null;
  }

  bool get isMonitoring => _isMonitoring;
}
