// Tests for the settings screen.
//
// The screen used to render as a blank window: its cloud-sync section
// probed the Supabase client, which only exists when the app was built
// with Supabase credentials. Without them the probe threw a
// LateInitializationError and took the whole screen down.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/core/services/supabase_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/user_profile_provider.dart';
import 'package:lang/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> pumpSettings(WidgetTester tester) async {
    final state = AppState(StorageService());
    await state.storageService.init();
    final profile = UserProfileProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<UserProfileProvider>.value(value: profile),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  test('the supabase service reports unconfigured instead of throwing', () {
    // the app ships without Supabase credentials: asking whether it is
    // configured must not throw
    final service = SupabaseService();
    expect(service.isConfigured, isFalse);
    expect(service.isInitialized, isFalse);
    expect(service.currentUserId, isNull);
  });

  testWidgets('the settings screen renders without Supabase configured', (
    tester,
  ) async {
    await pumpSettings(tester);

    // the app bar and the first section must be there: a blank window
    // means the build threw
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Backup & Sync'), findsOneWidget);
  });

  testWidgets('the settings screen lists its sections', (tester) async {
    await pumpSettings(tester);

    // the sections live further down the list: scroll each one into
    // view instead of guessing how far a drag goes
    await tester.scrollUntilVisible(
      find.text('Live OCR'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Live OCR'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Global hotkeys'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Global hotkeys'), findsOneWidget);
  });
}
