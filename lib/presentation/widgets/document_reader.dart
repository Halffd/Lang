import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import 'package:archive/archive.dart';
import 'package:lang/utils/font_scale.dart';

typedef OnPageChangedCallback = void Function(int currentPage, int totalPages);

class DocumentReader extends StatefulWidget {
  final String filePath;
  final String fileType;
  final OnPageChangedCallback? onPageChanged;
  final bool isMangaMode;

  const DocumentReader({
    super.key,
    required this.filePath,
    required this.fileType,
    this.onPageChanged,
    this.isMangaMode = false,
  });

  @override
  State<DocumentReader> createState() => DocumentReaderState();
}

class DocumentReaderState extends State<DocumentReader> {
  late DocumentType _documentType;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfViewerController? _pdfViewerController;

  // Lazy-load manga pages: only keep current ±2 pages in memory
  final Map<int, Uint8List> _mangaPageCache = {};
  List<String> _mangaPagePaths = [];
  final int _mangaCacheWindow = 2;
  bool _mangaLoading = true;
  String? _mangaError;
  final PageController _mangaPageController = PageController();
  bool _isVerticalScroll = false;

  /// Evict pages outside the cache window
  void _evictCache() {
    final keysToRemove = _mangaPageCache.keys
        .where((k) => (k - _currentPage).abs() > _mangaCacheWindow)
        .toList();
    for (final k in keysToRemove) {
      _mangaPageCache.remove(k);
    }
  }

