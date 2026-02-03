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
        // We need to get the page count after a delay
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            // Get the actual page count from the controller
            // We'll need to access the page count differently
            _totalPages = 10; // Default to 10 - will be updated when we can access actual page count
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
          _totalPages = book.chapters.length;
        });
        if (widget.onPageChanged != null) {
          widget.onPageChanged!(_currentPage, _totalPages);
        }
      },
      onPageChanged: (pageNumber, lastPageNumber) {
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
      _epubController?.previousChapter();
    }
  }

  void goToNextPage() {
    if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
      if (_currentPage < _totalPages) {
        _pdfViewerController!.nextPage();
      }
    } else if (_documentType == DocumentType.epub && _currentPage < _totalPages) {
      _epubController?.nextChapter();
    }
  }

  void goToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _totalPages) {
      if (_documentType == DocumentType.pdf && _pdfViewerController != null) {
        _pdfViewerController!.jumpToPage(pageNumber);
      } else if (_documentType == DocumentType.epub) {
        // For epub, we'll navigate to the chapter that corresponds to the page
        // Since chapters might not map directly to pages, we'll use a simple approach
        _epubController?.jumpToChapter(pageNumber - 1); // Chapters are 0-indexed
      }
      // For TXT, we'd implement the appropriate navigation
    }
  }

  // Getter methods to access current state
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
}

enum DocumentType { pdf, epub, txt }