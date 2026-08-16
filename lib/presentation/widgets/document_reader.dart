import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import 'package:advance_pdf_viewer/advance_pdf_viewer.dart';
import 'package:archive/archive.dart';

typedef OnPageChangedCallback = void Function(int currentPage, int totalPages);

class DocumentReader extends StatefulWidget {
  final String filePath;
  final String fileType;
  final OnPageChangedCallback? onPageChanged;
  final bool isMangaMode;

  const DocumentReader({
    Key? key,
    required this.filePath,
    required this.fileType,
    this.onPageChanged,
    this.isMangaMode = false,
  }) : super(key: key);

  @override
  State<DocumentReader> createState() => DocumentReaderState();
}

class DocumentReaderState extends State<DocumentReader> {
  late DocumentType _documentType;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfViewerController? _pdfViewerController;
  EpubController? _epubController;

  List<Uint8List> _mangaPages = [];
  bool _mangaLoading = true;
  String? _mangaError;
  final PageController _mangaPageController = PageController();
  bool _isVerticalScroll = false;

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
      List<Uint8List> pages = [];

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
            pages.add(await file.readAsBytes());
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

          for (final archiveFile in imageFiles) {
            if (archiveFile.isFile) {
              pages.add(Uint8List.fromList(archiveFile.content as List<int>));
            }
          }
        }
      }

      setState(() {
        _mangaPages = pages;
        _totalPages = pages.length;
        _mangaLoading = false;
        if (_totalPages > 0) {
          _currentPage = 1;
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
      default:
        return const Center(child: Text('Unsupported document type'));
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
                  style: const TextStyle(fontSize: 16),
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

    if (_mangaPages.isEmpty) {
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
          itemCount: _mangaPages.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index + 1;
            });
            if (widget.onPageChanged != null) {
              widget.onPageChanged!(_currentPage, _totalPages);
            }
          },
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: widgets.Image.memory(
                _mangaPages[index],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
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
                '${_currentPage}/${_totalPages}',
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
              Text('Page ${_currentPage}/${_totalPages}'),
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
            itemCount: _mangaPages.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: widgets.Image.memory(
                  _mangaPages[index],
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
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
                  style: const TextStyle(fontSize: 16),
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
