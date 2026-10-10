import 'dart:convert';

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

  Future<void> pumpTabWithPrefs(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    // init before AppState: the constructor loads settings synchronously,
    // so a storage that initializes afterwards reads nothing
    final storage = StorageService();
    await storage.init();
    final state = AppState(storage);
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
    await pumpTabWithPrefs(tester, {});

    expect(
      find.text('Pick a video to play with a subtitle track.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Pick video'), findsOneWidget);
  });

  testWidgets('offers no player controls before a video is picked', (
    tester,
  ) async {
    await pumpTabWithPrefs(tester, {});

    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.text('Transcript'), findsNothing);
    expect(find.text('Load subs'), findsNothing);
  });

  testWidgets('offers local and YouTube sources', (tester) async {
    await pumpTabWithPrefs(tester, {});

    expect(find.widgetWithText(FilledButton, 'Pick video'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'YouTube'), findsOneWidget);
  });

  testWidgets('offers no customization controls before a video is picked', (
    tester,
  ) async {
    await pumpTabWithPrefs(tester, {});

    // speed, subtitle size and delay menus belong to the player controls
    expect(find.byIcon(Icons.speed), findsNothing);
    expect(find.byIcon(Icons.format_size), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('offers a recents entry point only when recents exist', (
    tester,
  ) async {
    await pumpTabWithPrefs(tester, {});
    expect(find.text('Recent'), findsNothing);

    await pumpTabWithPrefs(tester, {
      'recent_videos': jsonEncode([
        {
          'kind': 'youtube',
          'source': 'https://www.youtube.com/watch?v=abc',
          'label': 'Some lesson',
          'videoId': 'abc',
          'lastPositionMs': 1000,
          'watchedMs': 60_000,
          'lastWatchedAt': 1,
        },
      ]),
    });
    expect(find.text('Recent'), findsOneWidget);
  });
}
