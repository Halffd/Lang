import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/domain/entities/app_state.dart';

/// Caps a text input at the user-configured fraction of the viewport
/// ([AppState.inputMaxHeightFraction], default 0.5). Long text scrolls
/// inside the field instead of pushing the layout past the screen.
///
/// Used by every multiline input across screens — analyze, search,
/// speech, writer, scanner, AI chat — so the limit is one setting
/// everywhere instead of per-screen magic numbers.
/// Falls back to the default fraction when no [AppState] provider is
/// mounted above (standalone routes, tests).
class BoundedInput extends StatelessWidget {
  final Widget child;

  const BoundedInput({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    AppState? appState;
    try {
      appState = context.watch<AppState>();
    } on ProviderNotFoundException {
      appState = null;
    }
    final fraction = appState?.inputMaxHeightFraction ?? 0.5;
    final viewport = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: viewport * fraction),
      child: child,
    );
  }
}
