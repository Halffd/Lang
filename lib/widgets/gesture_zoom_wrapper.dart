import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../models/app_state.dart';

class GestureZoomWrapper extends StatefulWidget {
  final Widget child;

  const GestureZoomWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<GestureZoomWrapper> createState() => _GestureZoomWrapperState();
}

class _GestureZoomWrapperState extends State<GestureZoomWrapper> {
  double? _initialScale;
  double? _initialFontSize;
  double? _lastScale;
  double? _lastFontSize;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    // Only add zoom functionality on mobile platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return widget.child;
    }

    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        // Handle mouse wheel for zoom on mobile platforms only
        if (event is PointerScrollEvent) {
          // For simplicity, we're not checking for control keys in this version
          // as it requires more complex handling
          final scrollDirection = event.scrollDelta.dy < 0 ? 1.0 : -1.0;
          final zoomIncrement = 0.1;
          final newZoomLevel = (appState.zoomLevel + (scrollDirection * zoomIncrement)).clamp(0.5, 3.0);
          appState.setZoomLevel(newZoomLevel);
        }
      },
      child: RawKeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKey: (RawKeyEvent event) {
          // Handle keyboard shortcuts for zoom
          if (event.isControlPressed) {
            if (event.logicalKey.keyId == 0x0000003D || // Equal sign (=)
                event.logicalKey.keyId == 0x0000002B || // Plus sign (+)
                event.logicalKey.keyLabel == '=') {
              // Zoom in with Ctrl + = or Ctrl + +
              final newZoomLevel = (appState.zoomLevel + 0.1).clamp(0.5, 3.0);
              appState.setZoomLevel(newZoomLevel);
            } else if (event.logicalKey.keyId == 0x0000002D) { // Minus sign (-)
              // Zoom out with Ctrl + -
              final newZoomLevel = (appState.zoomLevel - 0.1).clamp(0.5, 3.0);
              appState.setZoomLevel(newZoomLevel);
            } else if (event.logicalKey.keyId == 0x00000030) { // Digit 0
              // Reset zoom with Ctrl + 0
              appState.setZoomLevel(1.0);
            }
          }
        },
        child: GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: widget.child,
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _lastFontSize = 1.0;

    final appState = context.read<AppState>();
    _initialScale = appState.zoomLevel;
    _initialFontSize = appState.fontSizeMultiplier;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_initialScale == null || _initialFontSize == null) return;

    final appState = context.read<AppState>();

    // Calculate the new zoom level based on the scale factor
    // details.scale represents the cumulative scale factor since the start of the gesture
    final newZoom = (_initialScale! * details.scale).clamp(0.5, 3.0);
    appState.setZoomLevel(newZoom);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _initialScale = null;
    _initialFontSize = null;
    _lastScale = null;
    _lastFontSize = null;
  }
}