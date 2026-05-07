import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../providers/analyzer_provider.dart';
import '../widgets/word_detail_sheet.dart';
import 'settings_screen.dart';
import '../../utils/pinyin_util.dart';
import '../../domain/entities/analyzed_word.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AnalyzerProvider provider) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyZ:
        provider.prevPage();
      case LogicalKeyboardKey.keyX:
        provider.nextPage();
      case LogicalKeyboardKey.home:
        provider.firstPage();
      case LogicalKeyboardKey.end:
        provider.lastPage();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, provider),
      child: Scaffold(
        appBar: _buildAppBar(context, theme, provider, l10n),
        body: _buildBody(context, theme, provider, l10n),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    return AppBar(
      title: Text(l10n.langAnalyze, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      leading: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
      ),
      actions: [
        _buildLanguageSelector(context, provider, l10n),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context, AnalyzerProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final languages = {
      'ja': l10n.japanese,
      'zh': l10n.chinese,
      'en': l10n.english,
      'es': l10n.spanish,
      'fr': l10n.french,
      'de': l10n.german,
      'ko': l10n.korean,
      'ru': l10n.russian,
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
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.currentLanguage,
          icon: const Icon(Icons.language, size: 18),
          items: languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (val) {
            if (val != null) provider.setLanguage(val);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildTextInput(context, theme, provider),
          const SizedBox(height: 16),
          _buildAnalyzeButton(context, theme, provider, l10n),
          if (provider.isLoading) _buildLoadingIndicator(),
          if (provider.pagedWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildControls(context, theme, provider, l10n),
          ],
          const SizedBox(height: 8),
          Expanded(child: _buildResults(context, theme, provider, l10n)),
        ],
      ),
    );
  }

  Widget _buildTextInput(BuildContext context, ThemeData theme, AnalyzerProvider provider) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        TextField(
          controller: _controller,
          maxLines: 6,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.pasteTextHere,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, child) {
            return _controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => _controller.clear())
              : const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: provider.isLoading ? null : () => provider.analyzeText(_controller.text),
        icon: provider.isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.analytics),
        label: Text(
          provider.isLoading ? l10n.processing : l10n.analyzeText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(top: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        child: LinearProgressIndicator(minHeight: 6),
      ),
    );
  }

  Widget _buildControls(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    return Column(
      children: [
        _buildSliderRow(
          context, theme, l10n,
          icon: Icons.grid_view,
          label: l10n.perPageRow(provider.itemsPerRow),
          value: provider.itemsPerRow.toDouble(),
          min: 1, max: 5, divisions: 4,
          onChanged: (val) => provider.updateSetting('itemsPerRow', val.toInt()),
        ),
        _buildSliderRow(
          context, theme, l10n,
          icon: Icons.list,
          label: l10n.perPagePage(provider.itemsPerPage),
          value: provider.itemsPerPage.toDouble(),
          min: 10, max: 200, divisions: 19,
          onChanged: (val) => provider.updateSetting('itemsPerPage', val.toInt()),
        ),
        _buildPaginationRow(context, theme, provider, l10n),
      ],
    );
  }

  Widget _buildSliderRow(BuildContext context, ThemeData theme, AppLocalizations l10n, {
    required IconData icon,
    required String label,
    required double value,
    required double min, required double max, required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPaginationRow(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: provider.firstPage, icon: const Icon(Icons.first_page)),
          IconButton(onPressed: provider.prevPage, icon: const Icon(Icons.chevron_left)),
          Text(l10n.pageOf(provider.currentPage + 1, provider.totalPages)),
          IconButton(onPressed: provider.nextPage, icon: const Icon(Icons.chevron_right)),
          IconButton(onPressed: provider.lastPage, icon: const Icon(Icons.last_page)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, ThemeData theme, AnalyzerProvider provider, AppLocalizations l10n) {
    if (provider.pagedWords.isEmpty && !provider.isLoading) {
      return _buildEmptyState(l10n);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth / provider.itemsPerRow) - 8;
        final pagedWords = provider.pagedWords;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pagedWords.map((word) => _WordCard(
              word: word,
              itemWidth: itemWidth,
              provider: provider,
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(l10n.noResultsYet, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final AnalyzedWord word;
  final double itemWidth;
  final AnalyzerProvider provider;

  const _WordCard({required this.word, required this.itemWidth, required this.provider});

  Color _freqColor(int freq) {
    if (freq <= 1000) return Colors.greenAccent;
    if (freq <= 5000) return Colors.lightGreenAccent;
    if (freq <= 15000) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final freq = word.frequency;
    final freqColor = _freqColor(freq ?? 0);

    return SizedBox(
      width: itemWidth,
      child: Card(
        child: InkWell(
          onTap: () => WordDetailSheet.show(context, provider, word),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                          if (_showReading) _buildReading(),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => provider.playAudio(word.word),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: freqColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        freq?.toString() ?? '?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: freqColor),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        provider.saveWord(word.word);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.savedWord(word.word)), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _showReading {
    final reading = word.reading;
    final wordText = word.word;
    if (wordText.isEmpty) return false;
    final isZh = provider.currentLanguage == 'zh';
    if (isZh && reading != null && reading.isNotEmpty && reading != wordText) return true;
    if (isZh && PinyinUtil.isChinese(wordText)) return PinyinUtil.getPinyin(wordText) != null;
    return false;
  }

  Widget _buildReading() {
    final reading = word.reading;
    final wordText = word.word;
    final isZh = provider.currentLanguage == 'zh';
    String? text;
    if (isZh && reading != null && reading.isNotEmpty && reading != wordText) {
      text = reading;
    } else if (isZh && PinyinUtil.isChinese(wordText)) {
      text = PinyinUtil.getPinyin(wordText);
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white54, fontStyle: FontStyle.italic)),
    );
  }
}
