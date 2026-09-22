import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Duolingo-style flip card. `front` is shown until [isBack] is true, then
/// it flips over 300ms to show `back`. Tap fires [onTap] (caller flips state).
class FlipCard extends StatelessWidget {
  final Widget front;
  final Widget back;
  final bool isBack;
  final VoidCallback? onTap;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.isBack = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(isBack ? math.pi / 2 : 0),
        transformAlignment: Alignment.center,
        curve: Curves.easeInOut,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: isBack
                ? _Face(
                    key: const Key('back'),
                    color: Colors.indigo[600]!,
                    child: back,
                  )
                : _Face(
                    key: const Key('front'),
                    color: Colors.white,
                    child: front,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Face({required super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: Center(child: child),
    );
  }
}
