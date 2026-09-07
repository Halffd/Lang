import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';

/// Polls the system clipboard and reacts to copied text according to
/// the clipboard settings:
///
/// - mode `historyOnly`: record to activity history
/// - mode `autoSearch`: record and trigger [onClipboardChanged]
///   (wired to auto search) when gates pass
/// - mode `off`: no monitoring
///
/// Gates for auto search:
/// - [AppState.clipboardAutoSearchFocusedOnly]: app window must have
///   focus
/// - [AppState.clipboardAutoSearchRegex]: custom regex the text must
///   match (a `ja` shorthand matches any Japanese character)
class ClipboardMonitorService {
  /// Shared instance started from main.dart.
  static final ClipboardMonitorService instance = ClipboardMonitorService();

  Timer? _timer;
  String _lastClipboardContent = '';
  bool _isMonitoring = false;

  // Callback to notify when clipboard content should be searched
  Function(String)? onClipboardChanged;

  // Check clipboard every 500ms
  static const Duration _checkInterval = Duration(milliseconds: 500);

  void startMonitoring(AppState appState) {
    if (_isMonitoring) return;
    if (appState.clipboardAutoSearchMode == ClipboardAutoSearchMode.off) {
      return;
    }

    _isMonitoring = true;
    _timer = Timer.periodic(_checkInterval, (timer) async {
      if (!_isMonitoring) return;

      try {
        final ClipboardData? clipboardData = await Clipboard.getData(
          'text/plain',
        );
        final currentContent = clipboardData?.text ?? '';

        // Only trigger if content has changed and is not empty
        if (currentContent.isNotEmpty &&
            currentContent != _lastClipboardContent) {
          _lastClipboardContent = currentContent;

          final trimmed = currentContent.trim();
          // Always record into clipboard history in historyOnly and
          // autoSearch modes
          if (appState.clipboardAutoSearchMode != ClipboardAutoSearchMode.off &&
              trimmed.isNotEmpty) {
            HistoryService.instance.record(
              HistoryCategory.clipboard,
              trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed,
              subtitle: trimmed,
            );
          }

          // Auto search only in autoSearch mode when all gates pass
          if (appState.clipboardAutoSearchMode ==
                  ClipboardAutoSearchMode.autoSearch &&
              onClipboardChanged != null &&
              trimmed.isNotEmpty &&
              gatesPass(appState, trimmed)) {
            onClipboardChanged!(trimmed);
          }
        }
      } catch (e) {
        // ignore clipboard read failures (e.g. platform channel issues)
      }
    });
  }

  /// Focus and regex gates for auto search.
  @visibleForTesting
  static bool gatesPass(AppState appState, String text) {
    // focus gate
    if (appState.clipboardAutoSearchFocusedOnly &&
        !WidgetsBinding.instance.lifecycleState.isActive) {
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

extension on AppLifecycleState? {
  /// Whether the app is in the foreground (resumed/inactive still
  /// counts as focused for desktop window semantics).
  bool get isActive =>
      this == null ||
      this == AppLifecycleState.resumed ||
      this == AppLifecycleState.inactive;
}
