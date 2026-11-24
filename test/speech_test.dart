import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
    tempDir = await Directory.systemTemp.createTemp('speech_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  SpeechService fakeService({required String stdout}) {
    final service = SpeechService();
    service.modelsDirProvider = () async => tempDir;
    service.runCommand = (executable, arguments) async {
      if (executable == '/usr/bin/whisper-cli' ||
          executable == '/usr/bin/parakeet-cli') {
        return (0, stdout, '');
      }
      if (executable == 'curl') {
        // simulate model download
        final out = arguments[arguments.indexOf('-o') + 1];
        File(out).writeAsBytesSync([1, 2, 3]);
        return (0, '', '');
      }
      return (1, '', 'not found');
    };
    return service;
  }

  group('SpeechService', () {
    test('detectEngine prefers whisper when present', () async {
      final service = fakeService(stdout: '');
      expect(
        await service.detectEngine(SpeechEngine.whisper),
        SpeechEngine.whisper,
      );
    });

    test('detectEngine falls back to parakeet', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
        if (executable == '/usr/bin/parakeet-cli') return (0, 'v1', '');
        return (1, '', '');
      };
      expect(
        await service.detectEngine(SpeechEngine.whisper),
        SpeechEngine.parakeet,
      );
    });

    test('detectEngine null when neither binary exists', () async {
      final service = SpeechService();
      service.runCommand = (_, _) async => (1, '', '');
      expect(await service.detectEngine(SpeechEngine.whisper), isNull);
    });

    test('parses whisper segment output', () async {
      final service = fakeService(
        stdout: '''
whisper_init_from_file_with_state_no_state: loading model from models
main: processing file.wav (16000 Hz, 1 samples) ...
main: detected language: JA
[00:00:00.000 --> 00:00:02.500]  こんにちは
[00:00:02.500 --> 00:00:05.000]  世界
''',
      );
      final modelPath = await service.ensureModel(
        SpeechEngine.whisper,
        modelSize: 'tiny',
      );
      expect(modelPath, isNotNull);
      final (text, lang) = await service.transcribeFile(
        '/dev/null',
        engine: SpeechEngine.whisper,
        modelPath: modelPath!,
      );
      expect(text, 'こんにちは\n世界');
      expect(lang, 'ja');
    });

    test('explicit language is returned when not auto', () async {
      final service = fakeService(
        stdout: '''
[00:00:00.000 --> 00:00:01.000]  hello
''',
      );
      final modelPath = await service.ensureModel(
        SpeechEngine.whisper,
        modelSize: 'tiny',
      );
      final (_, lang) = await service.transcribeFile(
        '/dev/null',
        engine: SpeechEngine.whisper,
        modelPath: modelPath!,
        language: 'ja',
      );
      expect(lang, 'ja');
    });

    test('ensureModel downloads when missing and caches', () async {
      final service = fakeService(stdout: '');
      final p1 = await service.ensureModel(
        SpeechEngine.whisper,
        modelSize: 'tiny',
      );
      expect(p1, isNotNull);
      expect(File(p1!).existsSync(), isTrue);

      // second call: served from disk even if curl now fails
      service.runCommand = (executable, arguments) async {
        if (executable == 'curl') return (1, '', 'network down');
        return (0, '', '');
      };
      final p2 = await service.ensureModel(
        SpeechEngine.whisper,
        modelSize: 'tiny',
      );
      expect(p2, p1);
    });

    test('ensureModel returns null when download fails', () async {
      final service = SpeechService();
      service.modelsDirProvider = () async => tempDir;
      service.runCommand = (executable, arguments) async {
        if (executable == 'curl') return (1, '', 'network down');
        return (1, '', '');
      };
      expect(
        await service.ensureModel(SpeechEngine.whisper, modelSize: 'tiny'),
        isNull,
      );
    });

    test('sensitivity maps to beam size argument', () async {
      final argsSeen = <List<String>>[];
      final service = SpeechService();
      service.modelsDirProvider = () async => tempDir;
      service
        ..runCommand = (executable, arguments) async {
          if (executable == '/usr/bin/whisper-cli') {
            argsSeen.add(arguments);
            return (0, '', '');
          }
          if (executable == 'curl') {
            File(arguments[arguments.indexOf('-o') + 1]).writeAsBytesSync([1]);
            return (0, '', '');
          }
          return (1, '', '');
        }
        ..sensitivity = 5;
      final modelPath = await service.ensureModel(
        SpeechEngine.whisper,
        modelSize: 'tiny',
      );
      await service.transcribeFile(
        '/dev/null',
        engine: SpeechEngine.whisper,
        modelPath: modelPath!,
      );
      expect(argsSeen.first, contains('-bs'));
      final bsIdx = argsSeen.first.indexOf('-bs');
      expect(argsSeen.first[bsIdx + 1], '5');

      // sensitivity 1 -> no -bs flag (greedy)
      argsSeen.clear();
      service.sensitivity = 1;
      await service.transcribeFile(
        '/dev/null',
        engine: SpeechEngine.whisper,
        modelPath: modelPath,
      );
      expect(argsSeen.first, isNot(contains('-bs')));
    });

    test('whisper model list contains expected sizes', () {
      expect(SpeechService.whisperModels['tiny'], 'ggml-tiny.bin');
      expect(SpeechService.whisperModels['base'], 'ggml-base.bin');
      expect(SpeechService.whisperModels['large-v3'], 'ggml-large-v3.bin');
    });

    test('micAvailable reports false when no capture device exists', () async {
      final service = SpeechService();
      service.micProbeOverride = () async => false;
      expect(await service.micAvailable(), isFalse);
    });

    test('micAvailable reports true when a capture device exists', () async {
      final service = SpeechService();
      service.micProbeOverride = () async => true;
      expect(await service.micAvailable(), isTrue);
    });

    test(
      'startLive reports an error when the chunk file was never written',
      () async {
        // No capture device: `record` claims success, but no wav file is
        // ever produced. The chunk transcription must say so instead of
        // silently dropping the segment.
        TestWidgetsFlutterBinding.ensureInitialized();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async {
            switch (call.method) {
              case 'hasPermission':
                return true;
              case 'listInputDevices':
                return <String>[];
              case 'create':
              case 'start':
              case 'stop':
                return null;
              default:
                return null;
            }
          },
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            null,
          ),
        );

        final service = SpeechService();
        service.modelsDirProvider = () async => tempDir;
        final errors = <String>[];
        final started = await service.startLive(
          engine: SpeechEngine.whisper,
          modelPath: 'model.bin',
          language: 'auto',
          onSegment: (_) {},
          onError: errors.add,
        );
        expect(started, isTrue);
        // let the chunk timer fire once
        await Future<void>.delayed(const Duration(seconds: 7));
        await service.stopLive(
          engine: SpeechEngine.whisper,
          modelPath: 'model.bin',
          language: 'auto',
          onSegment: (_) {},
        );
        expect(errors, contains('no audio captured'));
      },
    );
  });

  group('AppState speech settings', () {
    test('defaults and persistence', () async {
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      expect(appState.speechEngine, 'whisper');
      expect(appState.speechModelSize, 'base');
      expect(appState.speechSensitivity, 3);
      expect(appState.speechLanguage, 'auto');
      expect(appState.speechAutoTranslate, isFalse);
      expect(appState.speechSideBySide, isFalse);

      appState.setSpeechEngine('parakeet');
      appState.setSpeechModelSize('small');
      appState.setSpeechSensitivity(5);
      appState.setSpeechLanguage('ja');
      appState.setSpeechAutoTranslate(true);
      appState.setSpeechSideBySide(true);

      final reloaded = AppState(storage);
      expect(reloaded.speechEngine, 'parakeet');
      expect(reloaded.speechModelSize, 'small');
      expect(reloaded.speechSensitivity, 5);
      expect(reloaded.speechLanguage, 'ja');
      expect(reloaded.speechAutoTranslate, isTrue);
      expect(reloaded.speechSideBySide, isTrue);
    });

    test('setters clamp and guard', () async {
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      appState.setSpeechSensitivity(9);
      expect(appState.speechSensitivity, 5);
      appState.setSpeechSensitivity(0);
      expect(appState.speechSensitivity, 1);
      appState.setSpeechEngine('bogus');
      expect(appState.speechEngine, 'whisper');
      appState.setSpeechLanguage('');
      expect(appState.speechLanguage, 'auto');
    });

    test('capture device and debug toggle persist', () async {
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);

      // no device selected means "system default" (the microphone)
      expect(appState.speechCaptureDevice, '');
      expect(appState.speechDebugLogging, isFalse);

      appState.setSpeechCaptureDevice('alsa_output.monitor');
      appState.setSpeechDebugLogging(true);

      final reloaded = AppState(storage);
      expect(reloaded.speechCaptureDevice, 'alsa_output.monitor');
      expect(reloaded.speechDebugLogging, isTrue);
    });
  });

  group('SpeechScreen', () {
    testWidgets('renders the speech-to-text controls', (tester) async {
      // The speech tab is hosted inside the app shell, which supplies
      // the Scaffold and the height. Reproduce that here.
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
            home: const Scaffold(body: SpeechScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The record / pick-file controls and the model selector are the
      // screen's entry points.
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      expect(find.byIcon(Icons.audio_file), findsOneWidget);
      expect(find.text('Test mic'), findsOneWidget);
    });

    testWidgets('record button reports a missing microphone', (tester) async {
      // The regression: on a machine with no capture device the record
      // button used to start a recording that captured nothing, so the
      // screen stayed empty with no explanation.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        (call) async {
          switch (call.method) {
            case 'hasPermission':
              return true;
            case 'listInputDevices':
              return <String>[];
            default:
              return null;
          }
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        ),
      );

      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = StorageService();
      await storage.init();
      final service = SpeechService();
      service.micProbeOverride = () async => false;
      // keep the model lookup off the network and the real filesystem
      service.modelsDirProvider = () async => tempDir;
      service.runCommand = (executable, arguments) async {
        if (executable == 'curl') {
          final out = arguments[arguments.indexOf('-o') + 1];
          File(out).writeAsBytesSync([1, 2, 3]);
          return (0, '', '');
        }
        return (0, '', '');
      };
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
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.mic_off));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('no microphone found'), findsOneWidget);
      // and nothing was recorded
      expect(service.isRecording, isFalse);
    });

    testWidgets('capture source menu lists the enumerated devices', (
      tester,
    ) async {
      // The regression: there was no way to pick a capture source, so
      // the microphone was the only option and recording another
      // application's audio was impossible.
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = StorageService();
      await storage.init();
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
        if (executable == 'pactl') {
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
                '\t\tnode.name = "alsa_output.sink.monitor"\n'
                '\t\tnode.description = "Monitor of Built-in Output"\n'
                '\t\tmedia.class = "Stream/Input/Audio"\n',
            '',
          );
        }
        return (0, '', '');
      };

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
      await tester.pump(const Duration(milliseconds: 300));

      // the device menu is present
      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // the system default entry plus both enumerated sources
      expect(find.text('System default (microphone)'), findsOneWidget);
      expect(find.text('Built-in Microphone'), findsOneWidget);
      // the monitor is marked as app-audio capture
      expect(
        find.text('Monitor of Built-in Output (app audio)'),
        findsOneWidget,
      );

      // picking a device persists it
      await tester.tap(find.text('Monitor of Built-in Output (app audio)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.selectedDeviceId, 'alsa_output.sink.monitor');
      expect(
        storage.getStringSync('speech_capture_device'),
        'alsa_output.sink.monitor',
      );
    });

    testWidgets('capture source menu lists the playing applications', (
      tester,
    ) async {
      // The regression: there was no way to capture one application's
      // audio - only whole output devices.
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = StorageService();
      await storage.init();
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
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
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // the playing application is offered
      expect(find.text('Firefox'), findsOneWidget);
      expect(find.byIcon(Icons.apps), findsOneWidget);
    });
  });
}
