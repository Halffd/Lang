import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:lang/core/services/history_service.dart';
import 'package:lang/presentation/widgets/document_reader.dart';

class DocumentReaderScreen extends StatefulWidget {
  final String? filePath;
  final String? fileType;
  final bool isMangaMode;

  const DocumentReaderScreen({
    super.key,
    this.filePath,
    this.fileType,
    this.isMangaMode = false,
  });

  @override
  State<DocumentReaderScreen> createState() => DocumentReaderScreenState();
}

class DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final GlobalKey<DocumentReaderState> _documentReaderKey =
      GlobalKey<DocumentReaderState>();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  int _currentPage = 1;
  int _totalPages = 1;
  String? _currentFilePath;
  String? _currentFileType;
  bool _showControls = true;
  String _pastedText = '';

  @override
  void initState() {
    super.initState();
    _pageController.text = '1';
    _currentFilePath = widget.filePath;
    _currentFileType = widget.fileType;
    // reading is driven by the field itself — no submit button
    _textController.text = _pastedText;
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Text mode is entered and left purely by the content of the field, so
  /// there is no "Read" button to press.
  void _onTextChanged() {
    final text = _textController.text;
    final trimmed = text.trim();
    final isText = _currentFilePath == null && trimmed.isNotEmpty;
    if (isText == (_currentFileType == 'text') && trimmed == _pastedText) {
      return;
    }
    setState(() {
      _pastedText = trimmed;
      if (isText) {
        _currentFilePath = null;
        _currentFileType = 'text';
        _currentPage = 1;
        _totalPages = 1;
        _pageController.text = '1';
      } else {
        // emptied the field: back to the landing screen
        _currentFileType = null;
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  if (_currentFilePath != null && _currentFileType != null)
                    Positioned.fill(
                      child: DocumentReader(
                        key: _documentReaderKey,
                        filePath: _currentFilePath!,
                        fileType: _currentFileType!,
                        isMangaMode: widget.isMangaMode,
                        onPageChanged: (currentPage, totalPages) {
                          setState(() {
                            _currentPage = currentPage;
                            _totalPages = totalPages;
                            _pageController.text = currentPage.toString();
                          });
                        },
                      ),
                    )
                  else if (_currentFileType == 'text')
                    Positioned.fill(
                      child: _TextReaderView(
                        initialText: _pastedText,
                        onOpened: (t) => HistoryService.instance.record(
                          HistoryCategory.document,
                          'Pasted text',
                          subtitle: t.length > 80 ? t.substring(0, 80) : t,
                        ),
                      ),
                    )
                  else
                    _ReaderLanding(
                      onOpenFile: _openFile,
                      onOpenManga: _openMangaFolder,
                    ),
                  if (_showControls &&
                      _currentFileType != null &&
                      _currentFileType != 'txt')
                    _buildNavigationOverlay(),
                  if (_showControls) _buildAppBar(),
                ],
              ),
            ),
          ),
          // Outside the tap-to-toggle detector on purpose: tapping the field
          // to focus it must not hide the controls.
          if (_currentFilePath == null) _buildTextInput(),
        ],
      ),
    );
  }

  /// Always-visible multiline input pinned to the bottom. Reading starts as
  /// soon as there is text; clearing it returns to the landing screen.
  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _textController,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Paste or type text to read…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(_currentFilePath?.split('/').last ?? 'Reader'),
            actions: [
              IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _openFile,
                tooltip: 'Open file',
              ),
              IconButton(
                icon: const Icon(Icons.photo_library),
                onPressed: _openMangaFolder,
                tooltip: 'Open manga folder',
              ),
              if (_currentFileType == 'manga' ||
                  _currentFileType == 'cbz' ||
                  _currentFileType == 'folder')
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    setState(() {
                      // Toggle reading direction would require reloading with different mode
                    });
                  },
                  tooltip: 'Toggle reading direction (RTL/LTR)',
                ),
              PopupMenuButton<String>(
                onSelected: (String result) {
                  if (result == 'page_info') {
                    _showPageInfo();
                  } else if (result == 'open') {
                    _openFile();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text('Open'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'page_info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Page Info'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationOverlay() {
    if (_currentFileType == 'txt') return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () {
                          final state = _documentReaderKey.currentState;
                          if (state != null) {
                            state.goToPreviousPage();
                          }
                        }
                      : null,
                ),
                if (_currentFileType != 'manga' &&
                    _currentFileType != 'cbz' &&
                    _currentFileType != 'folder' &&
                    _currentFileType != 'zip') ...[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextFormField(
                        controller: _pageController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'Page',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onFieldSubmitted: (value) {
                          int? page = int.tryParse(value);
                          if (page != null &&
                              page >= 1 &&
                              page <= _totalPages) {
                            final state = _documentReaderKey.currentState;
                            if (state != null) {
                              state.goToPage(page);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const Text('/'),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$_totalPages',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () {
                          final state = _documentReaderKey.currentState;
                          if (state != null) {
                            state.goToNextPage();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'fb2', 'cbz', 'zip'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      final ext = path.extension(filePath).toLowerCase().replaceFirst('.', '');
      String fileType;

      switch (ext) {
        case 'pdf':
          fileType = 'pdf';
          break;
        case 'epub':
          fileType = 'epub';
          break;
        case 'txt':
          fileType = 'txt';
          break;
        case 'fb2':
          fileType = 'fb2';
          break;
        case 'cbz':
        case 'zip':
          fileType = 'manga';
          break;
        default:
          fileType = 'txt';
      }

      setState(() {
        _currentFilePath = filePath;
        _currentFileType = fileType;
        _currentPage = 1;
        _totalPages = 1;
        _pageController.text = '1';
      });
      HistoryService.instance.record(
        HistoryCategory.document,
        path.basename(filePath),
        subtitle: filePath,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }

  Future<void> _openMangaFolder() async {
    try {
      final String? folderPath = await FilePicker.platform.getDirectoryPath();

      if (folderPath == null) return;

      setState(() {
        _currentFilePath = folderPath;
        _currentFileType = 'folder';
        _currentPage = 1;
        _totalPages = 1;
        _pageController.text = '1';
      });
      HistoryService.instance.record(
        HistoryCategory.document,
        path.basename(folderPath),
        subtitle: folderPath,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening folder: $e')));
      }
    }
  }

  void _showPageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current page: $_currentPage'),
            Text('Total pages: $_totalPages'),
            if (_currentFileType != null) Text('Format: $_currentFileType'),
            if (_currentFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Path: $_currentFilePath',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Reader landing (nothing open): recents list from history + actions.
class _ReaderLanding extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onOpenManga;

  const _ReaderLanding({required this.onOpenFile, required this.onOpenManga});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recents = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.document)
        .take(10)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.menu_book, size: 48),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Open file'),
                onPressed: onOpenFile,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Open manga folder'),
                onPressed: onOpenManga,
              ),
              const SizedBox(height: 8),
              Text(
                'Or paste text below to read it',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (recents.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Recent documents', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recents.length,
                    itemBuilder: (context, i) {
                      final item = recents[i];
                      final filePath = item.subtitle ?? '';
                      final isFile = filePath.contains('/');
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isFile ? Icons.insert_drive_file : Icons.notes,
                          size: 20,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: isFile
                            ? Text(
                                filePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        onTap: isFile
                            ? () => _openRecent(context, filePath)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _openRecent(BuildContext context, String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    final fileType = switch (ext) {
      'pdf' => 'pdf',
      'epub' => 'epub',
      'fb2' => 'fb2',
      'cbz' || 'zip' => 'manga',
      _ => 'txt',
    };
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DocumentReaderScreen(filePath: filePath, fileType: fileType),
      ),
    );
  }
}

/// Multiline text reader view: scrollable text with popup-dictionary support.
class _TextReaderView extends StatelessWidget {
  final String initialText;
  final void Function(String text)? onOpened;

  const _TextReaderView({required this.initialText, this.onOpened});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        initialText,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
      ),
    );
  }
}
