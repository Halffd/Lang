import 'package:flutter/material.dart';
import 'layout_config.dart';

enum ScreenType { compact, medium, expanded }

class ScreenSize {
  static const double compactMax = 360;
  static const double mediumMax = 600;

  static ScreenType type(BuildContext context) {
    final mode = LayoutConfig.instance.mode;
    if (mode != LayoutMode.auto) {
      return switch (mode) {
        LayoutMode.mobile => ScreenType.compact,
        LayoutMode.tablet => ScreenType.medium,
        LayoutMode.desktop || LayoutMode.centered => ScreenType.expanded,
        LayoutMode.auto => ScreenType.expanded, // unreachable
      };
    }
    final width = MediaQuery.of(context).size.width;
    if (width <= compactMax) return ScreenType.compact;
    if (width <= mediumMax) return ScreenType.medium;
    return ScreenType.expanded;
  }

  static bool isCompact(BuildContext context) =>
      type(context) == ScreenType.compact;

  static bool isMobile(BuildContext context) =>
      type(context) != ScreenType.expanded;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static T select<T>(
    BuildContext context, {
    required T compact,
    T? medium,
    T? expanded,
  }) {
    switch (type(context)) {
      case ScreenType.compact:
        return compact;
      case ScreenType.medium:
        return medium ?? compact;
      case ScreenType.expanded:
        return expanded ?? medium ?? compact;
    }
  }

  static EdgeInsets adaptivePadding(BuildContext context) {
    final scale = LayoutConfig.instance.paddingScale;
    final w = width(context);
    if (w <= compactMax) return EdgeInsets.all(8 * scale);
    if (w <= mediumMax) return EdgeInsets.all(12 * scale);
    return EdgeInsets.all(16 * scale);
  }

  /// Standard card margin, scaled by the `marginScale` layout setting.
  static EdgeInsets adaptiveMargin(BuildContext context) {
    final scale = LayoutConfig.instance.marginScale;
    final w = width(context);
    final base = w <= compactMax ? 4.0 : (w <= mediumMax ? 8.0 : 12.0);
    return EdgeInsets.symmetric(vertical: base * scale, horizontal: 4.0);
  }

  /// Standard border radius (scaled). Multiplied onto a base radius.
  static double adaptiveRadius(double base) =>
      base * LayoutConfig.instance.borderRadiusScale;

  /// Width cap for scroll content; expanded = up to `maxWidth` centered.
  /// Also respects LayoutMode.centered.
  static double contentWidth(BuildContext context, {double maxWidth = 1200}) {
    final cfg = LayoutConfig.instance;
    final w = width(context);
    if (cfg.mode == LayoutMode.centered) {
      return cfg.contentMaxWidth.clamp(360.0, w);
    }
    if (w <= mediumMax) return w;
    return maxWidth;
  }

  /// Wrap scroll content into a centered, width-capped surface when the
  /// layout mode says so.
  static Widget maybeCenter(
    BuildContext context,
    Widget child, {
    double maxWidth = 1100,
  }) {
    final cfg = LayoutConfig.instance;
    if (cfg.mode != LayoutMode.centered) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cfg.contentMaxWidth.clamp(360.0, width(context)),
          maxHeight: height(context) * cfg.contentHeightFraction,
        ),
        child: child,
      ),
    );
  }

  static double adaptiveFontSize(BuildContext context, double base) {
    final w = width(context);
    if (w <= compactMax) return base * 0.85;
    if (w <= mediumMax) return base * 0.92;
    return base;
  }

  static int adaptiveGridColumns(BuildContext context, {int max = 4}) {
    final w = width(context);
    if (w <= compactMax) return 1;
    if (w <= 480) return 2;
    if (w <= mediumMax) return 3;
    return max;
  }

  static double adaptiveItemWidth(
    BuildContext context, {
    int columns = 2,
    double spacing = 8,
  }) {
    final w = width(context);
    return (w - (columns + 1) * spacing) / columns;
  }
}
