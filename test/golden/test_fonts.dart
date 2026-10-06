import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto and MaterialIcons from the flutter SDK so golden baselines
/// render real glyphs.
///
/// Widget tests bundle no fonts: without this every glyph renders as an
/// identical Ahem block. That still catches layout shifts, but a human
/// reviewing a golden diff cannot tell a text change from a rendering
/// change. Roboto and MaterialIcons ship inside the SDK the tests already run
/// on, so there is no hardcoded machine path: [Platform.resolvedExecutable]
/// points inside the SDK cache (flutter_tester or the dart VM), and we walk
/// up until the material_fonts artifact directory shows up. If it is missing
/// (non-standard SDK layout) we silently keep the Ahem fallback, which stays
/// deterministic.
///
/// CJK glyphs are not in Roboto; they fall back to the block font, but they
/// do so deterministically, so baselines remain stable.
Future<void> loadAppFonts() async {
  final dir = _findMaterialFontsDir();
  if (dir == null) {
    return;
  }

  Future<void> load(String file, String family) async {
    final font = File('${dir.path}/$file');
    if (!font.existsSync()) {
      return;
    }
    final bytes = await font.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(bytes.buffer.asByteData()));
    await loader.load();
  }

  await load('Roboto-Regular.ttf', 'Roboto');
  await load('Roboto-Medium.ttf', 'Roboto');
  await load('Roboto-Bold.ttf', 'Roboto');
  await load('MaterialIcons-Regular.otf', 'MaterialIcons');
}

Directory? _findMaterialFontsDir() {
  var current = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    for (final candidate in [
      Directory('${current.path}/artifacts/material_fonts'),
      Directory('${current.path}/bin/cache/artifacts/material_fonts'),
      Directory('${current.path}/cache/artifacts/material_fonts'),
    ]) {
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return null;
}
