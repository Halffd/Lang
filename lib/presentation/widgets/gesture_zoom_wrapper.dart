import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:lang/domain/entities/app_state.dart';

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
    if (!Platform.isIOS && !Platform.isAndroid) {
      return widget.child;
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleScroll(event, context, appState);
        }
      },
      child: widget.child,
    );
  }

  void _handleScroll(PointerScrollEvent event, BuildContext context, AppState appState) {
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
      final scale = appState.fontScale;
      final newScale = (scale + event.scrollDelta.dy * -0.001).clamp(0.5, 3.0);
      appState.setFontScale(newScale);
    }
  }
}