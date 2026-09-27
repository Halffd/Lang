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
        LayoutMode.desktop => ScreenType.expanded,
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

  /// Screen padding: a flat 1px so content spans the full window width.
  /// Raise [LayoutConfig.paddingScale] in settings to add breathing room.
  static EdgeInsets adaptivePadding(BuildContext context) =>
      EdgeInsets.all(LayoutConfig.instance.paddingScale);

  /// Card margin: a flat 1px, matching [adaptivePadding].
  static EdgeInsets adaptiveMargin(BuildContext context) =>
      EdgeInsets.all(LayoutConfig.instance.marginScale);

  /// Standard border radius (scaled). Multiplied onto a base radius.
  static double adaptiveRadius(double base) =>
      base * LayoutConfig.instance.borderRadiusScale;

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
