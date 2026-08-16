import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import 'package:epubx/epubx.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class DocumentTextExtractor {
  Future<ExtractedDocument> extractDocument(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return _extractFromPdf(filePath);
      case 'epub':
        return _extractFromEpub(filePath);
      case 'cbr':
        return _extractFromCbr(filePath);
      case 'txt':
        final text = await _extractFromTxt(filePath);
        return ExtractedDocument(text: text);
      default:
        throw UnsupportedError('Unsupported file type: .$extension');
    }
  }

  Future<ExtractedDocument> _extractFromPdf(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    try {
      final pdfDocument = await PdfDocument.openFile(filePath);
      
      // Extract text from all pages
      final textBuffer = StringBuffer();
      final pageCount = pdfDocument.pagesCount;
      
      for (int i = 1; i <= pageCount; i++) {
        final page = await pdfDocument.getPage(i);
        final text = await page.getText();
        textBuffer.write(text);
        textBuffer.write('\n\n');
        await page.close();
      }
      
      // Extract cover image from first page
      Uint8List? coverImage;
      try {
        final firstPage = await pdfDocument.getPage(1);
        final pageImage = await firstPage.render(
          width: 400,
          height: 550,
          format: PdfPageImageFormat.png,
        );
        coverImage = pageImage.bytes;
        await firstPage.close();
      } catch (e) {
        debugPrint('Failed to extract cover image: $e');
      }
      
      await pdfDocument.close();
      
      return ExtractedDocument(
        text: textBuffer.toString(),
        coverImage: coverImage,
        pageCount: pageCount,
      );
    } catch (e) {
      throw Exception('Failed to extract PDF: $e');
    }
  }

  Future<ExtractedDocument> _extractFromEpub(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    try {
      // Use the epub package to read the book
      final epubBook = await EpubReader.readBook(filePath);
      
      // Extract text from all chapters
      final textBuffer = StringBuffer();
      int pageCount = 0;
      
      for (final chapter in epubBook.Chapters) {
        pageCount++;
        final content = chapter.HtmlContent;
        if (content != null && content.isNotEmpty) {
          // Parse HTML content and extract text
          final text = _extractTextFromHtml(content);
          textBuffer.write(text);
          textBuffer.write('\n\n');
        }
      }
      
      // Extract cover image
      Uint8List? coverImage;
      try {
        if (epubBook.CoverImage != null) {
          coverImage = epubBook.CoverImage!.Content;
        }
      } catch (e) {
        debugPrint('Failed to extract EPUB cover: $e');
      }
      
      return ExtractedDocument(
        text: textBuffer.toString(),
        coverImage: coverImage,
        pageCount: pageCount,
      );
    } catch (e) {
      throw Exception('Failed to extract EPUB: $e');
    }
  }

  Future<ExtractedDocument> _extractFromCbr(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    try {
      // CBR is a RAR archive containing images
      final bytes = await file.readAsBytes();
      final archive = RarDecoder().decodeBytes(bytes);
      
      // Get all image files and sort them
      final imageFiles = archive.files
          .where((f) => _isImageFile(f.name))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      
      if (imageFiles.isEmpty) {
        throw Exception('No images found in CBR archive');
      }
      
      final pageCount = imageFiles.length;
      
      // For CBR, we don't extract text (it's images), but we can extract cover
      Uint8List? coverImage;
      if (imageFiles.isNotEmpty) {
        coverImage = imageFiles.first.content as Uint8List?;
      }
      
      return ExtractedDocument(
        text: '[Comic Book Archive - ' + imageFiles.length.toString() + ' pages]',
        coverImage: coverImage,
        pageCount: pageCount,
      );
    } catch (e) {
      throw Exception('Failed to extract CBR: $e');
    }
  }

  Future<String> _extractFromTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsString();
  }

  String _extractTextFromHtml(String html) {
    // Simple HTML tag removal
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isImageFile(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff'].contains(ext);
  }
}

class ExtractedDocument {
  final String text;
  final Uint8List? coverImage;
  final int pageCount;

  ExtractedDocument({
    required this.text,
    this.coverImage,
    this.pageCount = 0,
  });
}