import 'package:flutter/material.dart';

/// How the app decides its responsive tier.
enum LayoutMode {
  /// Automatic from physical width.
  auto,

  /// Force compact layout ("mobile").
  mobile,

  /// Force medium layout ("tablet").
  tablet,

  /// Force expanded layout ("desktop").
  desktop,
}

/// Global layout tuning settings consumed by [ScreenSize]. Populated from
/// `AppState` at startup and on every settings change.
///
/// Singleton on purpose: widgets deep in the tree without Provider access
/// (pure helpers) also read from here.
class LayoutConfig extends ChangeNotifier {
  static final LayoutConfig instance = LayoutConfig._();
  LayoutConfig._();

  LayoutMode _mode = LayoutMode.auto;
  LayoutMode get mode => _mode;

  /// Scale for outer screen padding. 1.0 = the [ScreenSize.adaptivePadding]
  /// base.
  double _paddingScale = 1.0;
  double get paddingScale => _paddingScale;

  /// Scale for card/list margins.
  double _marginScale = 1.0;
  double get marginScale => _marginScale;

  /// Scale for border radii on cards/dialogs.
  double _borderRadiusScale = 1.0;
  double get borderRadiusScale => _borderRadiusScale;

  /// Scale for border stroke widths.
  double _borderWidthScale = 1.0;
  double get borderWidthScale => _borderWidthScale;

  void update({
    LayoutMode? mode,
    double? paddingScale,
    double? marginScale,
    double? borderRadiusScale,
    double? borderWidthScale,
  }) {
    if (mode != null) _mode = mode;
    if (paddingScale != null) _paddingScale = paddingScale;
    if (marginScale != null) _marginScale = marginScale;
    if (borderRadiusScale != null) _borderRadiusScale = borderRadiusScale;
    if (borderWidthScale != null) _borderWidthScale = borderWidthScale;
    notifyListeners();
  }
}
