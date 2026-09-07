import 'dart:async';
import 'package:flutter/services.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';

/// Polls the system clipboard and records copied text into the
/// activity history. The [onClipboardChanged] callback additionally
/// fires when the clipboard monitor setting is enabled (used for
/// auto-analysis features).
class ClipboardMonitorService {
  Timer? _timer;
  String _lastClipboardContent = '';
  bool _isMonitoring = false;

  // Callback to notify when clipboard content changes
  Function(String)? onClipboardChanged;

  // Check clipboard every 500ms
  static const Duration _checkInterval = Duration(milliseconds: 500);

  void startMonitoring(AppState appState) {
    if (_isMonitoring) return;

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

          // Always record into clipboard history
          final trimmed = currentContent.trim();
          if (trimmed.isNotEmpty) {
            HistoryService.instance.record(
              HistoryCategory.clipboard,
              trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed,
              subtitle: trimmed,
            );
          }

          // Process the new clipboard content
          _processClipboardContent(currentContent, appState);
        }
      } catch (e) {
        // ignore clipboard read failures (e.g. platform channel issues)
      }
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _timer?.cancel();
    _timer = null;
  }

  void _processClipboardContent(String content, AppState appState) {
    // Only process if the clipboard monitor setting is enabled
    if (appState.clipboardMonitor && onClipboardChanged != null) {
      onClipboardChanged!(content);
    }
  }

  bool get isMonitoring => _isMonitoring;
}
