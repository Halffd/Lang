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
      final (code, _, _) = await runCommand(binary, ['--version']);
      if (code == 0) return preferred;
    } catch (_) {}
    // fall back to the other engine when present
    final fallback = switch (preferred) {
      SpeechEngine.whisper => '/usr/bin/parakeet-cli',
      SpeechEngine.parakeet => '/usr/bin/whisper-cli',
      SpeechEngine.api => '',
    };
    try {
      final (code, _, _) = await runCommand(fallback, ['--version']);
      if (code == 0) {
        return preferred == SpeechEngine.whisper
            ? SpeechEngine.parakeet
            : SpeechEngine.whisper;
      }
    } catch (_) {}
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
        if (File(path).existsSync()) return path;
        final url =
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$file';
        try {
          final (code, _, stderr) = await runCommand('curl', [
            '-sL',
            '-o',
            path,
            url,
          ]);
          if (code == 0 && File(path).existsSync()) return path;
          debugPrint('speech model download failed: $stderr');
        } catch (_) {}
        return null;
      case SpeechEngine.parakeet:
        final dir = await modelsDirProvider();
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final path = '${dir.path}/ggml-parakeet-tdt-0.6b-v3.bin';
        if (File(path).existsSync()) return path;
        const url =
            'https://huggingface.co/ggml-org/parakeet-tdt-0.6b-v3-ggml/resolve/main/ggml-parakeet-tdt-0.6b-v3-q8_0.bin';
        try {
          final (code, _, stderr) = await runCommand('curl', [
            '-sL',
            '-o',
            path,
            url,
          ]);
          if (code == 0 && File(path).existsSync()) return path;
          debugPrint('parakeet model download failed: $stderr');
        } catch (_) {}
        return null;
    }
  }

  // ----------------------------------------------------------
  // transcription
  // ----------------------------------------------------------

  /// Transcribe an audio file. [language] is a whisper language
  /// code ('auto' for auto-detect). Returns (text, detectedLang).
  Future<(String, String?)> transcribeFile(
    String path, {
    required SpeechEngine engine,
    required String modelPath,
    String language = 'auto',
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
      );
      final text = result?.transcription.text.trim() ?? '';
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
    }
    final (code, stdout_, stderr) = await runCommand(binary, args);
    if (code != 0) {
      throw Exception('transcription failed: $stderr');
    }
    final text = _parseWhisperOutput(stdout_);
    var lang = language == 'auto' ? _detectLanguageTag(stdout_) : language;
    return (text, lang);
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
  }) async {
    if (_recording) return false;
    if (!await _recorder.hasPermission()) return false;

    _recording = true;
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _chunkStartMs = _sessionStartMs;
    var chunkIndex = 0;

    try {
      final dir = await modelsDirProvider();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _currentChunkPath = '${dir.path}/live_chunk_0.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentChunkPath!,
      );

      _chunkTimer = Timer.periodic(Duration(seconds: chunkSeconds), (_) async {
        if (!_recording) return;
        final finishedPath = _currentChunkPath;
        final startMs = _chunkStartMs - _sessionStartMs;
        // rotate to a fresh chunk file
        chunkIndex++;
        _currentChunkPath = '${dir.path}/live_chunk_$chunkIndex.wav';
        _chunkStartMs = DateTime.now().millisecondsSinceEpoch;
        await _recorder.stop();
        if (_recording) {
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: _currentChunkPath!,
          );
        }
        onChunkRecorded?.call(chunkIndex - 1);
        // transcribe the finished chunk
        try {
          final (text, lang) = engine == SpeechEngine.api
              ? await transcribeApi(
                  finishedPath!,
                  apiUrl: apiUrl ?? '',
                  apiKey: apiKey ?? '',
                  language: language,
                )
              : await transcribeFile(
                  finishedPath!,
                  engine: engine,
                  modelPath: modelPath,
                  language: language,
                );
          if (text.trim().isNotEmpty) {
            onSegment(
              SpeechSegment(
                text: text.trim(),
                language: lang,
                startMs: startMs,
                endMs: DateTime.now().millisecondsSinceEpoch - _sessionStartMs,
              ),
            );
          }
        } catch (e) {
          debugPrint('chunk transcription failed: $e');
        } finally {
          // keep only the current chunk file on disk
          try {
            final f = File(finishedPath!);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
      });
      return true;
    } catch (e) {
      _recording = false;
      debugPrint('live start failed: $e');
      return false;
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
  }) async {
    if (!_recording) return;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _recording = false;
    final path = _currentChunkPath;
    final startMs = _chunkStartMs - _sessionStartMs;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (path == null) return;
    try {
      if (File(path).existsSync()) {
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
              ));
        if (text.trim().isNotEmpty) {
          onSegment(
            SpeechSegment(
              text: text.trim(),
              language: lang,
              startMs: startMs,
              endMs: DateTime.now().millisecondsSinceEpoch - _sessionStartMs,
            ),
          );
        }
        File(path).deleteSync();
      }
    } catch (_) {}
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
  }
}
