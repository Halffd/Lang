import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/dictionary.dart';
import '../../../domain/entities/app_state.dart';
import '../../../domain/entities/translation_model.dart';
import '../../data/repositories/dictionary_service.dart';
import '../../data/repositories/translation_service.dart';
import '../../data/services/anki_connect_service.dart';
import '../../core/utils/word_list_mixins.dart';
import '../widgets/dictionary_entry_card.dart';
import '../../utils/language_detector.dart';
import '../widgets/reader/reader_app_bar.dart';
import '../widgets/reader/token_widget.dart';
import '../../data/repositories/reader_translation_service.dart';
import '../../data/datasources/remote/ichi_moe_service.dart';
import '../../utils/html_renderer.dart';
import '../../utils/screen_size.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect;
import '../../data/datasources/document_text_extractor.dart';
import '../../data/datasources/local_translation_service.dart';
import '../../data/datasources/remote/wikipedia_service.dart';
import '../widgets/wikipedia_article_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({Key? key}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SavedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin, DeletedWordsMixin, SRSWordsMixin {
  final TextEditingController _textController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final DocumentTextExtractor _textExtractor = DocumentTextExtractor();
  final LocalTranslationService _localTranslationService = LocalTranslationService();
  late TranslationService _translationService;
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
    final appState = Provider.of<AppState>(context, listen: false);
    setStorageService(appState.storageService);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final geminiKey = prefs.getString('geminiApiKey') ?? '';
      _translationService = TranslationService(
        localService: _localTranslationService,
        geminiApiKey: geminiKey.isNotEmpty ? geminiKey : null,
        provider: appState.translationProvider,
      );
      _readerTranslationService = ReaderTranslationService(_dictionaryService, _translationService);
      await _loadData();

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

      if (text.isNotEmpty && mounted) {
        _textController.text = text;
        await _analyzeText();
      }
    } catch (e) {
      debugPrint('Error auto-pasting from clipboard: $e');
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

    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _sentences = [];
    });

    try {
      final rawSentences = _textController.text.split('\n');

      for (final rawSentence in rawSentences) {
        if (rawSentence.trim().isNotEmpty) {
          final tokens = await _dictionaryService.tokenizeText(rawSentence);
          _sentences.add(tokens);
        }
      }

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _showInput = false;
        _currentSentenceIndex = 0;
        _currentWordIndex = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keyboardFocusNode.requestFocus();
      });

    } catch (e) {
      if (!mounted) return;
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
      if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
        _copyCurrentWord();
        return;
      }

      if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
        _pasteNewText();
        return;
      }

      if (_sentences.isEmpty) return;

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
        return;
      }

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
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
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
      if (text.isNotEmpty && mounted) {
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
      _expandedEntry = null;
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

    final appState = context.read<AppState>();
    if (appState.autoTranslate) {
      _performAutoTranslation();
    }
  }

  void _handleAutoTranslationIfNeeded() {
    if (mounted) {
      final appState = context.read<AppState>();
      if (appState.autoTranslate) {
        _performAutoTranslation();
      }
    }
  }

  Future<void> _performAutoTranslation() async {
    final token = _currentToken;
    if (token == null || token.text.isEmpty) return;

    try {
      final detectedLanguage = LanguageDetector.detect(token.text);

      String targetLanguage = 'en';
      String sourceLanguage = detectedLanguage;

      final request = TranslationRequest(
        sourceText: token.text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      final result = await _translationService.translate(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation: ${result.fullTranslation}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
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

  void _showDetailedWordInfo(String word, String language, List<String> details) {
    print('Detailed word info for "$word" in $language:');
    for (int i = 0; i < details.length; i++) {
      print('  ${i + 1}. ${details[i]}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found detailed info for: $word'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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

  void _showNoTranslationFound(String word) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No translation found for: $word'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isWordInAnki(token.entry!.term) ? 'Added to Anki' : 'Removed from Anki')),
      );
      final appState = context.read<AppState>();
      if (appState.ankiConnectEnabled && isWordInAnki(token.entry!.term)) {
        _sendToAnkiConnect(token, appState);
      }
    }
  }

  void _sendToAnkiConnect(Token token, AppState appState) async {
    final service = AnkiConnectService(appState.ankiConnectUrl);
    try {
      final fields = <String, String>{
        'Front': token.entry!.term,
        'Back': token.entry!.definitions.isNotEmpty ? token.entry!.definitions.first.meaning : token.text,
      };
      await service.addNote(
        deckName: appState.currentAnkiDeck,
        modelName: appState.ankiConnectModel,
        fields: fields,
      );
    } catch (_) {}
  }

  Future<void> _addToFavorites() async {
    final token = _currentToken;
    if (token != null && token.isWord && token.entry != null) {
      await toggleFavoriteWord(token.entry!.term, isFavorite: !isWordFavorite(token.entry!.term));
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isWordFavorite(token.entry!.term) ? 'Added to Favorites' : 'Removed from Favorites')),
      );
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
        await deleteWord(token.entry!.term);
        if (!mounted) return;
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word deleted (hidden)')),
          );
        }
      }
    }
  }

  Future<void> _showWiktionaryDefinition(Token token) async {
    if (token == null || token.text.isEmpty) return;

    try {
      final detectedLanguage = LanguageDetector.detect(token.text);

      final dictionaryService = DictionaryService();
      final wiktionaryDetails = await dictionaryService.fetchWordDetailsMultiLanguage(token.text, detectedLanguage);

      if (wiktionaryDetails.isNotEmpty) {
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

  Future<void> _showWikipediaArticle(Token token) async {
    if (token == null || token.text.isEmpty) return;
    showWikipediaArticle(context, token.text, languageCode: 'ja');
  }

  Future<void> _showIchiMoeDefinition(Token token) async {
    if (token == null || token.text.isEmpty) return;

    try {
      final dictionaryService = DictionaryService();
      final ichiMoeEntries = await dictionaryService.searchIchiMoe(token.text);

      if (ichiMoeEntries.isNotEmpty) {
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
      debugPrint('Error fetching ichi.moe definition: $e');
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

  final ScrollController _scrollController = ScrollController();

  void _scrollToCurrent() {}

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
                            border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
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
              final appState = context.watch<AppState>();

              return TokenWidget(
              token: token,
              isSelected: isSelected,
              isDeleted: isDeleted,
              showInlineDefinition: appState.showInlineDefinitions,
              showHoverDefinition: appState.showHoverDefinitions,
              onTap: () async {
                            setState(() {
                              _currentSentenceIndex = sentenceIndex;
                              _currentWordIndex = wordIndex;
                              _keyboardFocusNode.requestFocus();
                            });

                            await _getDetailedTranslationForToken(token);

                            final appState = context.read<AppState>();
                            if (appState.showWiktionary) {
                              await _showWiktionaryDefinition(token);
                            }

                            await _showIchiMoeDefinition(token);
                          },
                          onSecondaryTap: () async {
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
                                const PopupMenuItem(
                                  value: 'wikipedia',
                                  child: Row(
                                    children: [
                                      Icon(Icons.language, size: 18),
                                      SizedBox(width: 8),
                                      Text('Wikipedia'),
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
                                  case 'wikipedia':
                                    await _showWikipediaArticle(token);
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
            height: ScreenSize.isCompact(context) ? 200 : 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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

  Future<void> _openDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extracting text from document...')),
      );

      final text = await _textExtractor.extractText(filePath);

      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text content found in document')),
          );
        }
        return;
      }

      _textController.text = text;
      await _analyzeText();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }
}
