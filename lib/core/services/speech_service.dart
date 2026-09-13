import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// STT engine preference.
enum SpeechEngine { whisper, parakeet }

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
    final binary = switch (preferred) {
      SpeechEngine.whisper => '/usr/bin/whisper-cli',
      SpeechEngine.parakeet => '/usr/bin/parakeet-cli',
    };
    try {
      final (code, _, _) = await runCommand(binary, ['--version']);
      if (code == 0) return preferred;
    } catch (_) {}
    // fall back to the other engine when present
    final fallback = switch (preferred) {
      SpeechEngine.whisper => '/usr/bin/parakeet-cli',
      SpeechEngine.parakeet => '/usr/bin/whisper-cli',
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
    'large-v3': 'ggml-large-v3.bin',
    'tiny.en': 'ggml-tiny.en.bin',
    'base.en': 'ggml-base.en.bin',
    'small.en': 'ggml-small.en.bin',
  };

  /// Local model path for the engine, downloading when missing.
  /// Returns null when no model could be obtained.
  Future<String?> ensureModel(
    SpeechEngine engine, {
    String modelSize = 'base',
  }) async {
    switch (engine) {
      case SpeechEngine.whisper:
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
    final binary = switch (engine) {
      SpeechEngine.whisper => '/usr/bin/whisper-cli',
      SpeechEngine.parakeet => '/usr/bin/parakeet-cli',
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
  }) async {
    if (_recording) return false;
    if (!await _recorder.hasPermission()) return false;

    _recording = true;
    _chunkStartMs = DateTime.now().millisecondsSinceEpoch;
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
        final startMs = _chunkStartMs;
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
          final (text, lang) = await transcribeFile(
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
                endMs: DateTime.now().millisecondsSinceEpoch,
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
  }) async {
    if (!_recording) return;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _recording = false;
    final path = _currentChunkPath;
    final startMs = _chunkStartMs;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (path == null) return;
    try {
      if (File(path).existsSync()) {
        final (text, lang) = await transcribeFile(
          path,
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
              endMs: DateTime.now().millisecondsSinceEpoch,
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
