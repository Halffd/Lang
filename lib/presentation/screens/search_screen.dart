import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/ocr_service.dart';
import '../providers/analyzer_provider.dart';
import '../providers/ai_provider.dart';
import '../widgets/word_detail_sheet.dart';

enum OcrMode { mlKit, tesseract, easyOcr, ai }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sentenceController = TextEditingController();
  final TextEditingController _ocrController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSentenceMode = false;
  bool _isOcrMode = false;
  bool _isProcessingImage = false;
  int _columnCount = 6;
  OcrMode _ocrMode = OcrMode.mlKit;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sentenceController.dispose();
    _ocrController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isOcrMode) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      if (mounted) {
        _ocrController.text = data.text!;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          _buildModeSelector(theme),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isSentenceMode)
              _buildSentenceInput(theme, provider)
            else if (_isOcrMode)
              _buildOcrInput(theme, provider)
            else
              _buildSearchInput(theme, provider),
            const SizedBox(height: 16),
            Expanded(
              child: _isSentenceMode
                  ? _buildSentenceWordGrid(theme, provider)
                  : _isOcrMode
                      ? _buildOcrResults(theme, provider)
                      : _buildSearchResults(theme, provider),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (_isOcrMode) return 'OCR Text';
    if (_isSentenceMode) return 'Sentence Mode';
    return 'Search Dictionary';
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isOcrMode) ...[
          _buildOcrModeToggle(theme),
          const SizedBox(width: 8),
          _buildColumnCountSelector(theme),
          const SizedBox(width: 8),
        ],
        if (_isSentenceMode) ...[
          _buildColumnCountSelector(theme),
          const SizedBox(width: 8),
        ],
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.search, size: 16)),
            ButtonSegment(value: true, icon: Icon(Icons.text_fields, size: 16)),
          ],
          selected: {_isOcrMode || _isSentenceMode},
          onSelectionChanged: (selection) {
            final newMode = selection.first;
            setState(() {
              _isSentenceMode = false;
              _isOcrMode = newMode;
            });
          },
          showSelectedIcon: false,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildOcrModeToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OcrMode>(
          value: _ocrMode,
          isDense: true,
          items: [
            DropdownMenuItem(
              value: OcrMode.mlKit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, size: 14),
                  const SizedBox(width: 4),
                  Text('ML Kit', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: OcrMode.tesseract,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.document_scanner, size: 14),
                  const SizedBox(width: 4),
                  Text('Tesseract', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: OcrMode.easyOcr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_fix_high, size: 14),
                  const SizedBox(width: 4),
                  Text('EasyOCR', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: OcrMode.ai,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology, size: 14),
                  const SizedBox(width: 4),
                  Text('AI', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _ocrMode = val);
          },
        ),
      ),
    );
  }

  Widget _buildColumnCountSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _columnCount,
          isDense: true,
          items: [3, 4, 5, 6, 7, 8, 9, 10].map((n) => DropdownMenuItem(
            value: n,
            child: Text('$n', style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _columnCount = val);
          },
        ),
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme, AnalyzerProvider provider) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search for a word...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: _searchController,
          builder: (context, value, child) {
            return _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : const SizedBox.shrink();
          },
        ),
      ),
      onSubmitted: (query) => provider.searchWord(query),
    );
  }

  Widget _buildSentenceInput(ThemeData theme, AnalyzerProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _sentenceController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Enter a sentence to split into words...',
              prefixIcon: Icon(Icons.text_fields),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sentenceController.text.isNotEmpty ? () => provider.searchWord(_sentenceController.text) : null,
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _buildOcrInput(ThemeData theme, AnalyzerProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ocrController,
                focusNode: _focusNode,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Paste or type text, or pick an image...',
                  prefixIcon: const Icon(Icons.image),
                  suffixIcon: _ocrController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _ocrController.clear(),
                      )
                    : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: _isProcessingImage ? null : _pickImage,
                  icon: _isProcessingImage
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file),
                  tooltip: 'Pick image from file',
                ),
                IconButton(
                  onPressed: _isProcessingImage ? null : _captureFromClipboard,
                  icon: const Icon(Icons.paste),
                  tooltip: 'Paste image from clipboard',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isProcessingImage)
          const LinearProgressIndicator(),
        ElevatedButton.icon(
          onPressed: _ocrController.text.isNotEmpty && !_isProcessingImage
            ? () => _performOcr(_ocrController.text)
            : null,
          icon: const Icon(Icons.document_scanner),
          label: const Text('Extract Text from Image'),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme, AnalyzerProvider provider) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Type something to search' : 'No results found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final word = provider.searchResults[index];
        return Card(
          child: ListTile(
            title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Freq: ${word.frequency ?? "?"}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => WordDetailSheet.show(context, provider, word),
          ),
        );
      },
    );
  }

  Widget _buildSentenceWordGrid(ThemeData theme, AnalyzerProvider provider) {
    if (_sentenceController.text.isEmpty) {
      return Center(
        child: Text(
          'Enter a sentence above to split into words',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    final words = _parseWords(_sentenceController.text);

    if (words.isEmpty) {
      return const Center(child: Text('No words found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${words.length} words in $_columnCount columns',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        Expanded(child: _WordGrid(words: words, columns: _columnCount, onWordTap: (word) => _handleWordTap(context, provider, word))),
      ],
    );
  }

  Widget _buildOcrResults(ThemeData theme, AnalyzerProvider provider) {
    if (_ocrController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('Pick an image or paste from clipboard', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Text('Supported: PNG, JPG, JPEG, BMP, GIF', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    final lines = _ocrController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isOcrMode) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('${lines.length} lines detected', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _sentenceController.text = _ocrController.text;
                    setState(() {
                      _isOcrMode = false;
                      _isSentenceMode = true;
                    });
                  },
                  icon: const Icon(Icons.text_fields, size: 16),
                  label: const Text('Split into words'),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: lines.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  title: Text(lines[index], style: const TextStyle(fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.text_fields, size: 18),
                        onPressed: () {
                          _sentenceController.text = lines[index];
                          setState(() {
                            _isSentenceMode = true;
                            _isOcrMode = false;
                          });
                        },
                        tooltip: 'Split into words',
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: lines[index]));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                        tooltip: 'Copy',
                      ),
                    ],
                  ),
                  onTap: () {
                    _sentenceController.text = lines[index];
                    setState(() {
                      _isSentenceMode = true;
                      _isOcrMode = false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _parseWords(String text) {
    return text
        .split(RegExp(r'[\s\n]+', multiLine: true))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !RegExp(r'^[^\w\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]+$').hasMatch(w))
        .toList();
  }

  void _handleWordTap(BuildContext context, AnalyzerProvider provider, String word) {
    provider.searchWord(word);
    final match = provider.searchResults.where((w) => w.word == word).firstOrNull;
    if (match != null) {
      WordDetailSheet.show(context, provider, match);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;
        await _processImage(File(imagePath));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _captureFromClipboard() async {
    try {
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData?.text != null && textData!.text!.isNotEmpty) {
        _ocrController.text = textData.text!;
        setState(() {});
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text in clipboard')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing clipboard: $e')),
        );
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _isProcessingImage = true);
    final ocrService = OcrService();

    try {
      if (_ocrMode == OcrMode.ai) {
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final aiProvider = Provider.of<AiProvider>(context, listen: false);
        final text = await aiProvider.extractTextFromImageAi(base64Image);
        _ocrController.text = text;
      } else {
        final OcrEngine engine;
        switch (_ocrMode) {
          case OcrMode.mlKit:
            engine = OcrEngine.mlKit;
            break;
          case OcrMode.tesseract:
            engine = OcrEngine.tesseract;
            break;
          case OcrMode.easyOcr:
            engine = OcrEngine.easyOcr;
            break;
          case OcrMode.ai:
            engine = OcrEngine.mlKit;
            break;
        }

        final result = await ocrService.recognizeFromFile(
          imageFile.path,
          engine: engine,
        );

        if (result.isSuccess) {
          _ocrController.text = result.text;
        } else if (result.isEasyOcrUnavailable) {
          _ocrController.text = '';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('EasyOCR requires a Python backend. Using ML Kit instead...'),
                action: SnackBarAction(
                  label: 'Switch',
                  onPressed: () => setState(() => _ocrMode = OcrMode.mlKit),
                ),
              ),
            );
          }
        } else {
          _ocrController.text = '';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('OCR Error: ${result.error}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessingImage = false);
      ocrService.dispose();
    }
  }

  Future<void> _performOcr(String text) async {
    if (text.startsWith('http://') || text.startsWith('https://') || text.startsWith('file://') || text.startsWith('/')) {
      setState(() => _isProcessingImage = true);
      try {
        if (text.startsWith('file://')) {
          text = text.substring(7);
        }
        await _processImage(File(text));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing image: $e')),
          );
        }
      } finally {
        setState(() => _isProcessingImage = false);
      }
    }
  }
}

class _WordGrid extends StatelessWidget {
  final List<String> words;
  final int columns;
  final void Function(String) onWordTap;

  const _WordGrid({
    required this.words,
    required this.columns,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words.map((word) {
            return SizedBox(
              width: itemWidth.clamp(60.0, 150.0),
              height: 60,
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () => onWordTap(word),
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        word,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}