import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_zoom.dart';

/// Global text zoom: ctrl+scroll wheel and two-finger pinch adjust the
/// app-wide [AppState.fontSizeMultiplier] (persisted, clamped by
/// [FontZoom.minMultiplier]..[FontZoom.maxMultiplier]).
///
/// Listener is translucent — gestures still reach the content below; zoom
/// is additive like browser zoom.
class FontZoomScope extends StatefulWidget {
  final Widget child;

  const FontZoomScope({super.key, required this.child});

  @override
  State<FontZoomScope> createState() => _FontZoomScopeState();
}

class _FontZoomScopeState extends State<FontZoomScope> {
  // active touch pointers for pinch tracking
  final Map<int, Offset> _touchPointers = {};
  double? _pinchStartDistance;
  double? _pinchStartScale;

  // ctrl+scroll accumulation, applied in one step-sized chunk per notch
  double _scrollAccum = 0;
  Timer? _scrollDebounce;

  static const _debounce = Duration(milliseconds: 60);

  void _applyZoom(double delta) {
    final appState = context.read<AppState>();
    final current = appState.fontSizeMultiplier;
    final next = (current + delta).clamp(
      FontZoom.minMultiplier,
      FontZoom.maxMultiplier,
    );
    if (next != current) appState.setFontSizeMultiplier(next);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed) return;

    // browser convention: wheel/trackpad up (negative dy) = zoom in
    final step = context.read<AppState>().fontZoomStep;
    _scrollAccum += event.scrollDelta.dy < 0 ? step : -step;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(_debounce, () {
      // Always clear the accumulator, even for a sub-threshold flick:
      // leftover would combine with the next gesture and cause a phantom
      // zoom jump.
      final pending = _scrollAccum;
      _scrollAccum = 0;
      if (pending.abs() >= step * 0.5) _applyZoom(pending);
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.trackpad) {
      _touchPointers[event.pointer] = event.position;
      if (_touchPointers.length == 2) {
        final pts = _touchPointers.values.toList();
        _pinchStartDistance = (pts[0] - pts[1]).distance;
        _pinchStartScale = context.read<AppState>().fontSizeMultiplier;
      }
    }
  }

  void _handlePointerMove(PointerEvent event) {
    if (!_touchPointers.containsKey(event.pointer)) return;
    _touchPointers[event.pointer] = event.position;
    if (_touchPointers.length == 2 && _pinchStartDistance != null) {
      final pts = _touchPointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      if (_pinchStartDistance! > 10) {
        final ratio = dist / _pinchStartDistance!;
        final appState = context.read<AppState>();
        final next = ((_pinchStartScale ?? 1.0) * ratio).clamp(
          FontZoom.minMultiplier,
          FontZoom.maxMultiplier,
        );
        if (next != appState.fontSizeMultiplier) {
          appState.setFontSizeMultiplier(next);
        }
      }
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _touchPointers.remove(event.pointer);
    if (_touchPointers.length < 2) {
      _pinchStartDistance = null;
      _pinchStartScale = null;
    }
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handlePointerSignal,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: widget.child,
    );
  }
}
