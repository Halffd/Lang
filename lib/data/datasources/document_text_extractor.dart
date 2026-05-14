import 'dart:io';

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
    throw UnimplementedError('PDF extraction requires syncfusion_flutter_pdf package');
  }

  Future<String> _extractFromTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsString();
  }
}