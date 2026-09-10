import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart' show YomichanSearchResult;
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/screens/radical_search_screen.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';
import 'package:lang/presentation/widgets/script_text_field.dart';
import 'package:lang/utils/font_scale.dart';

/// Dictionary browser: A-Z / prefix browse over the installed
/// Yomichan dictionaries plus the radical/component search.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final YomichanService _yomichan = YomichanService();

  final TextEditingController _browseController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<YomichanSearchResult> _entries = [];
  bool _loading = false;
  String _query = '';
  int _offset = 0;
  bool _hasMore = true;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _browseController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    _browse(''); // open on the first page of the dictionary
  }

  @override
  void dispose() {
    _browseController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _browseController.text.trim();
    if (q == _query) return;
    _query = q;
    _offset = 0;
    _hasMore = true;
    _entries = [];
    _browse(q);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 400 &&
        !_loading &&
        _hasMore) {
      _browse(_query, append: true);
    }
  }

  Future<void> _browse(String query, {bool append = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final page = await _yomichan.browseEntries(
        query,
        limit: _pageSize,
        offset: append ? _offset : 0,
      );
      if (!mounted) return;
      setState(() {
        if (append) {
          _entries.addAll(page);
        } else {
          _entries = page;
        }
        _offset = (append ? _offset : 0) + page.length;
        _hasMore = page.length >= _pageSize;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _entries = append ? _entries : [];
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionaries),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.sort_by_alpha, size: 18),
              text: l10n.dictionaryTabBrowse,
            ),
            Tab(
              icon: const Icon(Icons.spoke, size: 18),
              text: l10n.dictionaryTabRadicals,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBrowseTab(), const RadicalSearchScreen()],
      ),
    );
  }

  Widget _buildBrowseTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ScriptTextField(
            controller: _browseController,
            language: context.read<AnalyzerProvider>().currentLanguage,
            enabled: appState.autoConvertInput,
            decoration: InputDecoration(
              hintText: l10n.dictionaryBrowseHint,
              prefixIcon: const Icon(Icons.sort_by_alpha),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_loading && _entries.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_loading && _entries.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                l10n.noDictionaryEntries,
                style: TextStyle(
                  fontSize: fs(context, 12),
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        if (_entries.isNotEmpty)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _entries.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final result = _entries[index];
                final entry = result.entry;
                return ListTile(
                  dense: true,
                  title: Text(
                    entry.word,
                    style: TextStyle(
                      fontSize: fs(context, 15, 'words'),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: entry.reading.isNotEmpty
                      ? Text(
                          entry.reading,
                          style: TextStyle(fontSize: fs(context, 12)),
                        )
                      : (entry.definitions.isNotEmpty
                            ? Text(
                                entry.definitions.first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: fs(context, 11)),
                              )
                            : null),
                  trailing: result.dictionary?.name != null
                      ? Text(
                          result.dictionary!.name,
                          style: TextStyle(
                            fontSize: fs(context, 10),
                            color: theme.colorScheme.outline,
                          ),
                        )
                      : null,
                  onTap: () => _openEntry(context, result),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openEntry(
    BuildContext context,
    YomichanSearchResult result,
  ) async {
    final provider = context.read<AnalyzerProvider>();
    // analyze the term so the shared detail sheet has full data
    await provider.searchWord(result.entry.word);
    if (!context.mounted) return;
    final match = provider.searchResults
        .where((w) => w.word == result.entry.word)
        .firstOrNull;
    if (match != null) {
      WordDetailSheet.show(context, provider, match);
    }
  }
}
