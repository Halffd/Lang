/// Bounds and presets for the app-wide text zoom (ctrl+scroll, pinch and
/// the settings presets). Kept in one place so [AppState] clamping, the
/// [FontZoomScope] handler and the settings UI cannot drift apart.
class FontZoom {
  const FontZoom._();

  static const double minMultiplier = 0.8;
  static const double maxMultiplier = 2.5;

  /// Default zoom change per ctrl+scroll notch.
  static const double defaultStep = 0.1;

  static const double minStep = 0.02;
  static const double maxStep = 0.5;

  /// Quick-pick values offered in settings, including 1.75x.
  static const List<double> presets = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
}
