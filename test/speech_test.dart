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
import 'package:lang/presentation/screens/reader_screen.dart';

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
  });

  group('ReaderScreen speech tab', () {
    testWidgets('shows four tabs including speech', (tester) async {
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
            home: const ReaderScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Screenshots'), findsOneWidget);
      expect(find.text('Clipboard'), findsOneWidget);
      expect(find.text('Speech'), findsOneWidget);
    });
  });
}
