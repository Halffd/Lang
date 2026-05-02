import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocumentTextExtractor {
  Future<String> extractText(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return _extractFromPdf(filePath);
      case 'txt':
        return _extractFromTxt(filePath);
      default:
        throw UnsupportedError('Unsupported file type: .$extension');
    }
  }

  Future<String> _extractFromPdf(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    final text = extractor.extractText();
    doc.dispose();
    return text.trim();
  }

  Future<String> _extractFromTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsString();
  }
}
