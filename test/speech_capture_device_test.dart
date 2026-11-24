import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/core/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech_device_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// A `pactl list sources` sample with a real microphone and a sink
  /// monitor, which is how a second application's playback is captured.
  const pactlSources = '''
Source #0
	Driver: module-alsa-card.c
	Source #0
		Name: alsa_input.pci-0000_00_1f.3.analog-stereo
		Description: Built-in Audio Analog Stereo
		Sample Specification: 44100Hz, 16-bit, stereo
		Channel Map: front-left,front-right
		Properties:
			alsa.resolution_bits = "16"
			device.api = "alsa"
			device.description = "Built-in Audio Analog Stereo"
			device.product.name = "Built-in Audio Analog Stereo"
			media.class = "Audio/Source"
			media.name = "Built-in Audio Analog Stereo"
			node.description = "Built-in Audio Analog Stereo"
			node.name = "alsa_input.pci-0000_00_1f.3.analog-stereo"
			node.nick = "Built-in Audio Analog Stereo"
Source #1
	Driver: module-alsa-card.c
	Source #1
		Name: alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
		Description: Monitor of Built-in Audio Analog Stereo
		Sample Specification: 44100Hz, 16-bit, stereo
		Channel Map: front-left,front-right
		Properties:
			media.class = "Stream/Input/Audio"
			media.name = "Monitor of Built-in Audio Analog Stereo"
			media.supported_formats = "{ s16le, s32le }"
			node.description = "Monitor of Built-in Audio Analog Stereo"
			node.name = "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"
			node.nick = "Monitor of Built-in Audio Analog Stereo"
''';

  group('capture device enumeration', () {
    test('parses devices and keeps monitor sources', () {
      final devices = SpeechService.parsePactlSources(pactlSources);

      expect(devices, hasLength(2));

      final mic = devices.first;
      // the id is the PulseAudio source name, which is what
      // `parecord --device=` expects
      expect(mic.id, 'alsa_input.pci-0000_00_1f.3.analog-stereo');
      expect(mic.label, 'Built-in Audio Analog Stereo');
      expect(mic.isMonitor, isFalse);

      // the monitor is the loopback source: recording it captures
      // whatever plays on that output device
      final monitor = devices.last;
      expect(monitor.id, 'alsa_output.pci-0000_00_1f.3.analog-stereo.monitor');
      expect(monitor.label, 'Monitor of Built-in Audio Analog Stereo');
      expect(monitor.isMonitor, isTrue);
    });

    test('a monitor id is the source name, not the node name', () {
      // The regression: node.name for the monitor is the *sink* name
      // ("auto_null"), but the source is "auto_null.monitor".
      // `parecord --device=auto_null` records silence.
      const output = '''
Source #51
	Name: auto_null.monitor
	Description: Monitor of Dummy Output
	Properties:
		node.name = "auto_null"
		node.description = "Monitor of Dummy Output"
''';

      final devices = SpeechService.parsePactlSources(output);

      expect(devices, hasLength(1));
      expect(devices.single.id, 'auto_null.monitor');
      expect(devices.single.isMonitor, isTrue);
    });

    test('returns an empty list for empty output', () {
      expect(SpeechService.parsePactlSources(''), isEmpty);
    });

    test('refreshCaptureDevices populates the device list', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
        if (executable == 'pactl') return (0, pactlSources, '');
        return (1, '', 'not found');
      };

      final devices = await service.refreshCaptureDevices();

      expect(devices, hasLength(2));
      expect(service.captureDevices, hasLength(2));
      expect(service.captureDevices.any((d) => d.isMonitor), isTrue);
    });

    test('a failed pactl probe yields no devices', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async =>
          (1, '', 'no server');

      final devices = await service.refreshCaptureDevices();

      expect(devices, isEmpty);
      expect(service.captureDevices, isEmpty);
    });

    test('a vanished selected device is dropped', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
        if (executable == 'pactl') return (0, pactlSources, '');
        return (1, '', 'not found');
      };
      service.selectedDeviceId = 'alsa_input.pci-0000_00_1f.3.analog-stereo';

      // the microphone is unplugged: only the monitor remains
      service.runCommand = (executable, arguments) async {
        if (executable == 'pactl') {
          return (0, pactlSources.split('Source #1').last, '');
        }
        return (1, '', 'not found');
      };
      await service.refreshCaptureDevices();

      expect(service.selectedDeviceId, isNull);
    });
  });

  group('app stream capture', () {
    test('parses the playing applications', () {
      const output = '''
Sink Input #3
	Driver: protocol-native.c
	Owner Module: 12
	Client: 25
	Sink: 0
	Sample Specification: float32le 2ch 48000Hz
	Channel Map: front-left,front-right
	Properties:
		media.name = "Test Tone"
		application.name = "Firefox"
		application.process.binary = "firefox"
		media.class = "Stream/Input/Audio"
Sink Input #4
	Driver: protocol-native.c
	Properties:
		application.name = "code"
		application.process.binary = "code"
''';

      final streams = SpeechService.parsePactlSinkInputs(output);

      expect(streams, hasLength(2));
      expect(streams.first.index, 3);
      expect(streams.first.name, 'Firefox');
      expect(streams.first.binary, 'firefox');
      expect(streams.last.index, 4);
      expect(streams.last.name, 'code');
    });

    test('startAppCapture routes the stream into the capture sink', () async {
      final service = SpeechService();
      final calls = <String>[];
      service.runCommand = (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        if (executable == 'pactl' &&
            arguments.contains('list') &&
            arguments.contains('short')) {
          return (0, '', '');
        }
        return (0, '', '');
      };

      final monitor = await service.startAppCapture(7);

      expect(monitor, SpeechService.captureSinkMonitor);
      expect(
        calls.any(
          (c) =>
              c.startsWith('pactl move-sink-input 7') &&
              c.contains(SpeechService.captureSinkName),
        ),
        isTrue,
      );
      expect(service.capturedAppIndex, 7);
    });

    test('the capture sink remaps the default sink', () async {
      // The regression: a null sink swallows the audio, so the captured
      // application goes silent while it is being recorded.
      final service = SpeechService();
      final calls = <String>[];
      service.runCommand = (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        return (0, '', '');
      };

      await service.startAppCapture(1);

      final load = calls.firstWhere((c) => c.contains('load-module'));
      expect(load, contains('module-remap-sink'));
      expect(load, contains('master=@DEFAULT_SINK@'));
    });

    test('the stream returns to the sink it came from', () async {
      // The regression: an app playing to a headset was moved to the
      // default sink on stop, so it jumped to the speakers.
      final service = SpeechService();
      final calls = <String>[];
      service.runCommand = (executable, arguments) async {
        final call = '$executable ${arguments.join(' ')}';
        calls.add(call);
        if (executable == 'pactl' &&
            arguments.contains('list') &&
            arguments.contains('sink-inputs')) {
          return (
            0,
            'Sink Input #5\n\tSink: 147\n\tProperties:\n'
                '\t\tapplication.name = "Firefox"\n',
            '',
          );
        }
        if (executable == 'pactl' &&
            arguments.contains('list') &&
            arguments.contains('short') &&
            arguments.contains('sinks')) {
          return (0, '147\tauto_null\tPipeWire\tfloat32le 2ch 48000Hz\n', '');
        }
        return (0, '', '');
      };

      await service.startAppCapture(5);
      calls.clear();

      await service.stopAppCapture();

      expect(
        calls.any(
          (c) =>
              c.startsWith('pactl move-sink-input 5') &&
              c.contains('auto_null'),
        ),
        isTrue,
      );
    });

    test('a failed move leaves nothing captured', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async {
        if (executable == 'pactl' && arguments.contains('move-sink-input')) {
          return (1, '', 'no such stream');
        }
        return (0, '', '');
      };

      final monitor = await service.startAppCapture(9);

      expect(monitor, isNull);
      expect(service.capturedAppIndex, isNull);
    });

    test('stopAppCapture moves the stream back', () async {
      final service = SpeechService();
      final calls = <String>[];
      service.runCommand = (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        return (0, '', '');
      };
      await service.startAppCapture(5);

      await service.stopAppCapture();

      expect(
        calls.any(
          (c) =>
              c.startsWith('pactl move-sink-input 5') &&
              c.contains('@DEFAULT_SINK@'),
        ),
        isTrue,
      );
      expect(service.capturedAppIndex, isNull);
    });

    test('a stale capture sink is recovered on startup', () async {
      // The regression: a crashed session left the application's audio
      // stranded in the capture sink, with nothing to move it back.
      final service = SpeechService();
      final calls = <String>[];
      service.runCommand = (executable, arguments) async {
        final call = '$executable ${arguments.join(' ')}';
        calls.add(call);
        if (executable == 'pactl' &&
            arguments.contains('list') &&
            arguments.contains('short') &&
            arguments.contains('sinks')) {
          // <index> <name> <driver> <format>
          return (
            0,
            '147\tauto_null\tPipeWire\tfloat32le 2ch 48000Hz\n'
                '148\t${SpeechService.captureSinkName}\tPipeWire\tfloat32le\n',
            '',
          );
        }
        if (executable == 'pactl' &&
            arguments.contains('list') &&
            arguments.contains('short') &&
            arguments.contains('sink-inputs')) {
          // <index> <sink index> <client> <name> <format>
          // the sink column holds the sink's index
          return (0, '42\t148\t25\tFirefox\n', '');
        }
        if (executable == 'pactl' &&
            arguments.contains('short') &&
            arguments.contains('modules')) {
          return (
            0,
            '9\tmodule-remap-sink\tsink_name=${SpeechService.captureSinkName}\n',
            '',
          );
        }
        return (0, '', '');
      };

      await service.recoverStaleCapture();

      // the stranded stream is moved back out
      expect(
        calls.any(
          (c) =>
              c.startsWith('pactl move-sink-input 42') &&
              c.contains('@DEFAULT_SINK@'),
        ),
        isTrue,
      );
      // and the capture sink is removed
      expect(calls.any((c) => c.contains('unload-module')), isTrue);
    });
  });

  group('debug log', () {
    test('records nothing while disabled', () async {
      final service = SpeechService();
      service.runCommand = (executable, arguments) async => (0, '', '');

      await service.detectEngine(SpeechEngine.whisper);

      expect(service.logEntries, isEmpty);
    });

    test('records the probed command when enabled', () async {
      final service = SpeechService();
      service.debugLogging = true;
      service.runCommand = (executable, arguments) async {
        if (executable == '/usr/bin/whisper-cli') {
          return (0, 'whisper-cli version 1.7', '');
        }
        return (1, '', 'not found');
      };

      await service.detectEngine(SpeechEngine.whisper);

      expect(service.logEntries, isNotEmpty);
      expect(
        service.logEntries.map((e) => e.message).join('\n'),
        contains('whisper-cli'),
      );
    });

    test('clearLog empties the buffer', () {
      final service = SpeechService();
      service.debugLogging = true;
      service.log('info', 'hello');
      expect(service.logEntries, hasLength(1));

      service.clearLog();

      expect(service.logEntries, isEmpty);
    });

    test('the buffer is bounded', () {
      final service = SpeechService();
      service.debugLogging = true;
      for (var i = 0; i < SpeechService.maxLogEntries + 50; i++) {
        service.log('info', 'entry $i');
      }

      expect(service.logEntries, hasLength(SpeechService.maxLogEntries));
      // the newest entries are the ones kept
      expect(
        service.logEntries.last.message,
        contains('entry ${SpeechService.maxLogEntries + 49}'),
      );
    });
  });

  group('record configuration', () {
    test('the selected device reaches the recorder config', () async {
      final service = SpeechService();
      service.selectedDeviceId = 'some.monitor';

      final config = service.recordConfigForTest();

      expect(config.device?.id, 'some.monitor');
    });

    test('no device means the system default', () async {
      final service = SpeechService();

      final config = service.recordConfigForTest();

      expect(config.device, isNull);
    });
  });
}
