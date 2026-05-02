import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../providers/analyzer_provider.dart';
import '../widgets/word_detail_sheet.dart';
import 'settings_screen.dart';
import '../../utils/pinyin_util.dart';
import '../../utils/screen_size.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, AnalyzerProvider provider) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        provider.prevPage();
      } else if (event.logicalKey == LogicalKeyboardKey.keyX) {
        provider.nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.home) {
        provider.firstPage();
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        provider.lastPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, provider),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.langAnalyze, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          leading: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.currentLanguage,
                  icon: const Icon(Icons.language, size: 18),
        items: [
          DropdownMenuItem(value: 'ja', child: Text(AppLocalizations.of(context)!.japanese)),
          DropdownMenuItem(value: 'zh', child: Text(AppLocalizations.of(context)!.chinese)),
          DropdownMenuItem(value: 'en', child: Text(AppLocalizations.of(context)!.english)),
          DropdownMenuItem(value: 'es', child: Text(AppLocalizations.of(context)!.spanish)),
          DropdownMenuItem(value: 'fr', child: Text(AppLocalizations.of(context)!.french)),
          DropdownMenuItem(value: 'de', child: Text(AppLocalizations.of(context)!.german)),
          DropdownMenuItem(value: 'ko', child: Text(AppLocalizations.of(context)!.korean)),
          DropdownMenuItem(value: 'ru', child: Text(AppLocalizations.of(context)!.russian)),
          DropdownMenuItem(value: 'it', child: Text(AppLocalizations.of(context)!.italian)),
          DropdownMenuItem(value: 'pt', child: Text(AppLocalizations.of(context)!.portuguese)),
          DropdownMenuItem(value: 'id', child: Text(AppLocalizations.of(context)!.indonesian)),
        ],
                  onChanged: (val) {
                    if (val != null) provider.setLanguage(val);
                  },
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.pasteTextHere,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _controller.clear()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.isLoading ? null : () => provider.analyzeText(_controller.text),
                  icon: provider.isLoading 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.analytics),
                  label: Text(provider.isLoading ? AppLocalizations.of(context)!.processing : AppLocalizations.of(context)!.analyzeText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    child: LinearProgressIndicator(minHeight: 6),
                  ),
                ),
              const SizedBox(height: 8),
              if (provider.pagedWords.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.grid_view, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: provider.itemsPerRow.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: AppLocalizations.of(context)!.perPageRow(provider.itemsPerRow),
                        onChanged: (val) => provider.updateSetting('itemsPerRow', val.toInt()),
                      ),
                    ),
                    Text(AppLocalizations.of(context)!.perPageRow(provider.itemsPerRow), style: theme.textTheme.bodySmall),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.list, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: provider.itemsPerPage.toDouble(),
                        min: 10,
                        max: 200,
                        divisions: 19,
                        label: AppLocalizations.of(context)!.perPagePage(provider.itemsPerPage),
                        onChanged: (val) => provider.updateSetting('itemsPerPage', val.toInt()),
                      ),
                    ),
                    Text(AppLocalizations.of(context)!.perPagePage(provider.itemsPerPage), style: theme.textTheme.bodySmall),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: provider.firstPage, icon: const Icon(Icons.first_page)),
                      IconButton(onPressed: provider.prevPage, icon: const Icon(Icons.chevron_left)),
                      Text(AppLocalizations.of(context)!.pageOf(provider.currentPage + 1, provider.totalPages)),
                      IconButton(onPressed: provider.nextPage, icon: const Icon(Icons.chevron_right)),
                      IconButton(onPressed: provider.lastPage, icon: const Icon(Icons.last_page)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: provider.pagedWords.isEmpty && !provider.isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(AppLocalizations.of(context)!.noResultsYet, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                    )
        : LayoutBuilder(
          builder: (context, constraints) {
            final columns = ScreenSize.isCompact(context)
                ? 1
                : ScreenSize.isMobile(context)
                    ? 2
                    : provider.itemsPerRow;
            final itemWidth = (constraints.maxWidth / columns) - 8;
                        final pagedWords = provider.pagedWords;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: pagedWords.map((word) {
                              final freq = word.frequency;
                              return SizedBox(
                                width: itemWidth,
                                child: Card(
                                  child: InkWell(
                                    onTap: () => WordDetailSheet.show(context, provider, word),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    word.word,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (word.reading != null && 
                                                      word.reading!.isNotEmpty && 
                                                      provider.currentLanguage == 'zh' &&
                                                      word.reading != word.word)
                                                    Text(
                                                      word.reading!,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white70,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    )
                                                  else if (word.word != null && 
                                                           PinyinUtil.isChinese(word.word!) && 
                                                           provider.currentLanguage == 'zh')
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0),
                                                      child: Text(
                                                        PinyinUtil.getPinyin(word.word!) ?? '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white70,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                              IconButton(
                                                icon: const Icon(Icons.volume_up, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => provider.playAudio(word.word),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getFreqColor(freq ?? 0).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  freq?.toString() ?? '?',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getFreqColor(freq ?? 0)),
                                                ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  provider.saveWord(word.word);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(AppLocalizations.of(context)!.savedWord(word.word)), duration: const Duration(seconds: 1)),
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
                            }).toList(),
                          ),
                        );
                      }
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFreqColor(int freq) {
    if (freq <= 1000) return Colors.greenAccent;
    if (freq <= 5000) return Colors.lightGreenAccent;
    if (freq <= 15000) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}
