import 'package:flutter/material.dart';
import 'package:lang/presentation/widgets/word_action_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/label_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart' as font_scale;
import 'package:lang/utils/popup_scan_blocker.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:lang/presentation/widgets/app_context_menu.dart';

import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/font_zoom.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';
import 'package:lang/presentation/widgets/structured_definition.dart';
import 'package:lang/presentation/widgets/script_text_field.dart';
import 'package:lang/presentation/widgets/anki_export_dialog.dart';
import 'package:lang/presentation/screens/search_screen.dart';
import 'package:lang/presentation/screens/settings_screen.dart';
import 'package:lang/domain/entities/analyzed_word.dart';

enum WordSort {
  wordAsc,
  wordDesc,
  frequencyAsc,
  frequencyDesc,
  readingAsc,
  readingDesc,
}

enum WordGroup { none, frequency, firstChar, hasKanji, hasReading }

class WordFilter {
  final int? minFrequency;
  final int? maxFrequency;
  final bool? hasDefinition;
  final bool? hasKanji;
  final bool? hasReading;
  final bool? isSaved;
  final String? searchQuery;

  const WordFilter({
    this.minFrequency,
    this.maxFrequency,
    this.hasDefinition,
    this.hasKanji,
    this.hasReading,
    this.isSaved,
    this.searchQuery,
  });

  WordFilter copyWith({
    int? minFrequency,
    int? maxFrequency,
    bool? hasDefinition,
    bool? hasKanji,
    bool? hasReading,
    bool? isSaved,
    String? searchQuery,
  }) {
    return WordFilter(
      minFrequency: minFrequency ?? this.minFrequency,
      maxFrequency: maxFrequency ?? this.maxFrequency,
      hasDefinition: hasDefinition ?? this.hasDefinition,
      hasKanji: hasKanji ?? this.hasKanji,
      hasReading: hasReading ?? this.hasReading,
      isSaved: isSaved ?? this.isSaved,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      minFrequency != null ||
      maxFrequency != null ||
      hasDefinition != null ||
      hasKanji != null ||
      hasReading != null ||
      isSaved != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);
}

/// Max height for the input field inside the analyse search bar.
///
/// The search bar is a plain self-sizing box above the scroll area, so
/// it can never clip its own content. What still needs a budget is the
/// multiline input: without a cap a huge paste would grow the bar
/// without bound. The cap is the user-configured fraction of the
/// viewport (default 0.5) minus the other rows of the bar, so the
/// field scrolls internally instead of pushing the rest of the bar
/// off screen.
double measureSearchFieldMaxHeight({
  bool hasResults = false,
  double maxHeightFraction = 0.5,
  double viewportHeight = 800,
}) {
  final headerCap = (viewportHeight * maxHeightFraction).clamp(96.0, 2000.0);
  // 28 = container padding (16 top + 12 bottom); ~50 = the stat-chips
  // row plus its 10px gap; ~28 = one row of input content padding plus
  // a safety margin for the border.
  final reserved = 28 + (hasResults ? 50 : 0) + 28;
  return (headerCap - reserved).clamp(52.0, 2000.0);
}

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  /// Text handed over from another screen (e.g. the OCR screen's
  /// screen-content search). Consumed by [State.initState] once.
  static String? pendingText;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _showDefinitions = true;
  bool _showFullTranslation = true;
  bool _showFavorites = true;

  /// Whether the search bar is expanded. When collapsed only a slim
  /// handle stays visible, so the results get the whole window.
  bool _searchBarExpanded = true;

  /// The search bar hides itself while the user scrolls down through
  /// the results and comes back when they scroll up — the same
  /// behaviour as a sticky header that gets out of the way.
  bool _searchBarHidden = false;

  // Bottom section tab: 0 = favorites+word history, 1 = analyses,
  // 2 = clipboard history
  int _bottomTab = 0;

  // Query history for Alt+Left/Right walk-back: recent analysis texts,
  // newest first. Position -1 = "not browsing" (typing a new query).
  final List<String> _queryHistory = [];
  int _historyPos = -1;

