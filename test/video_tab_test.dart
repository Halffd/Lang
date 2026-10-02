import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/reader/video_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTab(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(StorageService());
    await state.storageService.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoTab()),
        ),
      ),
    );
    await tester.pump();
  }

  // The player needs a real decodable media file, which a unit test cannot
  // supply, so these cover the no-media state. Playback, cue-following and
  // transcript interaction are covered by the SubtitleParser tests.
  testWidgets('shows a prompt and a pick button with no media', (tester) async {
    await pumpTab(tester);

    expect(
      find.text('Pick a video to play with a subtitle track.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Pick video'), findsOneWidget);
  });

  testWidgets('offers no player controls before a video is picked', (
    tester,
  ) async {
    await pumpTab(tester);

    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.text('Transcript'), findsNothing);
    expect(find.text('Load subs'), findsNothing);
  });
}
