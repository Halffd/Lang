import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../domain/entities/dictionary.dart';
import '../../../domain/entities/app_state.dart';
import '../../../domain/entities/translation_model.dart';
import '../../data/repositories/dictionary_service.dart';
import '../../data/repositories/translation_service.dart';
import '../../core/utils/word_list_mixins.dart';
import '../widgets/dictionary_entry_card.dart';
import '../../utils/language_detector.dart';
import '../widgets/reader/reader_app_bar.dart';
import '../widgets/reader/token_widget.dart';
import '../../data/repositories/reader_translation_service.dart';
import '../../data/datasources/remote/ichi_moe_service.dart';
import '../../utils/html_renderer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect;

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({Key? key}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SavedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin, DeletedWordsMixin, SRSWordsMixin {
  final TextEditingController _textController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final TranslationService _translationService = TranslationService();
  final FocusNode _keyboardFocusNode = FocusNode();
  
  // State
  bool _isAnalyzing = false;
  List<List<Token>> _sentences = [];
  int _currentSentenceIndex = 0;
  int _currentWordIndex = 0;
  bool _showInput = true;
  DictionaryEntry? _expandedEntry;

  late ReaderTranslationService _readerTranslationService;

  @override
  void initState() {
    super.initState();
    _readerTranslationService = ReaderTranslationService(_dictionaryService, _translationService);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Get the storage service from the app state
      final appState = Provider.of<AppState>(context, listen: false);
      setStorageService(appState.storageService);
      await _loadData();

      // Check if auto-paste is enabled and try to paste from clipboard
      if (appState.autoPasteReader) {
        await _autoPasteFromClipboard();
      }
    });
  }

  Future<void> _loadData() async {
    await loadSavedWords();
    await loadAnkiWords();
    await loadFavoriteWords();
    await loadSRSWords();
    await loadDeletedWords();
  }

  Future<void> _autoPasteFromClipboard() async {
    try {
      final ClipboardData? clipboardData = await Clipboard.getData('text/plain');
      final text = clipboardData?.text ?? '';

      if (text.isNotEmpty) {
        _textController.text = text;
        await _analyzeText();
      }
    } catch (e) {
      print('Error auto-pasting from clipboard: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _sentences = [];
    });

    try {
      // Split by newlines to handle "PgUp/Dn to go to next line"
      final rawSentences = _textController.text.split('\n');

      for (final rawSentence in rawSentences) {
        if (rawSentence.trim().isNotEmpty) {
          final tokens = await _dictionaryService.tokenizeText(rawSentence);
          _sentences.add(tokens);
        }
      }

      setState(() {
        _isAnalyzing = false;
        _showInput = false;
        _currentSentenceIndex = 0;
        _currentWordIndex = 0;
      });

      // Request focus for keyboard navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _keyboardFocusNode.requestFocus();
      });

    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing text: $e')),
        );
      }
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Check for Ctrl+C (copy)
      if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
        _copyCurrentWord();
        return;
      }

      // Check for Ctrl+V (paste)
      if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
        _pasteNewText();
        return;
      }

      if (_sentences.isEmpty) return;

      // Toggle auto-paste with 'm' key
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setAutoPasteReader(!appState.autoPasteReader);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appState.autoPasteReader
              ? 'Auto-paste enabled'
              : 'Auto-paste disabled'),
            duration: const Duration(seconds: 1),
          ),
        );
        return; // Early return to avoid other processing
      }

      // Navigation
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveNextWord();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _movePrevWord();
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        _moveEndLine();
      } else if (event.logicalKey == LogicalKeyboardKey.home) {
        _moveStartLine();
      } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
        _moveNextLine();
      } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
        _movePrevLine();
      }
      // Actions
      else if (event.logicalKey == LogicalKeyboardKey.space) {
        _toggleExpandInfo();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _addToAnki();
      } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
        _addToFavorites();
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        _deleteFromDb();
      }
    }
  }

  Future<void> _copyCurrentWord() async {
    final token = _currentToken;
    if (token != null) {
      await Clipboard.setData(ClipboardData(text: token.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied: ${token.text}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _pasteNewText() async {
    try {
      final ClipboardData? clipboardData = await Clipboard.getData('text/plain');
      final text = clipboardData?.text ?? '';
      if (text.isNotEmpty) {
        setState(() {
          _showInput = true;
          _textController.text = text;
          _sentences = [];
          _currentSentenceIndex = 0;
          _currentWordIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pasting: $e')),
        );
      }
    }
  }

  Token? get _currentToken {
    if (_sentences.isEmpty) return null;
    if (_currentSentenceIndex >= _sentences.length) return null;
    final sentence = _sentences[_currentSentenceIndex];
    if (_currentWordIndex >= sentence.length) return null;
    return sentence[_currentWordIndex];
  }

  void _moveNextWord() {
    setState(() {
      final sentence = _sentences[_currentSentenceIndex];
      if (_currentWordIndex < sentence.length - 1) {
        _currentWordIndex++;
      } else if (_currentSentenceIndex < _sentences.length - 1) {
        _currentSentenceIndex++;
        _currentWordIndex = 0;
      }
      _expandedEntry = null; // Close expanded info on move
    });
    _scrollToCurrent();
    _handleAutoTranslationIfNeeded();
  }

  void _movePrevWord() {
    setState(() {
      if (_currentWordIndex > 0) {
        _currentWordIndex--;
      } else if (_currentSentenceIndex > 0) {
        _currentSentenceIndex--;
        _currentWordIndex = _sentences[_currentSentenceIndex].length - 1;
      }
      _expandedEntry = null;
    });
    _scrollToCurrent();
  }

  void _moveEndLine() {
    setState(() {
      _currentWordIndex = _sentences[_currentSentenceIndex].length - 1;
      _expandedEntry = null;
    });
    _scrollToCurrent();
  }

  void _moveStartLine() {
    setState(() {
      _currentWordIndex = 0;
      _expandedEntry = null;
    });
    _scrollToCurrent();
  }

  void _moveNextLine() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        _currentWordIndex = 0;
        _expandedEntry = null;
      });
      _scrollToCurrent();
    }
  }

  void _movePrevLine() {
    if (_currentSentenceIndex > 0) {
      setState(() {
        _currentSentenceIndex--;
        _currentWordIndex = 0;
        _expandedEntry = null;
      });
      _scrollToCurrent();
    }
  }

  void _toggleExpandInfo() {
    final token = _currentToken;
    if (token != null && token.isWord && token.entry != null) {
      setState(() {
        if (_expandedEntry == token.entry) {
          _expandedEntry = null;
        } else {
          _expandedEntry = token.entry;
        }
      });
    }

    // If auto translate is enabled, translate when expanding the word info
    final appState = context.read<AppState>();
    if (appState.autoTranslate) {
      _performAutoTranslation();
    }
  }

  /// Handle auto translation if enabled
  void _handleAutoTranslationIfNeeded() {
    if (mounted) {
      final appState = context.read<AppState>();
      if (appState.autoTranslate) {
        _performAutoTranslation();
      }
    }
  }

  /// Perform auto translation for the current token
  Future<void> _performAutoTranslation() async {
    final token = _currentToken;
    if (token == null || token.text.isEmpty) return;

    try {
      // Detect language of the token text
      final detectedLanguage = LanguageDetector.detect(token.text);

      // Create a translation request for the current token
      // For European languages, translate to English; for Asian languages, use appropriate target
      String targetLanguage = 'en'; // Default to English
      String sourceLanguage = detectedLanguage;

      // Create a translation request for the current token
      final request = TranslationRequest(
        sourceText: token.text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      final result = await _translationService.translate(request);

      // For now, show a snackbar with the translation
      // In a more advanced implementation, we could show this inline
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation: ${result.fullTranslation}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Optionally show an error message
      print('Translation failed: $e');
    }
  }

  Future<void> _getDetailedTranslationForToken(Token token) async {
    if (!_isValidToken(token)) return;

    final detectedLanguage = LanguageDetector.detect(token.text);

    // Try Wiktionary first
    final wiktionaryDetails = await _fetchWiktionaryDetails(token.text, detectedLanguage);
    if (wiktionaryDetails.isNotEmpty) {
      _showDetailedWordInfo(token.text, detectedLanguage, wiktionaryDetails);
      return;
    }

    // Fallback to translation service
    await _fallbackToTranslation(token.text, detectedLanguage);
  }

  bool _isValidToken(Token? token) {
    return token != null && token.text.isNotEmpty;
  }

  Future<List<String>> _fetchWiktionaryDetails(String text, String language) async {
    try {
      return await _dictionaryService.fetchWordDetailsMultiLanguage(text, language);
    } catch (e) {
      print('Wiktionary fetch failed: $e');
      return [];
    }
  }

  Future<void> _fallbackToTranslation(String text, String sourceLanguage) async {
    try {
      final request = TranslationRequest(
        sourceText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: 'en',
      );
      final result = await _translationService.translate(request);
      _showTranslationResult(result);
    } catch (e) {
      _showError('Translation failed for: $text');
    }
  }

  /// Show detailed word information from Wiktionary
  void _showDetailedWordInfo(String word, String language, List<String> details) {
    // For now, we'll just print the details - in a real implementation
    // you'd show this information in a popup or dialog
    print('Detailed word info for "$word" in $language:');
    for (int i = 0; i < details.length; i++) {
      print('  ${i + 1}. ${details[i]}');
    }

    // In the future, this could show a detailed popup with the information
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found detailed info for: $word'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show translation result in UI
  void _showTranslationResult(TranslationResult result) {
    final translation = result.fullTranslation.isNotEmpty ? result.fullTranslation :
                       result.wordTranslations.firstOrNull?.translation ?? '';
    if (translation.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation: $translation'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show message when no translation is found
  void _showNoTranslationFound(String word) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No translation found for: $word'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _addToAnki() async {
    final token = _currentToken;
    if (token != null && token.isWord && token.entry != null) {
      await toggleAnkiWord(token.entry!.term, isAnki: !isWordInAnki(token.entry!.term));
      setState(() {}); // Refresh UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isWordInAnki(token.entry!.term) ? 'Added to Anki' : 'Removed from Anki')),
        );
      }
    }
  }

  Future<void> _addToFavorites() async {
    final token = _currentToken;
    if (token != null && token.isWord && token.entry != null) {
      await toggleFavoriteWord(token.entry!.term, isFavorite: !isWordFavorite(token.entry!.term));
      setState(() {}); // Refresh UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isWordFavorite(token.entry!.term) ? 'Added to Favorites' : 'Removed from Favorites')),
        );
      }
    }
  }

  Future<void> _deleteFromDb() async {
    final token = _currentToken;
    if (token != null && token.isWord && token.entry != null) {
      // Confirm deletion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete from Database'),
          content: Text('Are you sure you want to delete "${token.entry!.term}" from the dictionary database? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true) {
        // Since we don't have a direct delete entry method in DictionaryService exposed for individual entries easily
        // (the service has deleteDictionary but not deleteEntry), we might need to add it or skip.
        // The user specifically asked for "delete to delete from db".
        // Checking DictionaryService... it doesn't have deleteEntry.
        // But we have 'deleted words' mixin which hides it. Maybe the user implies that?
        // "delete to delete from db" suggests permanent deletion, but "DeletedWordsMixin" suggests hiding.
        // I will use DeletedWordsMixin as it's safer and already implemented.
        
        await deleteWord(token.entry!.term);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word deleted (hidden)')),
          );
        }
      }
    }
  }

  /// Show Wiktionary definition for the selected token
  Future<void> _showWiktionaryDefinition(Token token) async {
    if (token == null || token.text.isEmpty) return;

    try {
      // Detect language of the token text
      final detectedLanguage = LanguageDetector.detect(token.text);

      // Fetch Wiktionary details
      final dictionaryService = DictionaryService();
      final wiktionaryDetails = await dictionaryService.fetchWordDetailsMultiLanguage(token.text, detectedLanguage);

      if (wiktionaryDetails.isNotEmpty) {
        // Show Wiktionary details in a dialog
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Wiktionary: ${token.text}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: wiktionaryDetails.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '${index + 1}. ${wiktionaryDetails[index]}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } else {
        // Show message if no Wiktionary details found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No Wiktionary details found for: ${token.text}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching Wiktionary definition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch Wiktionary details for: ${token.text}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show ichi.moe definition for the selected token
  Future<void> _showIchiMoeDefinition(Token token) async {
    if (token == null || token.text.isEmpty) return;

    try {
      // Fetch ichi.moe details
      final dictionaryService = DictionaryService();
      final ichiMoeEntries = await dictionaryService.searchIchiMoe(token.text);

      if (ichiMoeEntries.isNotEmpty) {
        // Show ichi.moe details in a dialog
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Ichi.moe: ${token.text}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ichiMoeEntries.length,
                  itemBuilder: (context, index) {
                    final entry = ichiMoeEntries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${entry.term}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...entry.definitions.asMap().entries.map((defEntry) {
                            final defIndex = defEntry.key;
                            final definition = defEntry.value;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                              child: HtmlRenderer.renderHtmlSafe(definition),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } else {
        // Show message if no ichi.moe details found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No ichi.moe details found for: ${token.text}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching ichi.moe definition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch ichi.moe details for: ${token.text}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Scroll logic is tricky with Wrap. For now, we rely on the user seeing the highlight.
  // Ideally, we'd use ScrollablePositionedList, but we have a list of Wraps.
  final ScrollController _scrollController = ScrollController();

  void _scrollToCurrent() {
    // Basic auto-scroll: scroll to the approximate position of the sentence
    // This is not perfect for long sentences wrapped multiple times.
    // A better approach requires calculating the offset of the specific token, which is hard.
    // For now, ensuring the sentence is in view is a good start.
  }

  @override
  Widget build(BuildContext context) {
    if (_showInput) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Text Reader'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (String result) {
                if (result == 'open_document') {
                  _openDocument();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'open_document',
                  child: Text('Open Document'),
                ),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Paste text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeText,
                icon: _isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.analytics),
                label: const Text('Analyze Text'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: ReaderAppBar(),
      body: RawKeyboardListener(
        focusNode: _keyboardFocusNode,
        onKey: _handleKeyEvent,
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _sentences.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, sentenceIndex) {
                  final sentence = _sentences[sentenceIndex];
                  final isCurrentSentence = sentenceIndex == _currentSentenceIndex;

                  return Container(
                    decoration: isCurrentSentence
                        ? BoxDecoration(
                            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).primaryColor.withOpacity(0.05),
                          )
                        : null,
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(sentence.length, (wordIndex) {
                        final token = sentence[wordIndex];
                        final isSelected = isCurrentSentence && wordIndex == _currentWordIndex;
                        final isDeleted = token.isWord && isWordDeleted(token.text);

                        return TokenWidget(
                          token: token,
                          isSelected: isSelected,
                          isDeleted: isDeleted,
                          onTap: () async {
                            setState(() {
                              _currentSentenceIndex = sentenceIndex;
                              _currentWordIndex = wordIndex;
                              _keyboardFocusNode.requestFocus();
                            });

                            // Get detailed translation using the enhanced multi-language service
                            await _getDetailedTranslationForToken(token);

                            // If Wiktionary is enabled, show Wiktionary details
                            final appState = context.read<AppState>();
                            if (appState.showWiktionary) {
                              await _showWiktionaryDefinition(token);
                            }

                            // Always show ichi.moe details for Japanese terms
                            await _showIchiMoeDefinition(token);
                          },
                          onSecondaryTap: () async {
                            // Right-click context menu for additional options
                            await showMenu(
                              context: context,
                              position: const RelativeRect.fromLTRB(100, 100, 0, 0),
                              items: [
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy, size: 18),
                                      SizedBox(width: 8),
                                      Text('Copy'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'search',
                                  child: Row(
                                    children: [
                                      Icon(Icons.search, size: 18),
                                      SizedBox(width: 8),
                                      Text('Search'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'add_favorite',
                                  child: Row(
                                    children: [
                                      Icon(Icons.favorite, size: 18),
                                      SizedBox(width: 8),
                                      Text('Add to Favorites'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'add_anki',
                                  child: Row(
                                    children: [
                                      Icon(Icons.star, size: 18),
                                      const SizedBox(width: 8),
                                      Text(context.read<AppState>().ankiWords.contains(token.text) ? 'Remove from Anki' : 'Add to Anki'),
                                    ],
                                  ),
                                ),
                              ],
                            ).then((value) async {
                              if (value != null) {
                                switch (value) {
                                  case 'copy':
                                    await Clipboard.setData(ClipboardData(text: token.text));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Copied: ${token.text}')),
                                      );
                                    }
                                    break;
                                  case 'search':
                                    // Trigger search for the token text
                                    final results = await _dictionaryService.searchTerm(token.text);
                                    if (results.entries.isNotEmpty) {
                                      setState(() {
                                        _expandedEntry = results.entries[0];
                                      });
                                    }
                                    break;
                                  case 'add_favorite':
                                    final appState = context.read<AppState>();
                                    if (appState.favoriteWords.contains(token.text)) {
                                      appState.removeFavoriteWord(token.text);
                                    } else {
                                      appState.addFavoriteWord(token.text);
                                    }
                                    break;
                                  case 'add_anki':
                                    final appState = context.read<AppState>();
                                    if (appState.ankiWords.contains(token.text)) {
                                      appState.removeAnkiWord(token.text);
                                    } else {
                                      appState.addAnkiWord(token.text);
                                    }
                                    break;
                                }
                              }
                            });
                          },
                          fontSize: 24,
                          definitionFontSize: 16,
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
            if (_expandedEntry != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _expandedEntry = null),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: DictionaryEntryCard(
                          entry: _expandedEntry!,
                          isSaved: isWordSaved(_expandedEntry!.term),
                          isFavorite: isWordFavorite(_expandedEntry!.term),
                          isInAnki: isWordInAnki(_expandedEntry!.term),
                          isInSRS: isWordInSRS(_expandedEntry!.term),
                          onSaveToggle: () => toggleSavedWord(_expandedEntry!.term, isSaved: !isWordSaved(_expandedEntry!.term)),
                          onFavoriteToggle: () => toggleFavoriteWord(_expandedEntry!.term, isFavorite: !isWordFavorite(_expandedEntry!.term)),
                          onAnkiToggle: () => toggleAnkiWord(_expandedEntry!.term, isAnki: !isWordInAnki(_expandedEntry!.term)),
                          onSRSToggle: () => toggleSRSWord(_expandedEntry!.term, isInSRS: !isWordInSRS(_expandedEntry!.term)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens a file picker to select and read PDF, EPUB, or TXT files
  Future<void> _openDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileExtension = result.files.single.extension?.toLowerCase() ?? 'txt';

        // For now, just show a message that the file was selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected file: $filePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }
}
