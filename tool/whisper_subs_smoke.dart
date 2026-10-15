// Live smoke test for the whisper-subs server integration.
//
// Sends a source to a real server through WhisperSubsService — the same
// path the video tab's WhisperSubs button uses — and prints the SRT it
// gets back. Exits non-zero on any failure.
//
// Usage:
//   dart run tool/whisper_subs_smoke.dart <server-url> <api-key> \
//       <source-url-or-file> [model]

import 'dart:io';

import 'package:lang/core/services/whisper_subs_service.dart';
import 'package:lang/utils/subtitle_parser.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'usage: dart run tool/whisper_subs_smoke.dart '
      '<server-url> <api-key> <source-url-or-file> [model]',
    );
    exit(2);
  }
  final service = WhisperSubsService(baseUrl: args[0], apiKey: args[1]);
  final source = args[2];
  final model = args.length > 3 ? args[3] : 'large-v3';

  final me = await service.authMe();
  stdout.writeln('connected as ${me['username']}');

  final srt = await service.transcribeForSrt(
    source,
    model: model,
    onStatus: (line) => stdout.writeln('  $line'),
  );
  final cues = SubtitleParser.parseSrt(srt);
  stdout.writeln('srt bytes: ${srt.length}, cues: ${cues.length}');
  if (cues.isEmpty) {
    stderr.writeln('no cues parsed from the produced SRT');
    exit(1);
  }
  for (final cue in cues.take(3)) {
    stdout.writeln(
      '  ${cue.startDuration} -> ${cue.endDuration}: ${cue.plainText}',
    );
  }
  stdout.writeln('SMOKE OK');
}
