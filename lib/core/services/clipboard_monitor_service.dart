import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/app_state.dart';

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
        final ClipboardData? clipboardData = await Clipboard.getData('text/plain');
        final currentContent = clipboardData?.text ?? '';

        // Only trigger if content has changed and is not empty
        if (currentContent.isNotEmpty && currentContent != _lastClipboardContent) {
          _lastClipboardContent = currentContent;

          // Process the new clipboard content
          _processClipboardContent(currentContent, appState);
        }
      } catch (e) {
        print('Error monitoring clipboard: $e');
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