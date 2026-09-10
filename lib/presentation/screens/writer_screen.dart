import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/data/services/dictionary/tokenizer_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';
import 'package:lang/utils/font_scale.dart';

/// Writer: compose text in the target language, see live
/// tokenization, tap tokens for lookups and send the draft to
/// the analyze screen for a full breakdown.
class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final TextEditingController _controller = TextEditingController();
  final TokenizerService _tokenizer = TokenizerService();
  Timer? _debounce;

  List<Token> _tokens = [];
  bool _tokenizing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // char counter
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _tokenize);
  }

  Future<void> _tokenize() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _tokens = []);
      return;
    }
    if (!mounted) return;
    setState(() => _tokenizing = true);
    try {
      final tokens = await _tokenizer.tokenize(text);
      // ignore edits made while tokenizing
      if (!mounted || _controller.text != text) return;
      setState(() => _tokens = tokens);
    } catch (_) {
      if (mounted) setState(() => _tokens = []);
    } finally {
      if (mounted) setState(() => _tokenizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final text = _controller.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.writerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase),
            tooltip: l10n.analyzeText,
            onPressed: text.trim().isEmpty
                ? null
                : () => _sendToAnalyze(context, text),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // editor
            TextField(
              controller: _controller,
              maxLines: 6,
              style: TextStyle(
                fontSize: fs(context, 15, 'sentences'),
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: l10n.writerHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (_tokenizing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                Text(
                  '${text.characters.length}',
                  style: TextStyle(
                    fontSize: fs(context, 11),
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // live tokens
            Expanded(
              child: _tokens.isEmpty
                  ? Center(
                      child: Text(
                        text.trim().isEmpty
                            ? l10n.writerEmptyTokens
                            : l10n.noDictionaryEntries,
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tokens.length,
                      itemBuilder: (context, index) {
                        final token = _tokens[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            token.surface,
                            style: TextStyle(
                              fontSize: fs(context, 14, 'words'),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle:
                              (token.reading.isNotEmpty ||
                                  token.partOfSpeech.isNotEmpty)
                              ? Text(
                                  [
                                    if (token.reading.isNotEmpty) token.reading,
                                    if (token.partOfSpeech.isNotEmpty)
                                      token.partOfSpeech,
                                  ].join(' · '),
                                  style: TextStyle(fontSize: fs(context, 11)),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.search, size: 16),
                            tooltip: l10n.search,
                            onPressed: () => _lookup(context, token.surface),
                          ),
                          onTap: () => _lookup(context, token.surface),
                        );
                      },
                    ),
            ),

            // script conversion state hint
            if (appState.autoConvertInput) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.writerAutoConvertNote,
                  style: TextStyle(
                    fontSize: fs(context, 10),
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Token lookup: dictionary search then the shared detail sheet.
  Future<void> _lookup(BuildContext context, String surface) async {
    final provider = context.read<AnalyzerProvider>();
    await provider.searchWord(surface);
    if (!context.mounted) return;
    final match = provider.searchResults
        .where((w) => w.word == surface)
        .firstOrNull;
    if (match != null) {
      WordDetailSheet.show(context, provider, match);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$surface: ${AppLocalizations.of(context)!.noResultsFound}',
          ),
        ),
      );
    }
  }

  /// Send the draft to the analyze screen for a full breakdown.
  Future<void> _sendToAnalyze(BuildContext context, String text) async {
    final provider = context.read<AnalyzerProvider>();
    await provider.analyzeText(text);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyzeScreen()),
    );
  }
}
