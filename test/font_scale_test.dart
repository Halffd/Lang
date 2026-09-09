import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_settings.dart';
import 'package:lang/utils/font_scale.dart';

void main() {
  testWidgets('fs applies global * group multiplier', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    appState.setFontSizeMultiplier(1.5);
    appState.setFontSettings(
      const FontSettings(kanji: 2.0, sentences: 1.0, ui: 0.5),
    );

    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    // kanji: 16 * 1.5 * 2.0 = 48
    expect(fs(captured, 16, 'kanji'), 48.0);
    // sentences: 14 * 1.5 * 1.0 = 21
    expect(fs(captured, 14, 'sentences'), 21.0);
    // ui default group: 12 * 1.5 * 0.5 = 9
    expect(fs(captured, 12), 9.0);
    expect(fs(captured, 12, 'ui'), 9.0);
    // headers default 1.0: 16 * 1.5 * 1.0 = 24
    expect(fs(captured, 16, 'headers'), 24.0);
  });
}