  /// Load page on demand
  Future<Uint8List?> _loadPage(int pageIndex) async {
    if (pageIndex < 1 || pageIndex > _totalPages) return null;
    if (_mangaPageCache.containsKey(pageIndex)) {
      _evictCache();
      return _mangaPageCache[pageIndex]!;
    }
    try {
      final bytes = await File(_mangaPagePaths[pageIndex - 1]).readAsBytes();
      _mangaPageCache[pageIndex] = bytes;
      _evictCache();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _documentType = _getDocumentType(widget.fileType);
    if (_documentType == DocumentType.pdf) {
      _pdfViewerController = PdfViewerController();
    }
    if (_documentType == DocumentType.manga ||
        _documentType == DocumentType.cbz ||
        _documentType == DocumentType.folder) {
      _loadMangaImages();
    }
  }

  @override
  void dispose() {
    _mangaPageCache.clear();
    _mangaPageController.dispose();
    super.dispose();
  }

  DocumentType _getDocumentType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return DocumentType.pdf;
      case 'epub':
        return DocumentType.epub;
      case 'txt':
        return DocumentType.txt;
      case 'manga':
        return DocumentType.manga;
      case 'cbz':
      case 'cbr':
      case 'zip':
        return DocumentType.cbz;
      case 'folder':
        return DocumentType.folder;
      case 'fb2':
        return DocumentType.fb2;
      default:
        return DocumentType.txt;
    }
  }

  Future<void> _loadMangaImages() async {
    setState(() {
      _mangaLoading = true;
      _mangaError = null;
    });

    try {
      // Store paths instead of loading all images into memory
      final List<String> paths = [];

      if (_documentType == DocumentType.folder) {
        final dir = Directory(widget.filePath);
        if (await dir.exists()) {
          final files = await dir.list().toList();
          final imageExtensions = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
            '.bmp',
          ];
          final imageFiles =
              files
                  .whereType<File>()
                  .where(
                    (f) => imageExtensions.any(
                      (ext) => f.path.toLowerCase().endsWith(ext),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.path.compareTo(b.path));

          for (final file in imageFiles) {
            paths.add(file.path);
          }
        }
      } else {
        final file = File(widget.filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);

          final imageExtensions = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
            '.bmp',
          ];
          final imageFiles =
              archive.files
                  .where(
                    (f) =>
                        !f.isFile ||
                        imageExtensions.any(
                          (ext) => f.name.toLowerCase().endsWith(ext),
                        ),
                  )
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

          // Extract archive entries to temp files and store paths
          final tempDir = await Directory.systemTemp.createTemp('manga_');
          for (final archiveFile in imageFiles) {
            if (archiveFile.isFile) {
              final tempFile = File('${tempDir.path}/${archiveFile.name}');
              await tempFile.writeAsBytes(archiveFile.content as List<int>);
              paths.add(tempFile.path);
            }
          }
        }
      }

      setState(() {
        _mangaPagePaths = paths;
        _totalPages = paths.length;
        _mangaLoading = false;
        if (_totalPages > 0) {
          _currentPage = 1;
          _precachePages();
        }
      });

      if (widget.onPageChanged != null) {
        widget.onPageChanged!(_currentPage, _totalPages);
      }
    } catch (e) {
      setState(() {
        _mangaError = e.toString();
        _mangaLoading = false;
      });
    }
  }

  /// Precache current page and neighbors
  Future<void> _precachePages() async {
    final start = (_currentPage - _mangaCacheWindow).clamp(1, _totalPages);
    final end = (_currentPage + _mangaCacheWindow).clamp(1, _totalPages);
    for (int i = start; i <= end; i++) {
      if (!_mangaPageCache.containsKey(i)) {
        try {
          final bytes = await File(_mangaPagePaths[i - 1]).readAsBytes();
          _mangaPageCache[i] = bytes;
        } catch (_) {}
      }
    }
    _evictCache();
  }

  /// Load page on demand
  @override
  Widget build(BuildContext context) {
    switch (_documentType) {
      case DocumentType.pdf:
        return _buildPdfViewer();
      case DocumentType.epub:
        return _buildEpubViewer();
      case DocumentType.txt:
        return _buildTxtViewer();
      case DocumentType.manga:
      case DocumentType.cbz:
      case DocumentType.folder:
        return _buildMangaViewer();
      case DocumentType.fb2:
        return _buildFb2Viewer();
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(widget.filePath),
      controller: _pdfViewerController,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _totalPages = details.document.pages.count;
          });
          if (widget.onPageChanged != null) {
            widget.onPageChanged!(_currentPage, _totalPages);
          }
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
        if (widget.onPageChanged != null) {
          widget.onPageChanged!(_currentPage, _totalPages);
        }
      },
    );
  }

  Widget _buildEpubViewer() {
    return EpubView(
      controller: EpubController(
        document: EpubDocument.openFile(File(widget.filePath)),
      ),
      onDocumentLoaded: (book) {
        setState(() {
          _totalPages = 1;
        });
        if (widget.onPageChanged != null) {
          widget.onPageChanged!(_currentPage, _totalPages);
        }
      },
    );
  }

  Widget _buildTxtViewer() {
    return FutureBuilder<String>(
      future: File(widget.filePath).readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  snapshot.data!,
                  style: TextStyle(fontSize: fs(context, 16, 'sentences')),
                ),
              ),
            );
          } else {
            return const Center(child: Text('Error loading text file'));
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildMangaViewer() {
    if (_mangaLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading images...'),
          ],
        ),
      );
    }

    if (_mangaError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_mangaError'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMangaImages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_mangaPagePaths.isEmpty) {
      return const Center(child: Text('No images found'));
    }

    if (widget.isMangaMode || _isVerticalScroll) {
      return _buildVerticalMangaViewer();
    }

    return _buildHorizontalMangaViewer();
  }

  Widget _buildHorizontalMangaViewer() {
    return Stack(
      children: [
        PageView.builder(
          controller: _mangaPageController,
          reverse: widget.isMangaMode,
          itemCount: _totalPages,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index + 1;
            });
            if (widget.onPageChanged != null) {
              widget.onPageChanged!(_currentPage, _totalPages);
            }
          },
          itemBuilder: (context, index) {
            return FutureBuilder<Uint8List?>(
              future: _loadPage(index + 1),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: widgets.Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_currentPage/$_totalPages',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalMangaViewer() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Page $_currentPage/$_totalPages'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.swap_vert),
                onPressed: () {
                  setState(() {
                    _isVerticalScroll = !_isVerticalScroll;
                  });
                },
                tooltip: 'Toggle scroll direction',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              return FutureBuilder<Uint8List?>(
                future: _loadPage(index + 1),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: widgets.Image.memory(
                        snapshot.data!,
                        fit: BoxFit.fitWidth,
                        width: double.infinity,
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFb2Viewer() {
    return FutureBuilder<String>(
      future: File(widget.filePath).readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            final htmlContent = _convertFb2ToHtml(snapshot.data!);
            return Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  _stripHtml(htmlContent),
                  style: TextStyle(fontSize: fs(context, 16, 'sentences')),
                ),
              ),
            );
          } else {
            return const Center(child: Text('Error loading FB2 file'));
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  String _convertFb2ToHtml(String fb2Content) {
    final titleMatch = RegExp(
      r'<book-title>([^<]+)</book-title>',
    ).firstMatch(fb2Content);
    final title = titleMatch?.group(1) ?? 'Book';

    String body = fb2Content
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return '$title\n\n$body';
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  void goToPreviousPage() {
    if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
      if (_currentPage > 1) {
        _pdfViewerController!.previousPage();
      }
    } else if (_documentType == DocumentType.manga ||
        _documentType == DocumentType.cbz ||
        _documentType == DocumentType.folder) {
      if (_currentPage > 1) {
        _mangaPageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_documentType == DocumentType.epub && _currentPage > 1) {
      // epub navigation
    }
  }

  void goToNextPage() {
    if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
      if (_currentPage < _totalPages) {
        _pdfViewerController!.nextPage();
      }
    } else if (_documentType == DocumentType.manga ||
        _documentType == DocumentType.cbz ||
        _documentType == DocumentType.folder) {
      if (_currentPage < _totalPages) {
        _mangaPageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_documentType == DocumentType.epub &&
        _currentPage < _totalPages) {
      // epub navigation
    }
  }

  void goToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _totalPages) {
      if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
        _pdfViewerController!.jumpToPage(pageNumber);
      } else if (_documentType == DocumentType.manga ||
          _documentType == DocumentType.cbz ||
          _documentType == DocumentType.folder) {
        _mangaPageController.jumpToPage(pageNumber - 1);
      }
    }
  }

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
}

enum DocumentType { pdf, epub, txt, manga, cbz, folder, fb2 }
