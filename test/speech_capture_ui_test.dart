import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/speech_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/capture_screens.dart';

/// UI-level verification of the speech capture controls.
///
/// These drive the real widget surface: the capture-source menu, the
/// application picker and the debug log viewer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
    tempDir = await Directory.systemTemp.createTemp('speech_ui_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// A service whose pactl output lists a microphone, an output-device
  /// monitor, and one playing application.
  SpeechService serviceWithDevices() {
    final service = SpeechService();
    service.modelsDirProvider = () async => tempDir;
    service.runCommand = (executable, arguments) async {
      if (executable == 'pactl' && arguments.contains('sources')) {
        return (
          0,
          'Source #0\n'
              '\tName: alsa_input.mic\n'
              '\tDescription: Built-in Microphone\n'
              '\tProperties:\n'
              '\t\tnode.name = "alsa_input.mic"\n'
              '\t\tnode.description = "Built-in Microphone"\n'
              '\t\tmedia.class = "Audio/Source"\n'
              'Source #1\n'
              '\tName: alsa_output.sink.monitor\n'
              '\tDescription: Monitor of Built-in Output\n'
              '\tProperties:\n'
              '\t\tnode.name = "alsa_output.sink"\n'
              '\t\tnode.description = "Monitor of Built-in Output"\n'
              '\t\tmedia.class = "Stream/Input/Audio"\n',
          '',
        );
      }
      if (executable == 'pactl' && arguments.contains('sink-inputs')) {
        return (
          0,
          'Sink Input #3\n'
              '\tProperties:\n'
              '\t\tapplication.name = "Firefox"\n'
              '\t\tapplication.process.binary = "firefox"\n',
          '',
        );
      }
      return (0, '', '');
    };
    return service;
  }

  Future<void> pumpSpeechScreen(
    WidgetTester tester,
    SpeechService service,
  ) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = StorageService();
    await storage.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(storage),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SpeechScreen(service: service)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the capture source menu shows devices and applications', (
    tester,
  ) async {
    final service = serviceWithDevices();
    await pumpSpeechScreen(tester, service);

    // the capture-source button is on the toolbar
    expect(find.byIcon(Icons.mic_none), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // the default entry
    expect(find.text('System default (microphone)'), findsOneWidget);
    // a real capture device
    expect(find.text('Built-in Microphone'), findsOneWidget);
    // an output device, marked as app-audio capture
    expect(find.text('Monitor of Built-in Output (app audio)'), findsOneWidget);
    // a playing application
    expect(find.text('Firefox'), findsOneWidget);
    expect(find.byIcon(Icons.apps), findsOneWidget);
  });

  testWidgets('choosing an output device records it and persists it', (
    tester,
  ) async {
    final service = serviceWithDevices();
    await pumpSpeechScreen(tester, service);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Monitor of Built-in Output (app audio)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.selectedDeviceId, 'alsa_output.sink.monitor');

    final storage = StorageService();
    await storage.init();
    expect(
      storage.getStringSync('speech_capture_device'),
      'alsa_output.sink.monitor',
    );
  });

  testWidgets('the debug log button opens the log viewer', (tester) async {
    final service = serviceWithDevices();
    await pumpSpeechScreen(tester, service);

    // the bug-report toggle is on the toolbar
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // the viewer opened
    expect(find.text('Speech debug log'), findsOneWidget);
    // and the toggle is now on
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
  });

  testWidgets('the debug log viewer shows recorded entries', (tester) async {
    final service = serviceWithDevices();
    await pumpSpeechScreen(tester, service);

    // turn debugging on and produce an entry
    service.debugLogging = true;
    service.log('info', 'a distinctive log line');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('a distinctive log line'), findsOneWidget);
  });

  testWidgets('the capture source menu does not overflow', (tester) async {
    final service = serviceWithDevices();
    await pumpSpeechScreen(tester, service);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The regression: the 256px default menu width clipped the labels
    // and threw a RenderFlex overflow.
    expect(tester.takeException(), isNull);
  });
}