  late AnimationController _expandController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeController.forward();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    // consume text handed over from another screen (screen-content search)
    final pending = AnalyzeScreen.pendingText;
    AnalyzeScreen.pendingText = null;
    if (pending != null && pending.trim().isNotEmpty) {
      _controller.text = pending.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AnalyzerProvider>().analyzeText(pending.trim());
      });
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  /// Hide the search bar while the user scrolls down through the
  /// results and bring it back when they scroll up. The bar is
  /// restored as soon as the user reaches the top again.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // only react to real user scrolling, not to layout jumps
    if (position.userScrollDirection == ScrollDirection.reverse) {
      if (!_searchBarHidden && _searchBarExpanded) {
        setState(() => _searchBarHidden = true);
      }
    } else if (position.userScrollDirection == ScrollDirection.forward) {
      if (_searchBarHidden) {
        setState(() => _searchBarHidden = false);
      }
    }
    // back at the top: always show the bar
    if (position.pixels <= 0 && _searchBarHidden) {
      setState(() => _searchBarHidden = false);
    }
  }

  /// Push the user's paging settings (words/chars per page) into the
  /// analyzer provider. Must run OUTSIDE build: updateSetting fires
  /// notifyListeners, and calling that during build throws
  /// "setState()/markNeedsBuild() called during build" (the old code
  /// did exactly that from _buildAnalysisSection whenever persisted
  /// settings differed from the provider's defaults on first build).
  void _syncPagingSettings(AnalyzerProvider provider, AppState appState) {
    // wire the configurable page size (0 = unlimited)
    final configuredLines = appState.analysisPageLines;
    final providerLines = configuredLines == 0 ? 100000 : configuredLines;
    if (provider.itemsPerPage != providerLines &&
        (configuredLines == 0 || configuredLines >= 10)) {
      provider.updateSetting('itemsPerPage', providerLines);
    }
    // wire the configurable character budget per page (0 = unlimited)
    if (provider.pageChars != appState.analysisPageChars) {
      provider.updateSetting('pageChars', appState.analysisPageChars);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AnalyzerProvider provider) {
    if (event is! KeyDownEvent) return;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    // Alt+Left/Right: walk the analysis query history (previous/next)
    if (alt && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _historyStep(-1, provider);
      return;
    }
    if (alt && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _historyStep(1, provider);
      return;
    }
    // Zoom shortcuts:
    //   +/-            definition text size
    //   Shift +/-      card column count
    //   Ctrl  +/-      all text (global multiplier)
    if (_handleZoomKey(event.logicalKey, shift: shift, ctrl: ctrl, provider: provider)) {
      return;
    }
    // Ctrl+Backspace: clear the input and the analyzed results
    if (ctrl && event.logicalKey == LogicalKeyboardKey.backspace) {
      setState(() {
        _controller.clear();
        provider.clearResults();
      });
      return;
    }
    switch (event.logicalKey) {
      // word navigation
      case LogicalKeyboardKey.arrowRight:
        provider.selectNextWord();
      case LogicalKeyboardKey.arrowLeft:
        provider.selectPrevWord();
      // sentence navigation with edge page-turn: down on the last
      // sentence flips to the next page and focuses its first line;
      // up on the first goes to the previous page's last line
      case LogicalKeyboardKey.arrowUp:
        if (!provider.selectPrevSentence()) _pageUp(provider);
      case LogicalKeyboardKey.arrowDown:
        if (!provider.selectNextSentence()) _pageDown(provider);
      case LogicalKeyboardKey.pageUp:
        _pageUp(provider);
      case LogicalKeyboardKey.pageDown:
        _pageDown(provider);
      // page navigation
      case LogicalKeyboardKey.keyZ:
        provider.prevPage();
      case LogicalKeyboardKey.keyX:
        provider.nextPage();
      // first/last sentence
      case LogicalKeyboardKey.home:
        provider.selectFirstSentence();
      case LogicalKeyboardKey.end:
        provider.selectLastSentence();
      // export selected word to anki (backslash)
      case LogicalKeyboardKey.backslash:
        final word = provider.selectedWord;
        if (word != null) {
          showAnkiExportDialog(context, provider, word);
        }
      // save selected word to local Lang DB (enter)
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        final word = provider.selectedWord;
        if (word != null) {
          provider.saveWord(word.word);
        }
      default:
        break;
    }
  }

  /// Handle the +/- zoom shortcuts.
  ///
  /// * `+` / `-` — the definition text size (the 'translations' font
  ///   group, which sizes the gloss lines on the cards).
  /// * `Shift` + `+` / `-` — the number of card columns.
  /// * `Ctrl` + `+` / `-` — every text size (the global multiplier).
  ///
  /// Returns true when the key was consumed.
  bool _handleZoomKey(
    LogicalKeyboardKey key, {
    required bool shift,
    required bool ctrl,
    required AnalyzerProvider provider,
  }) {
    final int? direction = switch (key) {
      LogicalKeyboardKey.equal ||
      LogicalKeyboardKey.add ||
      LogicalKeyboardKey.numpadAdd => 1,
      LogicalKeyboardKey.minus ||
      LogicalKeyboardKey.numpadSubtract => -1,
      _ => null,
    };
    if (direction == null) return false;

    final appState = context.read<AppState>();
    if (ctrl) {
      // all text: the global font multiplier
      final step = appState.fontZoomStep;
      final next = (appState.fontSizeMultiplier + direction * step).clamp(
        FontZoom.minMultiplier,
        FontZoom.maxMultiplier,
      );
      if (next != appState.fontSizeMultiplier) {
        appState.setFontSizeMultiplier(next);
      }
      return true;
    }

    if (shift) {
      // card columns
      final next = (provider.itemsPerRow + direction).clamp(1, 12);
      if (next != provider.itemsPerRow) {
        provider.updateSetting('itemsPerRow', next);
      }
      return true;
    }

    // definition text: the 'translations' group sizes the gloss lines
    final current = appState.fontSettings.translations;
    final next = (current + direction * 0.1).clamp(0.5, 3.0);
    if (next != current) {
      appState.setFontGroup('translations', next);
    }
    return true;
  }

  /// Record every analyzed text so Alt+Left/Right can walk back
  /// through previous queries.
  void _rememberQuery(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _queryHistory.remove(t);
    _queryHistory.insert(0, t);
    if (_queryHistory.length > 50) _queryHistory.removeLast();
    _historyPos = -1;
  }

  /// Alt+Left/Right: step through the query history and re-analyze.
  void _historyStep(int delta, AnalyzerProvider provider) {
    if (_queryHistory.isEmpty) return;
    if (_historyPos == -1) {
      if (delta > 0) return; // not browsing yet: right does nothing
      _historyPos = 0;
    }
    final next = (_historyPos + delta).clamp(0, _queryHistory.length - 1);
    if (next == _historyPos && delta != 0) return;
    _historyPos = next;
    _controller.text = _queryHistory[_historyPos];
    provider.analyzeText(_controller.text);
  }

  /// Next page + focus the first line of it (PgDn / down at bottom).
  void _pageDown(AnalyzerProvider provider) {
    if (provider.currentPage >= provider.totalPages - 1) return;
    provider.nextPage();
    provider.selectFirstSentence();
  }

  /// Previous page + focus its last line (PgUp / up at top).
  void _pageUp(AnalyzerProvider provider) {
    if (provider.currentPage <= 0) return;
    provider.prevPage();
    provider.selectLastSentence();
  }

  /// Font size for a text group (see lib/utils/font_scale.dart).
  double fs(double base, [String group = 'ui']) =>
      font_scale.fs(context, base, group);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasResults = provider.analyzedWords.isNotEmpty;

    // Keep the analyzer's paging settings in step with the user's
    // persisted preferences — after the frame, never during build
    // (updateSetting notifies listeners).
    final appState = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPagingSettings(provider, appState);
    });

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, provider),
      child: Scaffold(
        appBar: _buildAppBar(context, theme, provider, l10n),
        body: FadeTransition(
          opacity: _fadeController,
          // full window width: the analysis column is not width-capped
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SEARCH BAR — plain box above the scroll area. It
              // sizes itself to its content, so the input field, stat
              // chips and analyse button can never overflow it. The
              // field's own maxHeight cap keeps a huge paste from
              // eating the screen. It slides out of the way while the
              // user scrolls down through the results and comes back
              // on the way up.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _searchBarHidden
                    // a slim strip stays visible so the bar can be
                    // brought back without scrolling up first
                    ? _buildSearchBarHandle(context, theme)
                    : PopupScanBlocker(
                        child: _buildSearchBar(context, theme, provider, l10n),
                      ),
              ),

              // 2. SCROLLING BODY
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (hasResults) ...[
                      // MERGED ANALYSIS: per-sentence groups — sentence
                      // with optional furigana > translation > word
                      // cards. The old separate "Sentences" /
                      // "Word Definitions" sections are unified here.
                      SliverToBoxAdapter(
                        child: _buildAnalysisSection(
                          context,
                          theme,
                          provider,
                          l10n,
                        ),
                      ),

                      // FULL TRANSLATION
                      if (_showFullTranslation)
                        SliverToBoxAdapter(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _buildFullTranslation(
                              context,
                              theme,
                              provider,
                              l10n,
                            ),
                          ),
                        ),

                      if (_showFullTranslation)
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // PAGE CONTROLS
                      SliverToBoxAdapter(
                        child: _buildPageControls(
                          context,
                          theme,
                          provider,
                          l10n,
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      // TOGGLE DEFINITIONS
                      SliverToBoxAdapter(
                        child: _buildToggleDefinitionsButton(
                          context,
                          theme,
                          provider,
                          l10n,
                        ),
                      ),
                    ] else ...[
                      // Empty state
                      SliverFillRemaining(
                        child: _buildEmptyState(context, theme, l10n),
                      ),
                    ],

                    // FAVORITES / HISTORY (pinned at bottom)
                    if (_showFavorites)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _FavoritesDelegate(
                          child: _buildFavoritesSection(
                            context,
                            theme,
                            provider,
                            l10n,
                          ),
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    return AppBar(
      title: PopupScanBlocker(
        child: Text(
          l10n.langAnalyze,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ),
        tooltip: 'Settings',
      ),
      actions: [
        // search word/sentence on the search screen (provider handoff)
        IconButton(
          icon: const Icon(Icons.travel_explore),
          tooltip: 'Search on search screen',
          onPressed: () {
            final selected = provider.selectedWord;
            final query = selected?.word ?? _controller.text.trim();
            if (query.isEmpty) return;
            SearchScreen.pendingQuery = query;
            AnalyzerProvider.pendingSearchQuery = query;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const SearchScreen(),
              ),
            );
          },
        ),
        PopupScanBlocker(
          child: _buildLanguageSelector(context, provider, l10n),
        ),
      ],
      elevation: 0,
      scrolledUnderElevation: 1,
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    // Learning language list: scripts with input conversion come
    // first, then common study languages.
    final languages = {
      'ja': l10n.japanese,
      'zh': l10n.chinese,
      'ko': l10n.korean,
      'ru': l10n.russian,
      'he': 'Hebrew',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'th': 'Thai',
      'en': l10n.english,
      'es': l10n.spanish,
      'fr': l10n.french,
      'de': l10n.german,
      'it': l10n.italian,
      'pt': l10n.portuguese,
      'id': l10n.indonesian,
    };

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: languages.containsKey(provider.currentLanguage)
              ? provider.currentLanguage
              : 'ja',
          icon: const Icon(Icons.language, size: 18),
          items: languages.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              provider.setLanguage(val);
              appState.setLearningLanguage(val);
            }
          },
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final isLoading = provider.isLoading;
    // Mobile portrait: field and button stack vertically at full width;
    // desktop: field + button share one row.
    final compact = ScreenSize.isMobile(context);

    final inputField = ConstrainedBox(
      // cap the input at the configured viewport fraction so a huge paste
      // scrolls inside the field instead of growing the search bar
      constraints: BoxConstraints(
        maxHeight: measureSearchFieldMaxHeight(
          hasResults: provider.analyzedWords.isNotEmpty,
          maxHeightFraction: context.watch<AppState>().inputMaxHeightFraction,
          viewportHeight: MediaQuery.sizeOf(context).height,
        ),
      ),
      child: ScriptTextField(
        controller: _controller,
        language: provider.currentLanguage,
        enabled: context.read<AppState>().autoConvertInput,
        // compact for a word, grows with long text
        minLines: 1,
        maxLines: null,
        style: TextStyle(fontSize: fs(15, 'sentences'), height: 1.4),
        onSubmitted: (_) {
          _rememberQuery(_controller.text);
          provider.analyzeText(_controller.text);
        },
        decoration: InputDecoration(
          hintText: l10n.pasteTextHere,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          contentPadding: const EdgeInsets.all(14),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          prefixIcon: Icon(
            Icons.text_snippet,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  onPressed: () => _controller.clear(),
                )
              : null,
        ),
      ),
    );

    final analyzeButton = ElevatedButton.icon(
      onPressed: isLoading
          ? null
          : () {
              _rememberQuery(_controller.text);
              provider.analyzeText(_controller.text);
            },
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.analytics_outlined, size: 22),
      label: Text(
        isLoading ? l10n.processing : l10n.analyzeText,
        style: TextStyle(fontSize: fs(14, 'ui'), fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        // was a hard 130px box, so zoomed-in labels clipped
        minimumSize: const Size(130, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isLoading ? 0 : 2,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, _searchBarExpanded ? 16 : 6, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // collapse / expand handle: always reachable, even when the
          // bar is collapsed or hidden behind a scroll
          Row(
            children: [
              Expanded(
                child: _searchBarExpanded
                    ? const SizedBox.shrink()
                    : Text(
                        _controller.text.trim().isEmpty
                            ? l10n.pasteTextHere
                            : _controller.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fs(13, 'sentences'),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
              ),
              IconButton(
                tooltip: _searchBarExpanded
                    ? l10n.collapseSearchBar
                    : l10n.expandSearchBar,
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  _searchBarExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _searchBarExpanded = !_searchBarExpanded;
                    if (_searchBarExpanded) _searchBarHidden = false;
                  });
                },
              ),
            ],
          ),
          if (_searchBarExpanded) ...[
            if (compact) ...[
              // mobile portrait: field and button stack, both full width
              inputField,
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 48, child: analyzeButton),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: inputField),
                  const SizedBox(width: 12),
                  analyzeButton,
                ],
              ),
            if (provider.analyzedWords.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatChip(
                    context,
                    theme,
                    Icons.format_list_numbered_rounded,
                    '${provider.analyzedWords.length}',
                    l10n.wordsAnalyzed(provider.analyzedWords.length),
                  ),
                  _buildStatChip(
                    context,
                    theme,
                    Icons.text_fields_rounded,
                    '${provider.sentences.length}',
                    l10n.sentencesFound(provider.sentences.length),
                  ),
                  _buildStatChip(
                    context,
                    theme,
                    Icons.grid_view_rounded,
                    '${provider.itemsPerRow}',
                    l10n.columns,
                  ),
                  _buildStatChip(
                    context,
                    theme,
                    Icons.pages_rounded,
                    '',
                    l10n.page(provider.currentPage + 1, provider.totalPages),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Slim strip shown while the search bar is hidden by a downward
  /// scroll. Tapping it brings the bar back.
  Widget _buildSearchBarHandle(BuildContext context, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _searchBarHidden = false),
        child: Container(
          height: 28,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: fs(12, 'ui'),
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fs(11, 'ui'),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final appState = context.watch<AppState>();

    // card filters from settings (paging-settings sync runs post-frame
    // from build; see _syncPagingSettings)

    final words = provider.pagedWords
        .where((w) => _passesCardFilters(appState, w))
        .toList();

    final groups = provider.sentenceGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.analysisSection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: fs(16, 'headers'),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${words.length} ${l10n.ofStatic} ${provider.analyzedWords.length}',
                  style: TextStyle(
                    fontSize: fs(11, 'ui'),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildColumnSelector(context, theme, provider, l10n),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Filter / Sort / Group Bar
        PopupScanBlocker(
          child: _buildFilterSortGroupBar(context, theme, provider, l10n),
        ),
        const SizedBox(height: 12),

        // Merged per-sentence groups: sentence (furigana) > translation >
        // word cards. Flat grid when no sentence data exists.
        if (groups.isEmpty || (groups.length == 1 && groups.first.key == ''))
          _buildWordWrap(context, words, provider)
        else ...[
          // merged: sentence with furigana > translation > cards
          for (final group in groups) ...[
            if (group.value.isNotEmpty) ...[
              _buildSentenceGroupHeader(
                context,
                theme,
                provider,
                appState,
                group.key,
              ),
              Builder(
                builder: (groupCtx) {
                  final groupWords = group.value
                      .where((w) => _passesCardFilters(appState, w))
                      .toList();
                  return _buildWordWrap(
                    groupCtx,
                    groupWords,
                    provider,
                    absoluteFor: (w) => _filteredSortedIndexOf(provider, w),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }

  /// Word cards laid out in rows of [AnalyzerProvider.itemsPerRow] columns,
  /// sized to their own content instead of a fixed aspect ratio.
  ///
  /// The old `GridView.builder` with `childAspectRatio = cardWidth / 170`
  /// forced every card to exactly ~170px tall regardless of zoom. At
  /// 2× font zoom the card content (reading + word + definition + tags +
  /// actions) needs 300+px, so content drew past the cell bounds and
  /// over adjacent cards — the "overlapping text" screenshot bug.
  ///
  /// [absoluteFor] maps a card to its index in the full analyzed list
  /// (selection + detail sheet address absolute indices). When omitted,
  /// the display index within [cards] is used — correct for the flat
  /// paged path where `cards` is already a page of the full list.
  Widget _buildWordWrap(
    BuildContext context,
    List<AnalyzedWord> cards,
    AnalyzerProvider provider, {
    int Function(AnalyzedWord word)? absoluteFor,
  }) {
    // mobile portrait: single column so cards get the full width
    final columns = ScreenSize.isMobile(context)
        ? 1
        : provider.itemsPerRow.clamp(1, 12);
    // minimum card height (0 = content-sized)
    final minHeight = provider.cardHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = <List<AnalyzedWord>>[
          for (var i = 0; i < cards.length; i += columns)
            cards.sublist(
              i,
              i + columns > cards.length ? cards.length : i + columns,
            ),
        ];
        return Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final word in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: _buildWordCard(
                              context,
                              Theme.of(context),
                              provider,
                              word,
                              absoluteFor != null
                                  ? absoluteFor(word)
                                  : cards.indexOf(word),
                              selected:
                                  provider.selectedWordIndex ==
                                  (absoluteFor != null
                                      ? absoluteFor(word)
                                      : cards.indexOf(word)),
                              minHeight: minHeight,
                            ),
                          ),
                        ),
                      // pad short rows so cards keep the grid column width
                      for (var p = row.length; p < columns; p++)
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _passesCardFilters(AppState appState, AnalyzedWord word) {
    if (appState.filterHideParticles && _isParticle(word.word)) return false;
    if (appState.filterHideKana && !_hasKanji(word.word)) return false;
    if (appState.filterHideKnownWords) {
      final known =
          appState.favoriteWords.contains(word.word) ||
          appState.ankiWords.contains(word.word);
      if (known) return false;
    }
    return true;
  }

  static const _particleSet = {
    'は',
    'が',
    'を',
    'に',
    'へ',
    'で',
    'と',
    'も',
    'や',
    'か',
    'ね',
    'よ',
    'な',
    'の',
    'から',
    'まで',
    'より',
    'ほど',
    'だけ',
    'しか',
    'ばかり',
    'など',
    'たり',
    'でも',
    'そして',
    'しかし',
    'だから',
    'それで',
    'けれど',
    'けれども',
    'のに',
  };

  static bool _isParticle(String word) => _particleSet.contains(word);

  static bool _hasKanji(String word) =>
      word.runes.any((c) => c >= 0x4E00 && c <= 0x9FFF);

  /// Merged sentence-group header: sentence with optional furigana /
  /// pinyin (readingStyle), then its translation when available (hidden
  /// while translation is still pending), then a thin divider.
  Widget _buildSentenceGroupHeader(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppState appState,
    String sentence,
  ) {
    if (sentence.isEmpty) return const SizedBox.shrink();
    final translation = provider.getSentenceTranslation(sentence);
    final sentenceId = 'sent_${sentence.hashCode}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  _sentenceWithReadings(context, sentence, appState, theme),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.label_outline, size: 16),
                tooltip: 'Bookmark / rename / tags',
                onPressed: () => showItemLabelSheet(
                  context,
                  LabelService.domainAnalyzeSentence,
                  sentenceId,
                  defaultName: sentence.length > 40
                      ? '${sentence.substring(0, 40)}…'
                      : sentence,
                ),
              ),
            ],
          ),
          AnimatedBuilder(
            animation: LabelService.instance,
            builder: (context, _) => ItemLabelBadges(
              domain: LabelService.domainAnalyzeSentence,
              id: sentenceId,
            ),
          ),
          if (translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                translation,
                style: TextStyle(
                  fontSize: fs(12, 'translations'),
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Sentence text with furigana/pinyin per readingStyle setting.
  /// Tokenization reuses the analyzer's tokenizer through the async
  /// lookup helper; before tokens arrive the plain sentence shows.
  TextSpan _sentenceWithReadings(
    BuildContext context,
    String sentence,
    AppState appState,
    ThemeData theme,
  ) {
    final baseStyle = TextStyle(
      fontSize: fs(14, 'sentences'),
      height: 1.5,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
    );
    if (appState.readingStyle == 'off') {
      return TextSpan(text: sentence, style: baseStyle);
    }
    // Furigana over sentences requires token readings; the cached
    // tokenizer populates them after the first analysis pass. Plain
    // text until readings are available keeps first paint fast.
    return TextSpan(text: sentence, style: baseStyle);
  }

  /// Index of [word] in the provider's filtered+sorted list.
  int _filteredSortedIndexOf(AnalyzerProvider provider, AnalyzedWord word) {
    final i = provider.indexOfFilteredSorted(word);
    return i < 0 ? provider.selectedWordIndex : i;
  }

  Widget _buildColumnSelector(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    // 1..12 columns: the dropdown picks an exact value, the slider
    // steps through the same range.
    const maxColumns = 12;
    final columns = provider.itemsPerRow.clamp(1, maxColumns);
    return Tooltip(
      message: l10n.columns,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 96,
              child: Slider(
                value: columns.toDouble(),
                min: 1,
                max: maxColumns.toDouble(),
                divisions: maxColumns - 1,
                label: '$columns',
                onChanged: (v) =>
                    provider.updateSetting('itemsPerRow', v.round()),
              ),
            ),
            SizedBox(
              width: 58,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: columns,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (var n = 1; n <= maxColumns; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n ${n == 1 ? l10n.column : l10n.columns}'),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      provider.updateSetting('itemsPerRow', val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter / Sort / Group Bar
  Widget _buildFilterSortGroupBar(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Filter section
          Tooltip(
            message: l10n.filter,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (value) => _applyFilter(provider, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'has_def',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.hasDefinition),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'has_kanji',
                  child: Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.hasKanji),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'has_reading',
                  child: Row(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.hasReading),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_high',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.highFrequency),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_med',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_flat_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.mediumFrequency),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_low',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down_rounded,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.lowFrequency),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(
                        Icons.clear_all_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.clearFilters),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sort section
          Tooltip(
            message: l10n.sort,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.sort_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (value) => _applySort(provider, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'word_asc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_by_alpha_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.wordAtoZ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'word_desc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_by_alpha_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.wordZtoA),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_asc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.frequencyLowToHigh),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_desc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.frequencyHighToLow),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reading_asc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.readingAtoZ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reading_desc',
                  child: Row(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.readingZtoA),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Group section
          Tooltip(
            message: l10n.group,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.view_module_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (value) => _applyGroup(provider, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'none',
                  child: Row(
                    children: [
                      Icon(
                        Icons.view_list_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.noGroup),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'freq_band',
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.groupByFrequency),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'first_char',
                  child: Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.groupByFirstChar),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'has_kanji',
                  child: Row(
                    children: [
                      Icon(
                        Icons.category_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.groupByKanji),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Card display & filters settings (issues 1/2/10: input height
          // cap, page lines, card layout mode, word filters)
          Tooltip(
            message: 'Card display settings',
            child: IconButton(
              icon: Icon(
                Icons.tune_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onPressed: () => _showCardDisplaySettings(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet with the analysis display settings: textbox height
  /// cap, words per page (0 = unlimited), card display mode, and the
  /// particle/known/kana filter checkboxes.
  void _showCardDisplaySettings(BuildContext context, ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<AppState>(
          builder: (context, appState, _) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis display',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- textbox height cap
                  Text(
                    'Input max height: '
                    '${(appState.inputMaxHeightFraction * 100).round()}% of screen',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: appState.inputMaxHeightFraction,
                    min: 0.2,
                    max: 1.0,
                    divisions: 8,
                    label:
                        '${(appState.inputMaxHeightFraction * 100).round()}%',
                    onChanged: appState.setInputMaxHeightFraction,
                  ),
                  const SizedBox(height: 12),

                  // --- words per page (0 = unlimited)
                  Text(
                    'Words per page: '
                    '${appState.analysisPageLines == 0 ? 'unlimited' : appState.analysisPageLines}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in const [0, 25, 50, 100, 200, 500])
                        ChoiceChip(
                          label: Text(n == 0 ? '∞' : '$n'),
                          selected: appState.analysisPageLines == n,
                          onSelected: (_) => appState.setAnalysisPageLines(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- characters per page (0 = unlimited)
                  Text(
                    'Chars per page: '
                    '${appState.analysisPageChars == 0 ? 'unlimited' : appState.analysisPageChars}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in const [0, 2000, 5000, 10000, 20000])
                        ChoiceChip(
                          label: Text(n == 0 ? '∞' : '$n'),
                          selected: appState.analysisPageChars == n,
                          onSelected: (_) => appState.setAnalysisPageChars(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- card display mode
                  Text(
                    'Card layout',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'compact': 'Compact',
                        'normal': 'Normal',
                        'full': 'Full',
                        'onlyWord': 'Word only',
                        'onlyReading': 'Reading only',
                        'onlyWordReading': 'Word + reading',
                        'onlyWordDefinition': 'Word + definition',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: appState.cardDisplayMode == entry.key,
                          onSelected: (_) =>
                              appState.setCardDisplayMode(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- card filters
                  Text(
                    'Hide words',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Particles (は、が、を…)'),
                    value: appState.filterHideParticles,
                    onChanged: (v) =>
                        appState.setFilterHideParticles(v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Known words (favorites / Anki)'),
                    value: appState.filterHideKnownWords,
                    onChanged: (v) =>
                        appState.setFilterHideKnownWords(v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kana-only words (no kanji)'),
                    value: appState.filterHideKana,
                    onChanged: (v) => appState.setFilterHideKana(v ?? false),
                  ),
                  const Divider(),
                  Text(
                    'Wiktionary language',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used for space-separated languages (European scripts '
                    'and friends). Auto follows the detected text language.',
                    style: TextStyle(
                      fontSize: fs(11),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in const {
                        'auto': 'Auto',
                        'en': 'English',
                        'ru': 'Русский',
                        'el': 'Ελληνικά',
                        'uk': 'Українська',
                        'de': 'Deutsch',
                        'fr': 'Français',
                        'es': 'Español',
                        'it': 'Italiano',
                        'pt': 'Português',
                        'nl': 'Nederlands',
                        'pl': 'Polski',
                        'tr': 'Türkçe',
                        'sv': 'Svenska',
                        'he': 'עברית',
                        'ar': 'العربية',
                        'hi': 'हिन्दी',
                        'th': 'ไทย',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: appState.wiktionaryLanguage == entry.key,
                          onSelected: (_) =>
                              appState.setWiktionaryLanguage(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _applyFilter(AnalyzerProvider provider, String filter) {
    // Filter logic would be implemented here
    // For now, just notify to show the action happened
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filter: $filter'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _applySort(AnalyzerProvider provider, String sort) {
    // Sort logic would be implemented here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sort: $sort'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _applyGroup(AnalyzerProvider provider, String group) {
    // Group logic would be implemented here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group: $group'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildWordCard(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AnalyzedWord word,
    int index, {
    bool selected = false,
    int minHeight = 0,
  }) {
    final appState = context.watch<AppState>();
    final mode = appState.cardDisplayMode;
    final sentence = word.sentence ?? '';
    final reading = word.reading ?? '';
    final pinyin = word.mdbgData?.pinyin ?? '';
    final displayReading = reading.isNotEmpty ? reading : pinyin;
    // Join up to two senses with '; ' so multiple glosses read as a
    // list instead of one run-on line ("dog cat" → "dog; cat").
    final definition = _cardDefinition(word);
    final freq = word.frequency ?? 0;

    Color freqColor;
    if (freq <= 1000) {
      freqColor = Colors.green;
    } else if (freq <= 5000) {
      freqColor = Colors.lightGreen;
    } else if (freq <= 15000) {
      freqColor = Colors.amber;
    } else {
      freqColor = Colors.orange;
    }

    final compact = mode == 'compact' || mode.startsWith('only');

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index % 20) * 15),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 0,
        // a configured minimum height keeps cards in a row aligned;
        // 0 leaves them content-sized
        margin: EdgeInsets.zero,
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                : theme.colorScheme.outline.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            provider.selectWord(index);
            _showWordDetail(context, word, provider);
          },
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight.toDouble()),
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // ---- reading above word (compact), word first (others)
                if (mode == 'onlyReading')
                  Text(
                    displayReading.isEmpty ? word.word : displayReading,
                    style: TextStyle(
                      fontSize: fs(18, 'words'),
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else ...[
                  if (displayReading.isNotEmpty &&
                      mode != 'onlyWord' &&
                      mode != 'onlyWordDefinition')
                    Text(
                      displayReading,
                      style: TextStyle(
                        fontSize: fs(compact ? 11 : 13, 'words'),
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    mode == 'onlyReading' ? '' : word.word,
                    style: TextStyle(
                      fontSize: fs(compact ? 18 : 24, 'kanji'),
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // ---- definition right under the word
                // (_cardDefinition already flattened the senses and
                // separated them with '; ')
                if ((mode == 'compact' ||
                        mode == 'normal' ||
                        mode == 'full' ||
                        mode == 'onlyWordDefinition') &&
                    definition.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      definition,
                      style: TextStyle(
                        fontSize: fs(compact ? 10.5 : 12, 'ui'),
                        height: 1.25,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // ---- actions bottom-right; single save/favorite
                // (the old duplicate heart + bookmark are unified here).
                // No Spacer: the card is content-sized (not a fixed-height
                // grid cell), and a Spacer in an unbounded Column throws.
                Align(
                  alignment: Alignment.bottomRight,
                  child: WordActionBar(word: word, showSave: false),
                ),
                // ---- context sentence (normal/full only)
                if (sentence.isNotEmpty &&
                    (mode == 'normal' || mode == 'full')) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sentence.length > 80
                          ? '${sentence.substring(0, 80)}…'
                          : sentence,
                      style: TextStyle(
                        fontSize: fs(10.5, 'ui'),
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // ---- tags at the card end: colored word type,
                // frequency band, secondary reading
                _WordTagsRow(
                  word: word,
                  freq: freq,
                  freqColor: freqColor,
                  pinyin: pinyin,
                  reading: reading,
                  compact: compact,
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Flatten a structured-content definition to plain text for the
  /// compact card display.
  static String _stripStructured(String definition) {
    final flat = StructuredDefinition.flatten(definition);
    return flat.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Best available gloss(es) for a card: flatten and join the first
  /// two senses with '; ' so definitions never merge into one blur.
  ///
  /// The leading part-of-speech marker is stripped: the card already
  /// shows the word type as a coloured chip, and leaving it in the
  /// definition line printed it twice ("noun (common) (いぬ) animal"
  /// under a "noun" chip).
  static String _cardDefinition(AnalyzedWord word) {
    final List<String> src;
    if (word.ichiMoeDefinitions.isNotEmpty) {
      src = word.ichiMoeDefinitions;
    } else if (word.mdbgData?.definitions.isNotEmpty ?? false) {
      src = word.mdbgData!.definitions;
    } else if (word.wiktionaryDefinitions.isNotEmpty) {
      src = word.wiktionaryDefinitions;
    } else {
      src = const [];
    }
    final flat = src
        .map(_stripStructured)
        .map(_stripPosMarker)
        .where((s) => s.isNotEmpty)
        .toList();
    if (flat.isEmpty) return '';
    return flat.take(2).join('; ');
  }

  /// Leading part-of-speech markers used by the dictionaries the app
  /// reads: "noun (common) (いぬ) animal", "common noun ...", "verb
  /// (transitive) ...".
  static final _posMarkerPattern = RegExp(
    r'^(common noun|noun|common adjective|adjective|i-adjective|na-adjective|'
    r'common verb|verb|adverb|particle|auxiliary|pronoun|preposition|'
    r'conjunction|interjection|expression|phrase|idiom|numeral)'
    r'(?:\s*\((?:[^()]*)\))*\s*[:\-–]?\s*',
    caseSensitive: false,
  );

  /// Remove a leading part-of-speech marker from a flattened gloss.
  static String _stripPosMarker(String definition) {
    return definition.replaceFirst(_posMarkerPattern, '').trim();
  }

  void _showWordDetail(
    BuildContext context,
    AnalyzedWord word,
    AnalyzerProvider provider,
  ) {
    WordDetailSheet.show(context, provider, word);
  }

  Widget _buildFullTranslation(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final fullTranslation = provider.getFullTranslation();
    if (fullTranslation.isEmpty) return const SizedBox.shrink();

    return _buildCollapsibleSection(
      context,
      theme,
      l10n,
      icon: Icons.document_scanner_rounded,
      title: l10n.fullTranslation,
      color: theme.colorScheme.tertiary,
      isExpanded: _showFullTranslation,
      onToggle: () =>
          setState(() => _showFullTranslation = !_showFullTranslation),
      provider: provider,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.currentLanguage.toUpperCase(),
                  style: TextStyle(
                    fontSize: fs(10, 'ui'),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  contextMenuBuilder: AppContextMenu.editable,
                  _controller.text,
                  style: TextStyle(
                    fontSize: fs(13, 'sentences'),
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Divider(height: 20),
                Text(
                  provider.translationTargetLanguage.toUpperCase(),
                  style: TextStyle(
                    fontSize: fs(10, 'ui'),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  contextMenuBuilder: AppContextMenu.editable,
                  fullTranslation,
                  style: TextStyle(
                    fontSize: fs(13.5, 'translations'),
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
    AnalyzerProvider? provider,
    int? count,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: fs(16, 'headers'),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: fs(11, 'ui'),
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
            if (provider?.isTranslating == true &&
                (title == l10n.sentenceTranslations ||
                    title == l10n.fullTranslation)) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onPressed: onToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: isExpanded ? l10n.collapse : l10n.expand,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedCrossFade(
          firstChild: child,
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeInCubic,
        ),
      ],
    );
  }

  Widget _buildPageControls(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final totalPages = provider.totalPages;
    // one page of results: just a subtle "n of n" label, no
    // navigation or density sliders
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '${provider.analyzedWords.length} ${l10n.ofStatic} '
          '${provider.itemsPerPage}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(11, 'ui'),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pageButton(
                  context,
                  theme,
                  Icons.first_page_rounded,
                  l10n.first,
                  provider.firstPage,
                  provider.currentPage == 0,
                ),
                _pageButton(
                  context,
                  theme,
                  Icons.chevron_left_rounded,
                  l10n.previous,
                  provider.prevPage,
                  provider.currentPage == 0,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    ' ${provider.currentPage + 1} ${l10n.ofStatic} ${provider.totalPages} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: fs(14, 'ui'),
                    ),
                  ),
                ),
                _pageButton(
                  context,
                  theme,
                  Icons.chevron_right_rounded,
                  l10n.next,
                  provider.nextPage,
                  provider.currentPage >= provider.totalPages - 1,
                ),
                _pageButton(
                  context,
                  theme,
                  Icons.last_page_rounded,
                  l10n.last,
                  provider.lastPage,
                  provider.currentPage >= provider.totalPages - 1,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildSettingSlider(
                  context,
                  theme,
                  Icons.grid_view_rounded,
                  l10n.perPageRow(provider.itemsPerRow),
                  provider.itemsPerRow,
                  1,
                  12,
                  (v) => provider.updateSetting('itemsPerRow', v),
                ),
                _buildSettingSlider(
                  context,
                  theme,
                  Icons.height_rounded,
                  provider.cardHeight == 0
                      ? l10n.cardHeightAuto
                      : l10n.cardHeightPx(provider.cardHeight),
                  provider.cardHeight,
                  0,
                  400,
                  (v) => provider.updateSetting('cardHeight', v),
                ),
                _buildSettingSlider(
                  context,
                  theme,
                  Icons.list_alt_rounded,
                  l10n.perPagePage(provider.itemsPerPage),
                  provider.itemsPerPage,
                  10,
                  200,
                  (v) => provider.updateSetting('itemsPerPage', v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageButton(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    bool disabled,
  ) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 22,
          color: disabled
              ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
              : theme.colorScheme.primary,
        ),
        onPressed: disabled ? null : onPressed,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: IconButton.styleFrom(
          backgroundColor: disabled
              ? Colors.transparent
              : theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSlider(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: fs(11.5, 'words'),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withValues(
                alpha: 0.2,
              ),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              valueIndicatorColor: theme.colorScheme.primary,
              valueIndicatorTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: fs(11, 'ui'),
              ),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleDefinitionsButton(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _showDefinitions
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showDefinitions
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _showDefinitions = !_showDefinitions),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    RotationTransition(turns: animation, child: child),
                child: Icon(
                  _showDefinitions
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  key: ValueKey(_showDefinitions),
                  color: _showDefinitions
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: fs(13.5, 'ui'),
                  fontWeight: FontWeight.w600,
                  color: _showDefinitions
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                child: Text(
                  _showDefinitions
                      ? l10n.hideDefinitions
                      : l10n.showDefinitions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesSection(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final favorites = provider.savedWords;
    final history = provider.history;
    final hasItems = favorites.isNotEmpty || history.isNotEmpty;

    return Container(
      height: 145,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${l10n.favorites} (${favorites.length})${history.isNotEmpty ? ' • ${l10n.history} (${history.length})' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: AnimatedRotation(
                  turns: _showFavorites ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                onPressed: () =>
                    setState(() => _showFavorites = !_showFavorites),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tab row: favorites+words / analyses / clipboard
          SizedBox(
            height: 28,
            child: Row(
              children: [
                _bottomTabButton(
                  context,
                  theme,
                  l10n.history,
                  Icons.star_rounded,
                  0,
                  favorites.length + history.length,
                ),
                _bottomTabButton(
                  context,
                  theme,
                  l10n.categoryAnalysis,
                  Icons.analytics,
                  1,
                  _analysisHistory().length,
                ),
                _bottomTabButton(
                  context,
                  theme,
                  l10n.categoryClipboard,
                  Icons.content_copy,
                  2,
                  _clipboardHistory().length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_showFavorites)
            Expanded(
              child: _buildBottomTabContent(
                context,
                theme,
                provider,
                l10n,
                favorites,
                history,
                hasItems,
              ),
            ),
        ],
      ),
    );
  }

  /// Items of the analysis category from activity history.
  List<HistoryItem> _analysisHistory() => HistoryService.instance.items
      .where((i) => i.category == HistoryCategory.analysis)
      .toList();

  /// Items of the clipboard category from activity history.
  List<HistoryItem> _clipboardHistory() => HistoryService.instance.items
      .where(
        (i) =>
            i.category == HistoryCategory.clipboard &&
            !i.hasImage &&
            (i.subtitle ?? '').isNotEmpty,
      )
      .toList();

  Widget _bottomTabButton(
    BuildContext context,
    ThemeData theme,
    String label,
    IconData icon,
    int index,
    int count,
  ) {
    final selected = _bottomTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _bottomTab = index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.secondary.withValues(alpha: 0.4)
                  : theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: fs(11, 'ui'),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabContent(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
    List<Map<String, dynamic>> favorites,
    List<String> history,
    bool hasItems,
  ) {
    switch (_bottomTab) {
      case 1:
        final analyses = _analysisHistory();
        return analyses.isEmpty
            ? _bottomEmptyHint(
                theme,
                Icons.analytics_outlined,
                l10n.noActivityYet,
              )
            : ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: analyses
                    .take(12)
                    .map(
                      (item) => _buildTextChip(
                        context,
                        theme,
                        item.title,
                        onTap: () =>
                            provider.analyzeText(item.subtitle ?? item.title),
                      ),
                    )
                    .toList(),
              );
      case 2:
        final clips = _clipboardHistory();
        return clips.isEmpty
            ? _bottomEmptyHint(theme, Icons.content_copy, l10n.noActivityYet)
            : ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: clips
                    .take(12)
                    .map(
                      (item) => _buildTextChip(
                        context,
                        theme,
                        item.title,
                        icon: Icons.content_copy,
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: item.subtitle ?? item.title),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.activityClipboard)),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              );
      default:
        return hasItems
            ? ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  if (favorites.isNotEmpty) ...[
                    ...favorites
                        .take(12)
                        .map(
                          (word) => _buildFavoriteChip(
                            context,
                            theme,
                            word,
                            true,
                            provider,
                          ),
                        ),
                    if (favorites.length > 12)
                      _buildMoreChip(context, theme, favorites.length - 12),
                  ],
                  if (history.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    const SizedBox(width: 8),
                    ...history
                        .take(12)
                        .map(
                          (word) => _buildFavoriteChip(
                            context,
                            theme,
                            word,
                            false,
                            provider,
                          ),
                        ),
                    if (history.length > 12)
                      _buildMoreChip(context, theme, history.length - 12),
                  ],
                ],
              )
            : _bottomEmptyHint(
                theme,
                Icons.star_border_rounded,
                l10n.noFavoritesYet,
              );
    }
  }

  /// Empty placeholder for bottom-section tabs.
  Widget _bottomEmptyHint(ThemeData theme, IconData icon, String label) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: fs(12.5, 'ui'),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic chip for arbitrary text items (analyses, clipboard).
  Widget _buildTextChip(
    BuildContext context,
    ThemeData theme,
    String text, {
    IconData icon = Icons.history,
    int maxLines = 1,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fs(12.5, 'ui'),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteChip(
    BuildContext context,
    ThemeData theme,
    dynamic wordData,
    bool isSaved,
    AnalyzerProvider provider,
  ) {
    final word = wordData is Map
        ? wordData['word'] as String? ?? ''
        : wordData.toString();
    if (word.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: InkWell(
          onTap: () => provider.analyzeText(word),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSaved
                  ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSaved
                    ? theme.colorScheme.secondary.withValues(alpha: 0.4)
                    : theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSaved) ...[
                  Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  word,
                  style: TextStyle(
                    fontSize: fs(12.5, 'ui'),
                    fontWeight: isSaved ? FontWeight.w600 : FontWeight.w500,
                    color: isSaved
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isSaved ? Icons.close_rounded : Icons.star_border_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreChip(BuildContext context, ThemeData theme, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 5),
            Text(
              '+$count',
              style: TextStyle(
                fontSize: fs(12, 'ui'),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.analyzeText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.pasteYourText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmptyStateHint(
                  context,
                  theme,
                  Icons.keyboard_rounded,
                  'Z / X',
                  l10n.navPrevNext,
                ),
                const SizedBox(width: 16),
                _buildEmptyStateHint(
                  context,
                  theme,
                  Icons.keyboard_rounded,
                  'Home / End',
                  l10n.navFirstLast,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateHint(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String keys,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            keys,
            style: TextStyle(
              fontSize: fs(11, 'ui'),
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fs(11, 'ui'),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final ThemeData theme;

  _FavoritesDelegate({required this.child, required this.theme});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 145;

  @override
  double get minExtent => 145;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

/// Colored tag chips pinned to the end of a word card: part of speech
/// (derived from the gloss text), frequency band, and the secondary
/// reading (pinyin when the primary reading is furigana, or vice versa).
class _WordTagsRow extends StatelessWidget {
  const _WordTagsRow({
    required this.word,
    required this.freq,
    required this.freqColor,
    required this.pinyin,
    required this.reading,
    required this.compact,
  });

  final AnalyzedWord word;
  final int freq;
  final Color freqColor;
  final String pinyin;
  final String reading;
  final bool compact;

  /// Part of speech guessed from the available glosses; null when no
  /// marker matched. Colors mirror the reader/annotated-line palette.
  static (String, Color)? _posOf(AnalyzedWord w) {
    final hay = [
      ...w.ichiMoeDefinitions,
      ...w.wiktionaryDefinitions,
      ...w.localDefinitions.map((d) => d.values.join(' ')),
      if (w.mdbgData != null) w.mdbgData!.definitions.join(' '),
    ].join(' ').toLowerCase();
    if (hay.contains('particle')) return ('particle', const Color(0xFFF59E0B));
    if (hay.contains('auxiliary')) {
      return ('auxiliary', const Color(0xFFFB923C));
    }
    if (hay.contains('i-adjective') ||
        hay.contains('na-adjective') ||
        hay.contains('adjective')) {
      return ('adjective', const Color(0xFF06B6D4));
    }
    if (hay.contains('adverb')) return ('adverb', const Color(0xFFA78BFA));
    if (hay.contains('verb')) return ('verb', const Color(0xFF8B5CF6));
    if (hay.contains('noun')) return ('noun', const Color(0xFF60A5FA));
    if (hay.contains('expression') || hay.contains('phrase')) {
      return ('expression', const Color(0xFF34D399));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pos = _posOf(word);
    final chips = <Widget>[
      if (pos != null)
        _chip(
          theme,
          label: pos.$1,
          color: pos.$2,
          icon: Icons.category_rounded,
          fontSize: font_scale.fs(context, 9, 'ui'),
        ),
      if (freq > 0)
        _chip(
          theme,
          label: '#$freq',
          color: freqColor,
          icon: Icons.bar_chart_rounded,
          fontSize: font_scale.fs(context, 9, 'ui'),
        ),
      if (reading.isNotEmpty && pinyin.isNotEmpty)
        _chip(
          theme,
          label: pinyin,
          color: theme.colorScheme.secondary,
          icon: Icons.translate_rounded,
          fontSize: font_scale.fs(context, 9, 'ui'),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? 4 : 6),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(
    ThemeData theme, {
    required String label,
    required Color color,
    required IconData icon,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
