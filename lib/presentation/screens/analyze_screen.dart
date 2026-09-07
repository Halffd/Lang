import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';
import 'package:lang/presentation/widgets/script_text_field.dart';
import 'package:lang/presentation/widgets/anki_export_dialog.dart';
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
  bool _showSentenceTranslations = true;
  bool _showFullTranslation = true;
  bool _showFavorites = true;

  // Filter state - using analyzer_provider types
  final WordFilter _wordFilter = WordFilter();
  final WordSortBy _sortBy = WordSortBy.frequency;
  final bool _sortAscending = false;
  final WordGroupBy _groupBy = WordGroupBy.none;

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
      // sentence navigation
      case LogicalKeyboardKey.arrowUp:
        provider.selectPrevSentence();
      case LogicalKeyboardKey.arrowDown:
        provider.selectNextSentence();
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasResults = provider.analyzedWords.isNotEmpty;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, provider),
      child: Scaffold(
        appBar: _buildAppBar(context, theme, provider, l10n),
        body: FadeTransition(
          opacity: _fadeController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. SEARCH BAR (pinned)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(
                  child: _buildSearchBar(context, theme, provider, l10n),
                  theme: theme,
                ),
              ),

              if (hasResults) ...[
                // 2. FULL SENTENCES (above) - one entry per sentence
                SliverToBoxAdapter(
                  child: _buildSentenceListSection(
                    context,
                    theme,
                    provider,
                    l10n,
                  ),
                ),

                if (_showSentenceTranslations)
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 3. WORD DEFINITION CARDS (below, grouped per sentence)
                SliverToBoxAdapter(
                  child: _buildWordCardsSection(context, theme, provider, l10n),
                ),

                // 4. FULL TRANSLATION
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

                // 5. PAGE CONTROLS
                SliverToBoxAdapter(
                  child: _buildPageControls(context, theme, provider, l10n),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // 6. TOGGLE DEFINITIONS
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

              // 7. FAVORITES / HISTORY (pinned at bottom)
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
      actions: [_buildLanguageSelector(context, provider, l10n)],
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
                child: ScriptTextField(
                  controller: _controller,
                  language: provider.currentLanguage,
                  enabled: context.read<AppState>().autoConvertJapanese,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 15, height: 1.4),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                height: 48,
                child: ElevatedButton.icon(
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isLoading ? 0 : 2,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-sentence list shown above word cards. Each sentence row
  /// highlights when selected and shows its word count.
  Widget _buildSentenceListSection(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final sentences = provider.sentenceList;
    if (sentences.isEmpty) return const SizedBox.shrink();

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
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notes_rounded,
                  size: 20,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${l10n.sentences} (${sentences.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...sentences.asMap().entries.map((entry) {
          final idx = entry.key;
          final sentence = entry.value;
          final isSelected = provider.selectedSentenceIndex == idx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => provider.selectSentence(idx),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.6)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        sentence,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: isSelected ? 1 : 0.85,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildWordCardsSection(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final words = provider.pagedWords;
    if (words.isEmpty) return const SizedBox.shrink();

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
                  '${l10n.wordDefinitions} (${words.length} of ${provider.analyzedWords.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildColumnSelector(context, theme, provider, l10n),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Filter / Sort / Group Bar
        _buildFilterSortGroupBar(context, theme, provider, l10n),
        const SizedBox(height: 12),

        // Word cards grouped by sentence. When no sentence data
        // exists, fall back to a flat grid.
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
                    context, theme, provider, word, absolute,
                    selected: selected,
                  );
                },
              );
            },
          )
        else ...[
          // per-sentence word groups
          for (final group in groups) ...[
            if (group.value.isNotEmpty) ...[
              if (group.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          group.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Text(
                        '${group.value.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: group.value.length,
                    itemBuilder: (context, index) {
                      final word = group.value[index];
                      final absolute = _filteredSortedIndexOf(
                          provider, group.value[index]);
                      final selected =
                          provider.selectedWordIndex == absolute;
                      return _buildWordCard(
                        context, theme, provider, word, absolute,
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
    return PopupMenuButton<int>(
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
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
        ],
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
    final isSaved = provider.savedWords.any((w) => w['word'] == word.word);
    final sentence = word.sentence ?? '';
    final reading = word.reading ?? '';
    final pinyin = word.mdbgData?.pinyin ?? '';
    final hasDefinition =
        word.ichiMoeDefinitions.isNotEmpty ||
        (word.mdbgData?.definitions.isNotEmpty ?? false) ||
        reading.isNotEmpty ||
        pinyin.isNotEmpty;
    final freq = word.frequency ?? 0;

    Color freqColor;
    if (freq <= 1000) {
      freqColor = Colors.green;
    } else if (freq <= 5000)
      freqColor = Colors.lightGreen;
    else if (freq <= 15000)
      freqColor = Colors.amber;
    else
      freqColor = Colors.orange;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + index * 30),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 0,
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            word.word,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (reading.isNotEmpty || pinyin.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              reading.isNotEmpty ? reading : pinyin,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            size: 20,
                            color: isSaved
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                          ),
                          onPressed: () => isSaved
                              ? provider.removeSavedWord(word.word)
                              : provider.saveWord(word.word),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: isSaved
                              ? AppLocalizations.of(context)!.removeFromFavorites
                              : AppLocalizations.of(context)!.addToFavorites,
                        ),
                        if (freq > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: freqColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$freq',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: freqColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_showDefinitions && hasDefinition) ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        word.ichiMoeDefinitions.isNotEmpty
                            ? word.ichiMoeDefinitions.take(3).join('; ')
                            : (word.mdbgData?.definitions.isNotEmpty ?? false
                                  ? word.mdbgData!.definitions
                                        .take(3)
                                        .join('; ')
                                  : (reading.isNotEmpty ? reading : pinyin)),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        maxLines: 7,
                      ),
                    ),
                  ),
                ] else if (!_showDefinitions) ...[
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.definitionsHidden,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
                if (sentence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sentence.length > 80
                                ? '${sentence.substring(0, 80)}…'
                                : sentence,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  void _showWordDetail(
    BuildContext context,
    AnalyzedWord word,
    AnalyzerProvider provider,
  ) {
    WordDetailSheet.show(context, provider, word);
  }

  Widget _buildSentenceTranslations(
    BuildContext context,
    ThemeData theme,
    AnalyzerProvider provider,
    AppLocalizations l10n,
  ) {
    final sentenceList = provider.sentences.values.toList();
    if (sentenceList.isEmpty) return const SizedBox.shrink();

    return _buildCollapsibleSection(
      context,
      theme,
      l10n,
      icon: Icons.translate_rounded,
      title: l10n.sentenceTranslations,
      color: theme.colorScheme.secondary,
      isExpanded: _showSentenceTranslations,
      onToggle: () => setState(
        () => _showSentenceTranslations = !_showSentenceTranslations,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sentenceList.length.clamp(0, 15),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sentence = sentenceList[index];
          final translation = provider.getSentenceTranslation(sentence);
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + index * 50),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 15 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sentence,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (translation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                translation,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.translationUnavailable,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
            child: SelectableText(
              fullTranslation,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
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
              ),
            ),
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
                      fontSize: 14,
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
                  fontSize: 11.5,
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
                fontSize: 11,
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
                  fontSize: 13.5,
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
      height: 130,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          const SizedBox(height: 10),
          if (_showFavorites)
            Expanded(
              child: hasItems
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
                            _buildMoreChip(
                              context,
                              theme,
                              favorites.length - 12,
                            ),
                        ],
                        if (history.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 24,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.2,
                            ),
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
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_border_rounded,
                            size: 32,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.noFavoritesYet,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.saveWordsToSeeThemHere,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.25,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
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
                    fontSize: 12.5,
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
                fontSize: 12,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final ThemeData theme;

  _SearchBarDelegate({required this.child, required this.theme});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 180;

  @override
  double get minExtent => 180;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
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
      false;
}
