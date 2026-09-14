// Clipboard settings radio group: mode selection updates app
// state through the RadioGroup ancestor (flutter 3.32+ api).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/clipboard_settings.dart';

class _MockStorage extends StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getSavedWords() async => <String>{};

  @override
  Future<Set<String>> getFavoriteWords() async => <String>{};

  @override
  Future<Set<String>> getAnkiWords() async => <String>{};

  @override
  String getStringSync(String key) => '';

  @override
  Future<String?> getString(String key) async => '';

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;

  @override
  Future<bool> setInt(String key, int value) async => true;
}

void main() {
  testWidgets('radio group switches clipboard mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState(_MockStorage());
    await appState.storageService.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: ClipboardSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // default mode: history only radio is selected
    final historyRadio = find
        .byType(RadioListTile<ClipboardAutoSearchMode>)
        .first;
    expect(
      (tester.widget(historyRadio) as RadioListTile).value,
      ClipboardAutoSearchMode.historyOnly,
    );

    // tap the auto search radio
    await tester.tap(find.byType(RadioListTile<ClipboardAutoSearchMode>).at(1));
    await tester.pumpAndSettle();
    expect(
      appState.clipboardAutoSearchMode,
      ClipboardAutoSearchMode.autoSearch,
    );

    // tap off
    await tester.tap(find.byType(RadioListTile<ClipboardAutoSearchMode>).last);
    await tester.pumpAndSettle();
    expect(appState.clipboardAutoSearchMode, ClipboardAutoSearchMode.off);
  });
}
