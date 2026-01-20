import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart';
import 'package:advance_pdf_viewer/advance_pdf_viewer.dart';

typedef OnPageChangedCallback = void Function(int currentPage, int totalPages);

class DocumentReader extends StatefulWidget {
  final String filePath;
  final String fileType; // 'pdf', 'epub', or 'txt'
  final OnPageChangedCallback? onPageChanged;

  const DocumentReader({
    Key? key,
    required this.filePath,
    required this.fileType,
    this.onPageChanged,
  }) : super(key: key);

  @override
  State<DocumentReader> createState() => _DocumentReaderState();
}

class _DocumentReaderState extends State<DocumentReader> {
  late DocumentType _documentType;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfViewerController? _pdfViewerController;
  EpubController? _epubController;

  @override
  void initState() {
    super.initState();
    _documentType = _getDocumentType(widget.fileType);
    if (_documentType == DocumentType.pdf) {
      _pdfViewerController = PdfViewerController();
    }
  }

  DocumentType _getDocumentType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return DocumentType.pdf;
      case 'epub':
        return DocumentType.epub;
      case 'txt':
        return DocumentType.txt;
      default:
        return DocumentType.txt;
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
      default:
        return const Center(child: Text('Unsupported document type'));
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(widget.filePath),
      controller: _pdfViewerController,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        // Update total pages after document is loaded
        // We need to get the page count from the controller after a delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Get the actual page count
          final document = SfPdfViewer.file(File(widget.filePath));
          setState(() {
            // Unfortunately, we can't directly access the page count from the controller
            // So we'll need to use a workaround to get the page count
            _totalPages = 10; // Placeholder - actual implementation would get the real page count
          });
          if (widget.onPageChanged != null) {
            widget.onPageChanged!(_currentPage, _totalPages);
          }
        });
      },
      onPageChanged: (int previousPageNumber, int newPageNumber) {
        setState(() {
          _currentPage = newPageNumber;
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
          _totalPages = book.chapters.length;
        });
        if (widget.onPageChanged != null) {
          widget.onPageChanged!(_currentPage, _totalPages);
        }
      },
      onPageChanged: (pageNumber) {
        setState(() {
          _currentPage = pageNumber;
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

  // Public navigation methods that can be accessed from parent widgets
  void goToPreviousPage() {
    if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
      if (_currentPage > 1) {
        _pdfViewerController!.previousPage();
      }
    } else if (_documentType == DocumentType.epub && _currentPage > 1) {
      _epubController?.jumpToChapter(_currentPage - 1);
    }
  }

  void goToNextPage() {
    if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
      if (_currentPage < _totalPages) {
        _pdfViewerController!.nextPage();
      }
    } else if (_documentType == DocumentType.epub && _currentPage < _totalPages) {
      _epubController?.jumpToChapter(_currentPage + 1);
    }
  }

  void goToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _totalPages) {
      if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
        _pdfViewerController!.jumpToPage(pageNumber);
      } else if (_documentType == DocumentType.epub) {
        _epubController?.jumpToChapter(pageNumber);
      }
      // For TXT, we'd implement the appropriate navigation
    }
  }

  // Getter methods to access current state
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
}

enum DocumentType { pdf, epub, txt }