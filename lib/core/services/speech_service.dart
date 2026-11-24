import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// STT engine preference.
enum SpeechEngine { whisper, parakeet, api }

/// OpenAI-compatible STT API engine: multipart audio POST to
/// /audio/transcriptions, Bearer key, JSON {text} response.
class ApiSttConfig {
  final String url;
  final String apiKey;
  final String model;

  const ApiSttConfig({
    required this.url,
    required this.apiKey,
    this.model = 'whisper-1',
  });
}

/// Result of one transcription segment.
class SpeechSegment {
  final String text;
  final String? language;
  final int startMs;
  final int endMs;
  final String? translation;

  const SpeechSegment({
    required this.text,
    this.language,
    required this.startMs,
    required this.endMs,
    this.translation,
  });

  SpeechSegment copyWith({String? translation}) => SpeechSegment(
    text: text,
    language: language,
    startMs: startMs,
    endMs: endMs,
    translation: translation ?? this.translation,
  );
}

/// One capture source the user can record from.
///
/// [id] is what `parecord --device=` expects. [isMonitor] marks the
/// loopback sources (a sink's monitor) — recording those captures what
/// another app is playing, which is the "capture app audio" case.
/// [appName] is the application a monitor belongs to, when the source
/// exposes one.
class SpeechCaptureDevice {
  final String id;
  final String label;
  final bool isMonitor;
  final String? appName;

  const SpeechCaptureDevice({
    required this.id,
    required this.label,
    this.isMonitor = false,
    this.appName,
  });

  @override
  bool operator ==(Object other) =>
      other is SpeechCaptureDevice &&
      other.id == id &&
      other.label == label &&
      other.isMonitor == isMonitor &&
      other.appName == appName;

  @override
  int get hashCode => Object.hash(id, label, isMonitor, appName);

  @override
  String toString() => 'SpeechCaptureDevice($id, $label)';
}

/// One entry in the speech debug log.
class SpeechLogEntry {
  final DateTime time;
  final String level;
  final String message;

  const SpeechLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });
}

/// An application that is currently playing audio.
///
/// Capturing one means routing its stream into a dedicated sink and
/// recording that sink's monitor: PulseAudio has no per-application
/// source, so the stream has to be moved.
class SpeechAppStream {
  /// PulseAudio sink-input index.
  final int index;

  /// The application's display name (e.g. "Firefox").
  final String name;

  /// The executable name, when the server reports one.
  final String? binary;

  const SpeechAppStream({required this.index, required this.name, this.binary});

  @override
  bool operator ==(Object other) =>
      other is SpeechAppStream &&
      other.index == index &&
      other.name == name &&
      other.binary == binary;

  @override
  int get hashCode => Object.hash(index, name, binary);

  @override
  String toString() => 'SpeechAppStream($index, $name)';
}

/// Injectable command execution for tests.
typedef SpeechCommandRunner =
    Future<(int, String, String)> Function(
      String executable,
      List<String> arguments,
    );

/// Live + file speech-to-text through local whisper.cpp /
/// parakeet-cli binaries.
///
/// Engines:
/// - /usr/bin/whisper-cli (whisper.cpp): ggml models, language
///   auto-detect, --translate flag
/// - /usr/bin/parakeet-cli (NVIDIA Parakeet TDT): fast english
///   ggml model, no language option
///
/// Live recording captures microphone chunks with the `record`
/// package (wav 16k mono) and transcribes each chunk after it
/// closes, giving near-live segments.
class SpeechService extends ChangeNotifier {
  /// Shared instance for the UI; tests construct their own.
  static final SpeechService instance = SpeechService();

  SpeechService();

  /// Injectable for tests.
  SpeechCommandRunner runCommand = _realRunner;

