import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';

/// Scaled font size for a text group: [base] * global multiplier *
/// per-group multiplier from [AppState].
///
/// Groups: headers, sentences, translations, words, kanji, ui.
double fs(BuildContext context, double base, [String group = 'ui']) {
  final appState = context.read<AppState>();
  final global = appState.fontSizeMultiplier;
  final s = appState.fontSettings;
  final groupMult = switch (group) {
    'headers' => s.headers,
    'sentences' => s.sentences,
    'translations' => s.translations,
    'words' => s.words,
    'kanji' => s.kanji,
    _ => s.ui,
  };
  return base * global * groupMult;
}
