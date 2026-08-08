import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';

class DocumentTextExtractor {
  Future<ExtractedDocument> extractDocument(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return _extractFromPdf(filePath);
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

  Future<String> _extractFromTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsString();
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