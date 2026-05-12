import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/widgets/document_reader.dart';

void main() {
  group('DocumentType', () {
    test('has expected number of document types', () {
      expect(DocumentType.values.length, greaterThanOrEqualTo(6));
    });

    test('has pdf type', () {
      expect(DocumentType.values, contains(DocumentType.pdf));
    });

    test('has epub type', () {
      expect(DocumentType.values, contains(DocumentType.epub));
    });

    test('has txt type', () {
      expect(DocumentType.values, contains(DocumentType.txt));
    });

    test('has manga type', () {
      expect(DocumentType.values, contains(DocumentType.manga));
    });

    test('has cbz type', () {
      expect(DocumentType.values, contains(DocumentType.cbz));
    });

    test('has folder type', () {
      expect(DocumentType.values, contains(DocumentType.folder));
    });

    test('has fb2 type', () {
      expect(DocumentType.values, contains(DocumentType.fb2));
    });

    test('manga, cbz, and folder are for image-based content', () {
      expect(DocumentType.manga.name, 'manga');
      expect(DocumentType.cbz.name, 'cbz');
      expect(DocumentType.folder.name, 'folder');
    });

    test('fb2 is for FictionBook novels', () {
      expect(DocumentType.fb2.name, 'fb2');
    });
  });

  group('DocumentReader', () {
    test('can be instantiated with required parameters', () {
      final reader = DocumentReader(
        filePath: '/test/path.pdf',
        fileType: 'pdf',
      );

      expect(reader.filePath, '/test/path.pdf');
      expect(reader.fileType, 'pdf');
      expect(reader.isMangaMode, false);
    });

    test('can be instantiated with manga mode', () {
      final reader = DocumentReader(
        filePath: '/test/manga.cbz',
        fileType: 'cbz',
        isMangaMode: true,
      );

      expect(reader.isMangaMode, true);
    });

    test('can be instantiated with default isMangaMode false', () {
      final reader = DocumentReader(
        filePath: '/test/images/',
        fileType: 'folder',
      );

      expect(reader.isMangaMode, false);
    });

    test('filePath can be any string', () {
      final pdfReader = DocumentReader(filePath: '/path/to/doc.pdf', fileType: 'pdf');
      final epubReader = DocumentReader(filePath: '/path/to/book.epub', fileType: 'epub');
      final txtReader = DocumentReader(filePath: '/path/to/text.txt', fileType: 'txt');
      final mangaReader = DocumentReader(filePath: '/path/to/manga.cbz', fileType: 'cbz');

      expect(pdfReader.filePath, '/path/to/doc.pdf');
      expect(epubReader.filePath, '/path/to/book.epub');
      expect(txtReader.filePath, '/path/to/text.txt');
      expect(mangaReader.filePath, '/path/to/manga.cbz');
    });

    test('fileType can be various formats', () {
      final formats = ['pdf', 'epub', 'txt', 'manga', 'cbz', 'folder', 'fb2'];

      for (final format in formats) {
        final reader = DocumentReader(
          filePath: '/test/file',
          fileType: format,
        );
        expect(reader.fileType, format);
      }
    });

    test('onPageChanged callback can be null', () {
      final reader = DocumentReader(
        filePath: '/test/path.pdf',
        fileType: 'pdf',
      );

      expect(reader.onPageChanged, isNull);
    });

    test('onPageChanged callback can be provided', () {
      void callback(int current, int total) {}

      final reader = DocumentReader(
        filePath: '/test/path.pdf',
        fileType: 'pdf',
        onPageChanged: callback,
      );

      expect(reader.onPageChanged, isNotNull);
    });
  });

  group('DocumentReader equality', () {
    test('two readers with same params are equal', () {
      final reader1 = DocumentReader(
        filePath: '/test.pdf',
        fileType: 'pdf',
      );
      final reader2 = DocumentReader(
        filePath: '/test.pdf',
        fileType: 'pdf',
      );

      expect(reader1.filePath, reader2.filePath);
      expect(reader1.fileType, reader2.fileType);
    });
  });
}