  static Future<(int, String, String)> _realRunner(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return (
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  /// Whether a capture device exists.
  ///
  /// `record`'s Linux implementation reports hasPermission() == true
  /// unconditionally, so a machine with no microphone (a VM, a CI
  /// runner, a container with only a null sink) looks perfectly
  /// healthy until the recorder silently produces no audio. Probing
  /// the actual source list lets the UI say "no microphone" instead
  /// of doing nothing at all.
  ///
  /// Returns null when the probe cannot run (unknown), true/false when
  /// the answer is known.
  Future<bool?> micAvailable() async {
    if (_isMobile) return null;
    if (micProbeOverride != null) return micProbeOverride!();
    try {
      final devices = await _recorder.listInputDevices();
      return devices.isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  /// Test hook for [micAvailable].
  Future<bool?> Function()? micProbeOverride;

  /// Enumerate the capture sources available to the recorder.
  ///
  /// `record`'s own listInputDevices() deliberately drops monitor
  /// sources, but a monitor is exactly what "record another app"
  /// needs: a sink's monitor carries that application's playback. So
  /// this parses `pactl list sources` directly and keeps both kinds.
  ///
  /// Returns the list, or an empty list when the probe cannot run.
  Future<List<SpeechCaptureDevice>> refreshCaptureDevices() async {
    if (_isMobile) {
      _captureDevices.clear();
      notifyListeners();
      return const [];
    }
    try {
      final (code, stdout, stderr) = await runCommand('pactl', [
        'list',
        'sources',
      ]);
      if (code != 0) {
        log('error', 'pactl list sources failed ($code): $stderr');
        _captureDevices.clear();
        notifyListeners();
        return const [];
      }
      final devices = parsePactlSources(stdout);
      _captureDevices
        ..clear()
        ..addAll(devices);
      log(
        'info',
        'found ${devices.length} capture source(s): '
            '${devices.map((d) => d.id).join(', ')}',
      );
      // the selected device may have disappeared (unplugged mic)
      if (_selectedDeviceId != null &&
          !devices.any((d) => d.id == _selectedDeviceId)) {
        log('warn', 'selected device $_selectedDeviceId vanished');
        _selectedDeviceId = null;
      }
      notifyListeners();
      return List.unmodifiable(_captureDevices);
    } catch (e) {
      log('error', 'capture device enumeration failed: $e');
      _captureDevices.clear();
      notifyListeners();
      return const [];
    }
  }

  /// Parse `pactl list sources` output into capture devices.
  ///
  /// Exposed for tests: the format is stable PulseAudio/PipeWire
  /// output, and the monitor-vs-device distinction matters.
  ///
  /// The id is the PulseAudio **source name** (`Name:`), not
  /// `node.name`: `parecord --device=` wants the source name. For a
  /// monitor they differ — a sink `auto_null` has `node.name =
  /// auto_null` but the monitor source is `auto_null.monitor`, and
  /// passing the node name captures silence.
  @visibleForTesting
  static List<SpeechCaptureDevice> parsePactlSources(String output) {
    final devices = <SpeechCaptureDevice>[];
    String? nodeName;
    String? name;
    String? description;
    String? appName;
    var isMonitor = false;

    void flush() {
      // Prefer the source name; fall back to node.name when the
      // source has no Name: field.
      final id = (name != null && name.isNotEmpty) ? name : nodeName;
      if (id == null) return;
      final label = description ?? name ?? id;
      // A monitor is the loopback of a sink: recording it captures
      // whatever plays on that sink, i.e. another application's audio.
      final monitor =
          isMonitor ||
          (description?.startsWith('Monitor of') ?? false) ||
          (name?.startsWith('Monitor of') ?? false);
      devices.add(
        SpeechCaptureDevice(
          id: id,
          label: label,
          isMonitor: monitor,
          appName: appName,
        ),
      );
    }

    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('Source #')) {
        flush();
        nodeName = null;
        name = null;
        description = null;
        appName = null;
        isMonitor = false;
        continue;
      }
      if (line.startsWith('Name:')) {
        name = _afterColon(line);
      } else if (line.startsWith('Description:')) {
        description = _afterColon(line);
      } else if (line.startsWith('node.name')) {
        nodeName = _afterEquals(line);
      } else if (line.startsWith('node.description')) {
        // node.description is often better than Description:
        final v = _afterEquals(line);
        if (v.isNotEmpty) description = v;
      } else if (line.startsWith('application.name')) {
        appName = _afterEquals(line);
      } else if (line.startsWith('application.process.binary')) {
        // keep the app name but remember the binary for the UI
        appName ??= _afterEquals(line);
      } else if (line.startsWith('media.class')) {
        final v = _afterEquals(line);
        if (v == 'Audio/Source') {
          isMonitor = false;
        }
      }
    }
    flush();
    return devices;
  }

  static String _afterColon(String line) {
    final i = line.indexOf(':');
    if (i < 0) return '';
    return line.substring(i + 1).trim();
  }

  static String _afterEquals(String line) {
    final i = line.indexOf('=');
    if (i < 0) return '';
    return line.substring(i + 1).trim().replaceAll('"', '').replaceAll("'", '');
  }

  // ----------------------------------------------------------
  // debug log
  // ----------------------------------------------------------

  /// When true, every step of the capture + transcription pipeline is
  /// recorded in [logEntries] and echoed to the console. Off by
  /// default: the log is verbose and the UI has a dedicated viewer.
  bool debugLogging = false;

  final List<SpeechLogEntry> _logEntries = [];

  /// Ring buffer of debug entries, newest last.
  List<SpeechLogEntry> get logEntries => List.unmodifiable(_logEntries);

  /// Maximum number of retained log entries.
  static const int maxLogEntries = 500;

  /// Record a debug entry. No-op unless [debugLogging] is on.
  void log(String level, String message) {
    if (!debugLogging) return;
    final entry = SpeechLogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
    );
    _logEntries.add(entry);
    if (_logEntries.length > maxLogEntries) {
      _logEntries.removeRange(0, _logEntries.length - maxLogEntries);
    }
    debugPrint('[speech:$level] $message');
    notifyListeners();
  }

  /// Clear the debug log.
  void clearLog() {
    if (_logEntries.isEmpty) return;
    _logEntries.clear();
    notifyListeners();
  }

  /// Capture sources the user can record from.
  final List<SpeechCaptureDevice> _captureDevices = [];

  /// Enumerated capture sources, refreshed by [refreshCaptureDevices].
  List<SpeechCaptureDevice> get captureDevices =>
      List.unmodifiable(_captureDevices);

  /// The capture source currently selected for recording.
  String? _selectedDeviceId;

  // ----------------------------------------------------------
  // application capture
  // ----------------------------------------------------------

  /// The sink the captured application's audio is routed through.
  static const String captureSinkName = 'lang_capture';

  /// The monitor source of [captureSinkName].
  static const String captureSinkMonitor = '$captureSinkName.monitor';

  /// Applications currently playing audio.
  final List<SpeechAppStream> _appStreams = [];

  /// Applications currently playing audio, refreshed by
  /// [refreshAppStreams].
  List<SpeechAppStream> get appStreams => List.unmodifiable(_appStreams);

  /// The application whose audio is being captured, if any.
  int? _capturedAppIndex;

  /// The sink the captured application's stream came from.
  ///
  /// The stream goes back to exactly this sink when capture stops,
  /// rather than to a generic default: an app playing to a headset
  /// must return to the headset.
  String? _capturedAppOriginalSink;

  /// The sink-input index routed into the capture sink, if any.
  int? get capturedAppIndex => _capturedAppIndex;

  /// Enumerate the applications that are currently playing audio.
  Future<List<SpeechAppStream>> refreshAppStreams() async {
    if (_isMobile) {
      _appStreams.clear();
      notifyListeners();
      return const [];
    }
    try {
      final (code, stdout, stderr) = await runCommand('pactl', [
        'list',
        'sink-inputs',
      ]);
      if (code != 0) {
        log('error', 'pactl list sink-inputs failed ($code): $stderr');
        _appStreams.clear();
        notifyListeners();
        return const [];
      }
      final streams = parsePactlSinkInputs(stdout);
      _appStreams
        ..clear()
        ..addAll(streams);
      log(
        'info',
        '${streams.length} app stream(s) playing: '
            '${streams.map((s) => s.name).join(', ')}',
      );
      notifyListeners();
      return List.unmodifiable(_appStreams);
    } catch (e) {
      log('error', 'app stream enumeration failed: $e');
      _appStreams.clear();
      notifyListeners();
      return const [];
    }
  }

  /// Parse `pactl list sink-inputs` output into playing applications.
  @visibleForTesting
  static List<SpeechAppStream> parsePactlSinkInputs(String output) {
    final streams = <SpeechAppStream>[];
    int? index;
    String? name;
    String? binary;

    void flush() {
      if (index == null) return;
      // a stream without an application name is a system sound
      // (module-stream-restore) rather than an app the user picked
      streams.add(
        SpeechAppStream(
          index: index,
          name: name ?? 'App $index',
          binary: binary,
        ),
      );
    }

    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('Sink Input #')) {
        flush();
        index = int.tryParse(line.substring('Sink Input #'.length).trim());
        name = null;
        binary = null;
        continue;
      }
      if (line.startsWith('application.name')) {
        name = _afterEquals(line);
      } else if (line.startsWith('application.process.binary')) {
        binary = _afterEquals(line);
      } else if (line.startsWith('media.name')) {
        // the stream's title: a better label than the app name when
        // the app reports one
        final v = _afterEquals(line);
        if (v.isNotEmpty && name == null) name = v;
      }
    }
    flush();
    return streams;
  }

  /// Route the application at [sinkInputIndex] into the capture sink so
  /// its audio can be recorded, and return the monitor source to record.
  ///
  /// PulseAudio offers no per-application source: the only way to
  /// capture one app is to move its stream into a dedicated sink and
  /// record that sink's monitor. The capture sink remaps the default
  /// sink, so the application keeps playing normally. Returns null on
  /// failure.
  Future<String?> startAppCapture(int sinkInputIndex) async {
    if (_isMobile) return null;
    try {
      // remember where the stream came from before moving it
      final originalSink = await _sinkInputSink(sinkInputIndex);
      // the sink may already exist from a previous session
      await _ensureCaptureSink();
      final (moveCode, _, moveErr) = await runCommand('pactl', [
        'move-sink-input',
        '$sinkInputIndex',
        captureSinkName,
      ]);
      if (moveCode != 0) {
        log('error', 'move-sink-input $sinkInputIndex failed: $moveErr');
        return null;
      }
      _capturedAppIndex = sinkInputIndex;
      _capturedAppOriginalSink = originalSink;
      log(
        'info',
        'capturing app stream $sinkInputIndex via $captureSinkMonitor '
            '(was on ${originalSink ?? 'an unknown sink'})',
      );
      notifyListeners();
      return captureSinkMonitor;
    } catch (e) {
      log('error', 'startAppCapture failed: $e');
      return null;
    }
  }

  /// The sink the stream at [sinkInputIndex] is currently playing to.
  ///
  /// Returns null when it cannot be determined.
  Future<String?> _sinkInputSink(int sinkInputIndex) async {
    try {
      final (code, stdout, _) = await runCommand('pactl', [
        'list',
        'sink-inputs',
      ]);
      if (code != 0) return null;
      var inBlock = false;
      for (final raw in stdout.split('\n')) {
        final line = raw.trim();
        if (line.startsWith('Sink Input #')) {
          inBlock = line == 'Sink Input #$sinkInputIndex';
          continue;
        }
        if (!inBlock) continue;
        if (line.startsWith('Sink:')) {
          final sink = _afterColon(line);
          if (sink.isEmpty || sink == '4294967295') return null;
          // the block reports the sink index; map it to its name
          return await _sinkNameByIndex(sink);
        }
      }
    } catch (e) {
      log('warn', 'could not determine the sink of stream $sinkInputIndex: $e');
    }
    return null;
  }

  /// The name of the sink with the given index, e.g. "auto_null".
  Future<String?> _sinkNameByIndex(String index) async {
    try {
      final (code, stdout, _) = await runCommand('pactl', [
        'list',
        'short',
        'sinks',
      ]);
      if (code != 0) return null;
      for (final line in stdout.split('\n')) {
        final parts = line.trim().split('\t');
        if (parts.length >= 2 && parts[0] == index) return parts[1];
      }
    } catch (_) {}
    return null;
  }

  /// Stop capturing the routed application and move its stream back.
  Future<void> stopAppCapture() async {
    final index = _capturedAppIndex;
    final originalSink = _capturedAppOriginalSink;
    _capturedAppIndex = null;
    _capturedAppOriginalSink = null;
    if (index == null) return;
    try {
      // move it back to where it came from, then drop the capture sink
      final (code, _, stderr) = await runCommand('pactl', [
        'move-sink-input',
        '$index',
        originalSink ?? '@DEFAULT_SINK@',
      ]);
      if (code != 0) {
        log('warn', 'could not move app stream $index back: $stderr');
      } else {
        log(
          'info',
          'app stream $index moved back to '
              '${originalSink ?? 'the default sink'}',
        );
      }
    } catch (e) {
      log('warn', 'stopAppCapture failed: $e');
    }
    await _unloadCaptureSink();
    notifyListeners();
  }

  /// Move any stream still routed into the capture sink back out, and
  /// remove the sink.
  ///
  /// A crash or a force-killed app leaves its stream in the capture
  /// sink; this puts it back so the application is audible again.
  Future<void> recoverStaleCapture() async {
    try {
      final (code, stdout, _) = await runCommand('pactl', [
        'list',
        'short',
        'sinks',
      ]);
      if (code != 0) return;
      // <index> <name> <driver> <format>
      String? captureSinkIndex;
      for (final line in stdout.split('\n')) {
        final parts = line.trim().split('\t');
        if (parts.length >= 2 && parts[1] == captureSinkName) {
          captureSinkIndex = parts[0];
          break;
        }
      }
      if (captureSinkIndex == null) return;

      log('warn', 'a stale capture sink was found; restoring its streams');
      final (inputCode, inputs, _) = await runCommand('pactl', [
        'list',
        'short',
        'sink-inputs',
      ]);
      if (inputCode == 0) {
        for (final line in inputs.split('\n')) {
          // `pactl list short sink-inputs` columns:
          //   <index> <sink index> <client> <name> <format>
          // The sink column holds the sink's *index*, which is what
          // the capture sink was matched by.
          final parts = line.trim().split('\t');
          if (parts.length >= 2 && parts[1] == captureSinkIndex) {
            await runCommand('pactl', [
              'move-sink-input',
              parts[0],
              '@DEFAULT_SINK@',
            ]);
            log('info', 'restored stale stream ${parts[0]}');
          }
        }
      }
      await _unloadCaptureSink();
    } catch (e) {
      log('warn', 'could not recover the stale capture: $e');
    }
  }

  /// Make sure the capture sink exists, loading it when needed.
  ///
  /// The sink is a **remap** sink whose master is the default sink, not
  /// a null sink: the captured application's audio keeps playing through
  /// the normal output while its monitor carries a copy for capture.
  /// A null sink would swallow the audio, leaving the application mute.
  Future<void> _ensureCaptureSink() async {
    final (code, stdout, _) = await runCommand('pactl', [
      'list',
      'short',
      'sinks',
    ]);
    if (code == 0 &&
        stdout.split('\n').any((l) => l.contains(captureSinkName))) {
      log('info', 'capture sink $captureSinkName already exists');
      return;
    }
    final (loadCode, _, loadErr) = await runCommand('pactl', [
      'load-module',
      'module-remap-sink',
      'sink_name=$captureSinkName',
      'master=@DEFAULT_SINK@',
      'sink_properties=device.description=LangCapture',
    ]);
    if (loadCode != 0) {
      log('error', 'could not load the capture sink: $loadErr');
      return;
    }
    log(
      'info',
      'capture sink $captureSinkName loaded (remap of the default sink)',
    );
  }

  /// Unload the capture sink, if it is loaded.
  Future<void> _unloadCaptureSink() async {
    try {
      final (code, stdout, _) = await runCommand('pactl', [
        'list',
        'short',
        'modules',
      ]);
      if (code != 0) return;
      for (final line in stdout.split('\n')) {
        if (!line.contains(captureSinkName)) continue;
        if (!line.contains('module-null-sink') &&
            !line.contains('module-remap-sink')) {
          continue;
        }
        final id = line.trim().split(' ').first;
        await runCommand('pactl', ['unload-module', id]);
        log('info', 'capture sink $captureSinkName unloaded');
      }
    } catch (e) {
      log('warn', 'could not unload the capture sink: $e');
    }
  }

  /// Selected capture source id, or null for the system default.
  String? get selectedDeviceId => _selectedDeviceId;

  set selectedDeviceId(String? value) {
    if (_selectedDeviceId == value) return;
    _selectedDeviceId = value;
    log('info', 'capture device set to ${value ?? '<default>'}');
    notifyListeners();
  }

  /// Override for tests (models dir without network).
  Future<Directory> Function() modelsDirProvider = _defaultModelsDir;

  static Future<Directory> _defaultModelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/speech_models');
  }

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _chunkTimer;
  bool _recording = false;
  String? _currentChunkPath;
  int _chunkStartMs = 0;

  /// Completes when the chunk timer is not mid-rotation.
  ///
  /// The rotation stops the recorder and starts a new one, which are
  /// both awaits. stopLive() waits for this so it does not read the
  /// chunk path while the timer is swapping it.
  Completer<void>? _rotationDone;

  /// Session-relative clock origin so segment timestamps are mm:ss
  /// offsets, not epoch ms.
  int _sessionStartMs = 0;

  bool get isRecording => _recording;

  /// Seconds per live-recording chunk. Shorter = lower latency but
  /// less context; 5s is a good balance.
  int chunkSeconds = 5;

  /// Beam size / sensitivity knob mapped per engine:
  /// whisper: -bs N beam size 1-5 (5 = most careful)
  /// parakeet: not applicable
  int sensitivity = 3;

  // ----------------------------------------------------------
  // engine + model management
  // ----------------------------------------------------------

  /// Resolve which binary is available for the preferred engine.
  Future<SpeechEngine?> detectEngine(SpeechEngine preferred) async {
    if (preferred == SpeechEngine.api) return SpeechEngine.api;
    // mobile: whisper.cpp runs in-process via the whisper_ggml FFI
    // plugin — no external binary to probe
    if (_isMobile && preferred == SpeechEngine.whisper) {
      return SpeechEngine.whisper;
    }
    final binary = switch (preferred) {
      SpeechEngine.whisper => '/usr/bin/whisper-cli',
      SpeechEngine.parakeet => '/usr/bin/parakeet-cli',
      SpeechEngine.api => '',
    };
    try {
      final (code, out, err) = await runCommand(binary, ['--version']);
      log(
        'info',
        'probe $binary --version -> exit=$code '
            '${out.trim().split('\n').firstOrNull ?? err.trim().split('\n').firstOrNull ?? ''}',
      );
      if (code == 0) return preferred;
    } catch (e) {
      log('warn', 'probe $binary failed: $e');
    }
    // fall back to the other engine when present
    final fallback = switch (preferred) {
      SpeechEngine.whisper => '/usr/bin/parakeet-cli',
      SpeechEngine.parakeet => '/usr/bin/whisper-cli',
      SpeechEngine.api => '',
    };
    try {
      final (code, out, err) = await runCommand(fallback, ['--version']);
      log(
        'info',
        'probe $fallback --version -> exit=$code '
            '${out.trim().split('\n').firstOrNull ?? err.trim().split('\n').firstOrNull ?? ''}',
      );
      if (code == 0) {
        return preferred == SpeechEngine.whisper
            ? SpeechEngine.parakeet
            : SpeechEngine.whisper;
      }
    } catch (e) {
      log('warn', 'probe $fallback failed: $e');
    }
    log('error', 'no STT engine binary found');
    return null;
  }

  /// whisper.cpp ggml model names available for download.
  static const Map<String, String> whisperModels = {
    'tiny': 'ggml-tiny.bin',
    'base': 'ggml-base.bin',
    'small': 'ggml-small.bin',
    'medium': 'ggml-medium.bin',
    'large-v1': 'ggml-large-v1.bin',
    'large-v2': 'ggml-large-v2.bin',
    'large-v3': 'ggml-large-v3.bin',
    'tiny.en': 'ggml-tiny.en.bin',
    'base.en': 'ggml-base.en.bin',
    'small.en': 'ggml-small.en.bin',
    'medium.en': 'ggml-medium.en.bin',
  };

  /// Model titles for the UI, mimiuchi-style.
  static const Map<String, String> whisperModelTitles = {
    'tiny': 'Tiny (Multilingual)',
    'base': 'Base (Multilingual)',
    'small': 'Small (Multilingual)',
    'medium': 'Medium (Multilingual)',
    'large-v1': 'Large-v1',
    'large-v2': 'Large-v2',
    'large-v3': 'Large-v3',
    'tiny.en': 'Tiny (English only)',
    'base.en': 'Base (English only)',
    'small.en': 'Small (English only)',
    'medium.en': 'Medium (English only)',
  };

  /// Local model path for the engine, downloading when missing.
  /// Returns null when no model could be obtained.
  Future<String?> ensureModel(
    SpeechEngine engine, {
    String modelSize = 'base',
  }) async {
    switch (engine) {
      case SpeechEngine.api:
        return '';
      case SpeechEngine.whisper:
        if (_isMobile) {
          // whisper_ggml downloads and caches the ggml model itself on
          // first transcribe; no manual file management needed
          return modelSize;
        }
        final file = whisperModels[modelSize] ?? whisperModels['base']!;
        final dir = await modelsDirProvider();
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final path = '${dir.path}/$file';
        if (File(path).existsSync()) {
          log('info', 'model present: $path');
          return path;
        }
        final url =
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$file';
        log('info', 'downloading model $file -> $path');
        try {
          final (code, _, stderr) = await runCommand('curl', [
            '-sL',
            '-o',
            path,
            url,
          ]);
          if (code == 0 && File(path).existsSync()) {
            log('info', 'model downloaded ($file)');
            return path;
          }
          log('error', 'speech model download failed: $stderr');
        } catch (e) {
          log('error', 'speech model download threw: $e');
        }
        return null;
      case SpeechEngine.parakeet:
        final dir = await modelsDirProvider();
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final path = '${dir.path}/ggml-parakeet-tdt-0.6b-v3.bin';
        if (File(path).existsSync()) {
          log('info', 'model present: $path');
          return path;
        }
        const url =
            'https://huggingface.co/ggml-org/parakeet-tdt-0.6b-v3-ggml/resolve/main/ggml-parakeet-tdt-0.6b-v3-q8_0.bin';
        log('info', 'downloading parakeet model -> $path');
        try {
          final (code, _, stderr) = await runCommand('curl', [
            '-sL',
            '-o',
            path,
            url,
          ]);
          if (code == 0 && File(path).existsSync()) {
            log('info', 'parakeet model downloaded');
            return path;
          }
          log('error', 'parakeet model download failed: $stderr');
        } catch (e) {
          log('error', 'parakeet model download threw: $e');
        }
        return null;
    }
  }

  // ----------------------------------------------------------
  // transcription
  // ----------------------------------------------------------

  /// Transcribe an audio file. [language] is a whisper language
  /// code ('auto' for auto-detect). Returns (text, detectedLang).
  ///
  /// [suppressRepetition] enables the anti-hallucination flags: short
  /// chunks with no prior context are where whisper loops hardest (the
  /// same phrase repeated until the window fills), so live transcription
  /// turns context off and suppresses non-speech tokens; one-shot file
  /// transcription keeps defaults.
  Future<(String, String?)> transcribeFile(
    String path, {
    required SpeechEngine engine,
    required String modelPath,
    String language = 'auto',
    bool suppressRepetition = false,
  }) async {
    // Mobile: on-device whisper.cpp via the whisper_ggml FFI plugin —
    // the desktop whisper-cli binary doesn't exist there. The model
    // downloads on first use (initModel inside transcribe).
    if (engine == SpeechEngine.whisper && _isMobile) {
      final controller = WhisperController();
      final result = await controller.transcribe(
        model: _whisperModelEnum(modelPath),
        audioPath: path,
        lang: language,
        keepModelLoaded: true, // chunked live transcription skips reloads
        // maxContext 0: earlier text stops conditioning the next window,
        // which is exactly how a hallucinated phrase repeats across
        // chunks; suppressNonSpeechTokens drops the music/applause
        // tokens that feed the loop.
        maxContext: suppressRepetition ? 0 : null,
        suppressNonSpeechTokens: suppressRepetition,
      );
      final text = _stripRepeatedLines(result?.transcription.text.trim() ?? '');
      return (text, language == 'auto' ? null : language);
    }

    final binary = switch (engine) {
      SpeechEngine.whisper => '/usr/bin/whisper-cli',
      SpeechEngine.parakeet => '/usr/bin/parakeet-cli',
      SpeechEngine.api => '',
    };
    final args = <String>['-m', modelPath, '-f', path, '-t', '4'];
    if (engine == SpeechEngine.whisper) {
      args
        ..add('-l')
        ..add(language == 'auto' ? 'auto' : language);
      // sensitivity: beam size 1-5
      final beam = sensitivity.clamp(1, 5);
      if (beam > 1) {
        args
          ..add('-bs')
          ..add('$beam');
      }
      if (suppressRepetition) {
        // --no-context: drop prior-window conditioning (the hallucination
        // loop driver); --suppress-nst: mute music/applause tokens.
        args
          ..add('--no-context')
          ..add('--suppress-nst');
      }
    }
    if (debugLogging) {
      // --print-progress and --print-confidence make the CLI report what
      // it is doing; without them a silent binary looks like a hang.
      args.addAll(['--print-progress']);
      if (engine == SpeechEngine.whisper) {
        args.addAll(['--print-confidence']);
      }
    }
    log('info', 'exec: $binary ${args.join(' ')}');
    final stopwatch = Stopwatch()..start();
    final (code, stdout_, stderr) = await runCommand(binary, args);
    stopwatch.stop();
    log(
      'info',
      'exec done: exit=$code elapsed=${stopwatch.elapsedMilliseconds}ms '
          'stdout=${stdout_.length}B stderr=${stderr.length}B',
    );
    if (stderr.isNotEmpty) {
      // whisper.cpp writes its banner and timings to stderr; the tail
      // carries the useful part.
      final tail = stderr
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final start = tail.length > 12 ? tail.length - 12 : 0;
      for (final line in tail.sublist(start)) {
        log('debug', 'stderr: $line');
      }
    }
    if (code != 0) {
      log('error', 'transcription failed (exit $code)');
      throw Exception('transcription failed: $stderr');
    }
    final parsed = _parseWhisperOutput(stdout_);
    final text = _stripRepeatedLines(parsed);
    var lang = language == 'auto' ? _detectLanguageTag(stdout_) : language;
    log(
      'info',
      'parsed ${parsed.split('\n').where((l) => l.trim().isNotEmpty).length} '
          'segment line(s), ${text.length} chars, lang=${lang ?? '?'}',
    );
    if (text.isEmpty) {
      log(
        'warn',
        'no text produced — the audio may be silent, or the model found '
            'no speech in it',
      );
    } else {
      log(
        'info',
        'text: ${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
      );
    }
    return (text, lang);
  }

  /// Collapse within-transcript hallucination loops: whisper repeating a
  /// phrase line-for-line until its window fills collapses to a single
  /// occurrence. Cross-chunk repeats are handled by the caller, which
  /// knows the previous segment's text.
  static String _stripRepeatedLines(String text) {
    if (text.isEmpty) return text;
    final out = <String>[];
    for (final line in text.split('\n')) {
      if (out.isNotEmpty && out.last.trim() == line.trim()) continue;
      out.add(line);
    }
    return out.join('\n');
  }

  /// OpenAI-compatible STT API: multipart audio POST, JSON text back.
  Future<(String, String?)> transcribeApi(
    String path, {
    required String apiUrl,
    required String apiKey,
    String language = 'auto',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(apiUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..files.add(await http.MultipartFile.fromPath('file', path))
      ..fields['model'] = 'whisper-1'
      ..fields['response_format'] = 'json';
    if (language != 'auto') {
      request.fields['language'] = language;
    }

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('STT API failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) throw Exception('unexpected STT API response');
    final text = decoded['text']?.toString() ?? '';
    final lang = decoded['language']?.toString();
    return (text.trim(), lang?.toLowerCase());
  }

  /// Map a modelSize string (tiny/base/.../large-v3) to the
  /// whisper_ggml enum. large-v1/v2 fold into large (v3) — the plugin
  /// only ships v3.
  static WhisperModel _whisperModelEnum(String modelSize) {
    switch (modelSize) {
      case 'tiny':
        return WhisperModel.tiny;
      case 'tiny.en':
        return WhisperModel.tinyEn;
      case 'base':
        return WhisperModel.base;
      case 'base.en':
        return WhisperModel.baseEn;
      case 'small':
        return WhisperModel.small;
      case 'small.en':
        return WhisperModel.smallEn;
      case 'medium':
        return WhisperModel.medium;
      case 'medium.en':
        return WhisperModel.mediumEn;
      default:
        return WhisperModel.large; // large-v1/v2/v3
    }
  }

  /// True on mobile platforms where the desktop whisper-cli binary
  /// cannot exist.
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// whisper-cli prints segments as
  /// `[start --> end]  text` lines (and a header with detected
  /// language when auto).
  String _parseWhisperOutput(String out) {
    final buf = StringBuffer();
    for (final line in out.split('\n')) {
      final m = RegExp(
        r'\[\s*[\d:.]+\s*-->\s*[\d:.]+\s*\]\s*(.*)$',
      ).firstMatch(line);
      if (m != null) {
        final seg = m.group(1)!.trim();
        if (seg.isNotEmpty) {
          buf.writeln(seg);
        }
      }
    }
    return buf.toString().trim();
  }

  String? _detectLanguageTag(String out) {
    final m = RegExp(
      r'detected language:\s*([A-Za-z]+)',
      caseSensitive: false,
    ).firstMatch(out);
    return m?.group(1)?.toLowerCase();
  }

  // ----------------------------------------------------------
  // live mic sensitivity meter (RMS level + active device)
  // ----------------------------------------------------------

  StreamSubscription<Amplitude>? _meterSub;
  String _meterPath = '';

  /// Start a bare mic stream and report RMS levels through [onLevel].
  /// Returns false when the mic is unavailable. [onDevice] fires once
  /// with the active input device label.
  Future<bool> startMeter(
    void Function(double level, String device) onLevel,
  ) async {
    if (!await _recorder.hasPermission()) return false;
    // No capture device: `record` would still "succeed" and leave the
    // meter pinned at zero forever.
    final mic = await micAvailable();
    if (mic == false) return false;
    try {
      final dir = await modelsDirProvider();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _meterPath =
          '${dir.path}/sensitivity_probe_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: _meterPath,
      );

      try {
        final devices = await _recorder.listInputDevices();
        if (devices.isNotEmpty) onLevel(0, devices.first.label);
      } catch (_) {}
      onLevel(0, '');

      double last = 0;
      _meterSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            // amp.current is dBFS (-inf..0); map to 0..1
            final db = amp.current.isNaN ? -60.0 : amp.current;
            final level = ((db + 60) / 60).clamp(0.0, 1.0);
            final smoothed = (level + last) / 2;
            last = smoothed;
            onLevel(smoothed, '');
          });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stop the sensitivity meter stream and discard the probe file.
  Future<void> stopMeter() async {
    await _meterSub?.cancel();
    _meterSub = null;
    try {
      await _recorder.stop();
      final f = File(_meterPath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  // ----------------------------------------------------------
  // live recording (chunked mic capture -> per-chunk STT)
  // ----------------------------------------------------------

  /// Start live speech-to-text. [onSegment] fires for every
  /// transcribed chunk. [onChunkRecorded] fires when a chunk is
  /// ready for transcription (before the text arrives).
  Future<bool> startLive({
    required SpeechEngine engine,
    required String modelPath,
    required String language,
    required void Function(SpeechSegment segment) onSegment,
    void Function(int chunkIndex)? onChunkRecorded,
    String? apiUrl,
    String? apiKey,
    void Function(String message)? onError,
    String? deviceId,
  }) async {
    if (_recording) return false;
    if (!await _recorder.hasPermission()) return false;

    log('info', 'startLive: engine=$engine model=$modelPath lang=$language');

    _recording = true;
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _chunkStartMs = _sessionStartMs;
    var chunkIndex = 0;

    try {
      final dir = await modelsDirProvider();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final chunk0 = '${dir.path}/live_chunk_0.wav';
      _currentChunkPath = chunk0;
      final config = _recordConfig(deviceId);
      log(
        'info',
        'recorder config: device=${config.device?.id ?? '<default>'} '
            'rate=${config.sampleRate} channels=${config.numChannels}',
      );
      await _recorder.start(config, path: chunk0);
      log('info', 'recorder started -> $chunk0');

      _chunkTimer = Timer.periodic(Duration(seconds: chunkSeconds), (_) async {
        if (!_recording) return;
        // The chunk paths are captured as locals: stopLive() clears
        // _currentChunkPath while this callback is suspended on the
        // recorder's await, and reading the field afterwards would hit
        // a null. The locals keep the two chunks distinct even when
        // the session ends mid-rotation.
        final finishedPath = _currentChunkPath;
        if (finishedPath == null) return;
        final startMs = _chunkStartMs - _sessionStartMs;
        // rotate to a fresh chunk file
        chunkIndex++;
        final nextPath = '${dir.path}/live_chunk_$chunkIndex.wav';
        _currentChunkPath = nextPath;
        _chunkStartMs = DateTime.now().millisecondsSinceEpoch;
        log('info', 'chunk $chunkIndex closed: $finishedPath');
        // stopLive() waits for this so it does not read the chunk path
        // while it is being swapped
        final rotation = Completer<void>();
        _rotationDone = rotation;
        try {
          await _recorder.stop();
          final size = _fileSize(finishedPath);
          log(
            size == null ? 'warn' : 'info',
            size == null
                ? 'chunk $chunkIndex produced no file'
                : 'chunk $chunkIndex size=$size bytes',
          );
          if (_recording) {
            await _recorder.start(config, path: nextPath);
            onChunkRecorded?.call(chunkIndex - 1);
          }
        } finally {
          _rotationDone = null;
          if (!rotation.isCompleted) rotation.complete();
        }
        await _transcribeChunk(
          finishedPath: finishedPath,
          startMs: startMs,
          engine: engine,
          modelPath: modelPath,
          language: language,
          apiUrl: apiUrl,
          apiKey: apiKey,
          onSegment: onSegment,
          onError: onError,
        );
      });
      return true;
    } catch (e) {
      _recording = false;
      log('error', 'live start failed: $e');
      onError?.call('microphone unavailable');
      return false;
    }
  }

  /// The recorder configuration, honouring the selected capture device.
  @visibleForTesting
  RecordConfig recordConfigForTest([String? deviceId]) =>
      _recordConfig(deviceId);

  RecordConfig _recordConfig(String? deviceId) {
    final id = deviceId ?? _selectedDeviceId;
    return RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      device: id == null || id.isEmpty ? null : InputDevice(id: id, label: id),
    );
  }

  /// Size of [path] in bytes, or null when the file does not exist.
  static int? _fileSize(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return f.lengthSync();
    } catch (_) {
      return null;
    }
  }

  /// Transcribe one finished live chunk and report it as a segment.
  ///
  /// The chunk file is deleted afterwards, whether the transcription
  /// succeeded or not, so a failing chunk does not leave files behind.
  Future<void> _transcribeChunk({
    required String finishedPath,
    required int startMs,
    required SpeechEngine engine,
    required String modelPath,
    required String language,
    required String? apiUrl,
    required String? apiKey,
    required void Function(SpeechSegment segment) onSegment,
    void Function(String message)? onError,
  }) async {
    try {
      // A chunk file that was never written means the recorder captured
      // nothing: there is no capture device, or the device was busy.
      // Reporting that beats silently transcribing nothing.
      if (!File(finishedPath).existsSync()) {
        log('error', 'chunk file missing: $finishedPath');
        onError?.call('no audio captured');
        return;
      }
      final size = _fileSize(finishedPath);
      log('info', 'transcribing chunk $finishedPath (${size ?? 0} bytes)');
      final (text, lang) = engine == SpeechEngine.api
          ? await transcribeApi(
              finishedPath,
              apiUrl: apiUrl ?? '',
              apiKey: apiKey ?? '',
              language: language,
            )
          : await transcribeFile(
              finishedPath,
              engine: engine,
              modelPath: modelPath,
              language: language,
              // live chunks are 5s slivers: prime hallucination
              // territory (see transcribeFile)
              suppressRepetition: true,
            );
      if (text.trim().isNotEmpty) {
        log('info', 'chunk produced ${text.length} chars');
        onSegment(
          SpeechSegment(
            text: text.trim(),
            language: lang,
            startMs: startMs,
            endMs: DateTime.now().millisecondsSinceEpoch - _sessionStartMs,
          ),
        );
      } else {
        log('warn', 'chunk produced no text');
      }
    } catch (e) {
      log('error', 'chunk transcription failed: $e');
      onError?.call('transcription failed');
    } finally {
      // keep only the current chunk file on disk
      try {
        final f = File(finishedPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Stop live capture and transcribe the trailing chunk.
  Future<void> stopLive({
    required SpeechEngine engine,
    required String modelPath,
    required String language,
    required void Function(SpeechSegment segment) onSegment,
    String? apiUrl,
    String? apiKey,
    void Function(String message)? onError,
  }) async {
    if (!_recording) return;
    log('info', 'stopLive');
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _recording = false;
    // The chunk timer may be mid-rotation (suspended on the recorder's
    // stop). Wait for it to finish before reading the path, otherwise
    // the trailing chunk is the *next* (empty) file and the chunk
    // that actually holds audio is lost.
    await _rotationDone?.future;
    final path = _currentChunkPath;
    final startMs = _chunkStartMs - _sessionStartMs;
    try {
      await _recorder.stop();
      log('info', 'recorder stopped');
    } catch (e) {
      log('warn', 'recorder stop failed: $e');
    }
    if (path == null) return;
    try {
      final size = _fileSize(path);
      if (size != null) {
        log('info', 'transcribing trailing chunk $path ($size bytes)');
        final (text, lang) = await (engine == SpeechEngine.api
            ? transcribeApi(
                path,
                apiUrl: apiUrl ?? '',
                apiKey: apiKey ?? '',
                language: language,
              )
            : transcribeFile(
                path,
                engine: engine,
                modelPath: modelPath,
                language: language,
                // trailing live chunk: same anti-hallucination rules
                suppressRepetition: true,
              ));
        if (text.trim().isNotEmpty) {
          log('info', 'trailing chunk produced ${text.length} chars');
          onSegment(
            SpeechSegment(
              text: text.trim(),
              language: lang,
              startMs: startMs,
              endMs: DateTime.now().millisecondsSinceEpoch - _sessionStartMs,
            ),
          );
        } else {
          log('warn', 'trailing chunk produced no text');
        }
        File(path).deleteSync();
      } else {
        log('error', 'trailing chunk file missing: $path');
        onError?.call('no audio captured');
      }
    } catch (e) {
      log('error', 'trailing chunk transcription failed: $e');
      onError?.call('transcription failed');
    }
    _currentChunkPath = null;
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @visibleForTesting
  void resetForTest() {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _recording = false;
    runCommand = _realRunner;
    modelsDirProvider = _defaultModelsDir;
    micProbeOverride = null;
    debugLogging = false;
    _logEntries.clear();
    _captureDevices.clear();
    _selectedDeviceId = null;
    _appStreams.clear();
    _capturedAppIndex = null;
    _capturedAppOriginalSink = null;
  }
}
