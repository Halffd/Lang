import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_zoom.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> loadWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final storage = StorageService();
    await storage.init();
    // settings are loaded synchronously in the constructor
    return AppState(storage);
  }

  group('layoutMode migration', () {
    test('missing value falls back to auto', () async {
      expect((await loadWith({})).layoutMode, 'auto');
    });

    test('legacy centered value migrates to auto', () async {
      // "centered" was a real persisted option before the width cap was
      // removed; leaving it would break the settings SegmentedButton.
      expect((await loadWith({'layout_mode': 'centered'})).layoutMode, 'auto');
    });

    test('unknown/corrupt value falls back to auto', () async {
      expect((await loadWith({'layout_mode': 'nonsense'})).layoutMode, 'auto');
    });

    test('still-valid modes are preserved', () async {
      for (final mode in ['auto', 'mobile', 'tablet', 'desktop']) {
        expect((await loadWith({'layout_mode': mode})).layoutMode, mode);
      }
    });
  });

  group('font zoom persistence', () {
    test('default step is used when unset', () async {
      final state = await loadWith({});
      expect(state.fontZoomStep, 0.1);
    });

    test('step is clamped to a usable range', () async {
      final state = await loadWith({});
      state.setFontZoomStep(99.0);
      expect(state.fontZoomStep, FontZoom.maxStep);
      state.setFontZoomStep(0.0);
      expect(state.fontZoomStep, FontZoom.minStep);
    });

    test('1.75x preset survives a reload', () async {
      final state = await loadWith({'font_size_multiplier': 1.75});
      expect(state.fontSizeMultiplier, 1.75);
    });
  });
}
