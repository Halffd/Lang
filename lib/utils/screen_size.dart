import 'package:flutter/material.dart';

enum ScreenType { compact, medium, expanded }

class ScreenSize {
  static const double compactMax = 360;
  static const double mediumMax = 600;

  static ScreenType type(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= compactMax) return ScreenType.compact;
    if (width <= mediumMax) return ScreenType.medium;
    return ScreenType.expanded;
  }

  static bool isCompact(BuildContext context) =>
      type(context) == ScreenType.compact;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width <= mediumMax;

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
    final w = width(context);
    if (w <= compactMax) return const EdgeInsets.all(8);
    if (w <= mediumMax) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
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

  static double adaptiveItemWidth(BuildContext context, {int columns = 2, double spacing = 8}) {
    final w = width(context);
    return (w - (columns + 1) * spacing) / columns;
  }
}
