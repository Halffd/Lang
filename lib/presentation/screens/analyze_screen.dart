import 'package:flutter/material.dart';
import 'package:lang/presentation/widgets/word_action_bar.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/label_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart' as font_scale;

import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/domain/entities/app_state.dart';
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

  // Bottom section tab: 0 = favorites+word history, 1 = analyses,
  // 2 = clipboard history
  int _bottomTab = 0;

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
  }

  void _onTextChanged() {
    setState(() {});
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
              // eating the screen.
              _buildSearchBar(context, theme, provider, l10n),

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
      title: Text(
        l10n.langAnalyze,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
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
        _buildLanguageSelector(context, provider, l10n),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  // cap the input at the configured viewport fraction so
                  // a huge paste scrolls inside the field instead of
                  // growing the search bar without bound
                  constraints: BoxConstraints(
                    maxHeight: measureSearchFieldMaxHeight(
                      hasResults: provider.analyzedWords.isNotEmpty,
                      maxHeightFraction: context
                          .watch<AppState>()
                          .inputMaxHeightFraction,
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
                    style: TextStyle(
                      fontSize: fs(15, 'sentences'),
                      height: 1.4,
                    ),
                    onSubmitted: (_) => provider.analyzeText(_controller.text),
                    decoration: InputDecoration(
                      hintText: l10n.pasteTextHere,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.text_snippet,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              onPressed: () => _controller.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => provider.analyzeText(_controller.text),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.analytics_outlined, size: 22),
                label: Text(
                  isLoading ? l10n.processing : l10n.analyzeText,
                  style: TextStyle(
                    fontSize: fs(14, 'ui'),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  // was a hard 130px box, so zoomed-in labels clipped
                  minimumSize: const Size(130, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isLoading ? 0 : 2,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
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

    final pageStart = provider.currentPage * provider.itemsPerPage;
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
        _buildFilterSortGroupBar(context, theme, provider, l10n),
        const SizedBox(height: 12),

        // Merged per-sentence groups: sentence (furigana) > translation >
        // word cards. Flat grid when no sentence data exists.
        if (groups.isEmpty || (groups.length == 1 && groups.first.key == ''))
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = provider.itemsPerRow.clamp(1, 5);
              final cardWidth =
                  (constraints.maxWidth - (crossAxisCount - 1) * 10) /
                  crossAxisCount;
              final childAspectRatio = cardWidth / 170;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  final absolute = pageStart + index;
                  final selected = provider.selectedWordIndex == absolute;
                  return _buildWordCard(
                    context,
                    theme,
                    provider,
                    word,
                    absolute,
                    selected: selected,
                  );
                },
              );
            },
          )
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = provider.itemsPerRow.clamp(1, 5);
                  final cardWidth =
                      (constraints.maxWidth - (crossAxisCount - 1) * 10) /
                      crossAxisCount;
                  final childAspectRatio = cardWidth / 170;

                  final groupWords = group.value
                      .where((w) => _passesCardFilters(appState, w))
                      .toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: groupWords.length,
                    itemBuilder: (context, index) {
                      final word = groupWords[index];
                      final absolute = _filteredSortedIndexOf(provider, word);
                      final selected = provider.selectedWordIndex == absolute;
                      return _buildWordCard(
                        context,
                        theme,
                        provider,
                        word,
                        absolute,
                        selected: selected,
                      );
                    },
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

  /// Card filter checkboxes (issue 10): hide particles / known words /
  /// kana-only words.
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
    return Tooltip(
      message: l10n.columns,
      child: PopupMenuButton<int>(
        initialValue: provider.itemsPerRow,
        onSelected: (val) => provider.updateSetting('itemsPerRow', val),
        itemBuilder: (context) => List.generate(5, (i) => i + 1)
            .map(
              (n) => PopupMenuItem(
                value: n,
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Text('$n ${n == 1 ? l10n.column : l10n.columns}'),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
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
                Icons.grid_view_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '${provider.itemsPerRow} ${l10n.columns}',
                style: TextStyle(
                  fontSize: fs(12, 'ui'),
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
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
  }) {
    final appState = context.watch<AppState>();
    final mode = appState.cardDisplayMode;
    final sentence = word.sentence ?? '';
    final reading = word.reading ?? '';
    final pinyin = word.mdbgData?.pinyin ?? '';
    final displayReading = reading.isNotEmpty ? reading : pinyin;
    final definition = word.ichiMoeDefinitions.isNotEmpty
        ? word.ichiMoeDefinitions.first
        : (word.mdbgData?.definitions.isNotEmpty ?? false
              ? word.mdbgData!.definitions.first
              : (word.wiktionaryDefinitions.isNotEmpty
                    ? word.wiktionaryDefinitions.first
                    : ''));
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
                if ((mode == 'compact' ||
                        mode == 'normal' ||
                        mode == 'full' ||
                        mode == 'onlyWordDefinition') &&
                    definition.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _stripStructured(definition),
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
                // ---- small tags row (compact/normal/full)
                if (mode != 'onlyWord' &&
                    mode != 'onlyReading' &&
                    mode != 'onlyWordReading' &&
                    mode != 'onlyWordDefinition') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (freq > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: freqColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '$freq',
                            style: TextStyle(
                              fontSize: fs(8.5, 'ui'),
                              fontWeight: FontWeight.bold,
                              color: freqColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          [
                            if (reading.isNotEmpty && pinyin.isNotEmpty)
                              pinyin, // secondary reading shown as small tag
                          ].join(),
                          style: TextStyle(
                            fontSize: fs(8.5, 'ui'),
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                // ---- actions pinned bottom-right; single save/favorite
                // (the old duplicate heart + bookmark are unified here)
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
              ],
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
                  5,
                  (v) => provider.updateSetting('itemsPerRow', v),
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
