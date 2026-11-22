import 'package:flutter/material.dart';

import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/ai_screen.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';
import 'package:lang/presentation/screens/capture_screens.dart';
import 'package:lang/presentation/screens/dictionary_screen.dart';
import 'package:lang/presentation/screens/history_screen.dart';
import 'package:lang/presentation/screens/reader/video_tab.dart';
import 'package:lang/presentation/screens/reader_screen.dart';
import 'package:lang/presentation/screens/saved_words_screen.dart';
import 'package:lang/presentation/screens/scanner_screen.dart';
import 'package:lang/presentation/screens/search_screen.dart';
import 'package:lang/presentation/screens/srs_screen.dart';
import 'package:lang/presentation/screens/study_screen.dart';
import 'package:lang/presentation/screens/writer_screen.dart';

/// One navigation destination: the screen it shows, the route name
/// used by the popup-dictionary screen scope, and its bar label.
class NavDestination {
  final String route;
  final IconData icon;
  final Widget screen;

  /// Localization key for the label; null when [label] is a literal.
  final String? labelKey;
  final String? label;

  const NavDestination({
    required this.route,
    required this.icon,
    required this.screen,
    this.labelKey,
    this.label,
  });

  /// Localized bar label.
  String resolveLabel(AppLocalizations l10n) {
    final key = labelKey;
    if (key == null) return label ?? '';
    return switch (key) {
      'analyze' => l10n.analyze,
      'search' => l10n.search,
      'reader' => l10n.reader,
      'dictionaries' => l10n.dictionaries,
      'writerTitle' => l10n.writerTitle,
      'saved' => l10n.saved,
      'history' => l10n.history,
      'ai' => l10n.ai,
      _ => label ?? key,
    };
  }
}

/// The app's navigation destinations, in bar order.
///
/// Single source of truth: the bottom bar renders this list, the
/// shell switches screens by index into it, and the settings screen
/// builds its "default screen" dropdown from it. The three used to
/// be separate lists, and they disagreed — the bar had 12 entries
/// against 14 screens, so every destination after the second opened
/// the wrong screen.
const List<NavDestination> navDestinations = [
  NavDestination(
    route: 'analyze',
    icon: Icons.analytics,
    labelKey: 'analyze',
    screen: AnalyzeScreen(),
  ),
  NavDestination(
    route: 'search',
    icon: Icons.search,
    labelKey: 'search',
    screen: SearchScreen(),
  ),
  NavDestination(
    route: 'scanner',
    icon: Icons.document_scanner,
    label: 'Scan',
    screen: ScannerScreen(),
  ),
  NavDestination(
    route: 'screenshot',
    icon: Icons.screenshot_monitor,
    label: 'OCR',
    screen: ScreenshotScreen(),
  ),
  NavDestination(
    route: 'speech',
    icon: Icons.mic_none_rounded,
    label: 'Speech',
    screen: SpeechScreen(),
  ),
  NavDestination(
    route: 'reader',
    icon: Icons.menu_book,
    labelKey: 'reader',
    screen: ReaderScreen(),
  ),
  NavDestination(
    route: 'dictionary',
    icon: Icons.sort_by_alpha,
    labelKey: 'dictionaries',
    screen: DictionaryScreen(),
  ),
  NavDestination(
    route: 'writer',
    icon: Icons.edit_note,
    labelKey: 'writerTitle',
    screen: WriterScreen(),
  ),
  NavDestination(
    route: 'saved',
    icon: Icons.bookmark,
    labelKey: 'saved',
    screen: SavedWordsScreen(),
  ),
  NavDestination(
    route: 'history',
    icon: Icons.history,
    labelKey: 'history',
    screen: HistoryScreen(),
  ),
  NavDestination(
    route: 'srs',
    icon: Icons.school,
    label: 'SRS',
    screen: SRSScreen(),
  ),
  NavDestination(
    route: 'ai',
    icon: Icons.auto_awesome,
    labelKey: 'ai',
    screen: AiScreen(),
  ),
  NavDestination(
    route: 'study',
    icon: Icons.local_play,
    label: 'Study',
    screen: StudyScreen(),
  ),
  NavDestination(
    route: 'video',
    icon: Icons.play_circle_outline,
    label: 'Video',
    screen: VideoTab(),
  ),
];

/// Index of the destination with [route], or -1 when unknown.
int navIndexOfRoute(String route) =>
    navDestinations.indexWhere((d) => d.route == route);
