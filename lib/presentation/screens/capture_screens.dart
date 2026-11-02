import 'package:flutter/material.dart';

import 'package:lang/presentation/screens/screenshot_tab.dart';
import 'package:lang/presentation/screens/speech_tab.dart';

/// Standalone screen for the OCR/screenshot capture + history pipeline.
/// Previously embedded inside the search and reader screens; now its own
/// bottom-bar destination so it is directly reachable.
class ScreenshotScreen extends StatelessWidget {
  const ScreenshotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 44, title: const Text('OCR / Screenshot')),
      body: const ScreenshotTab(),
    );
  }
}

/// Standalone speech-to-text screen: live mic chunks, transcript with
/// furigana, word cards. Its own bottom-bar destination, mid-bar where
/// capture screens belong.
class SpeechScreen extends StatelessWidget {
  const SpeechScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SpeechTab();
  }
}
