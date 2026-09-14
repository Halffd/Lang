// Anki .apkg round trip: exportDeck -> importPackage through real
// sqlite3 bytes, zip archive and the anki db schema. Guards the
// row/column access in the importer.

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/anki_package_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';

class _MemStorage extends StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is List) return value.cast<String>();
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export then import returns the same cards', () async {
    final storage = _MemStorage();
    final srs = SRSService(storage);
    await srs.initialize();

    await srs.addCard(
      SRSCard.newCard(
        id: 'rt_1',
        word: '読む',
        reading: 'よむ',
        meaning: 'to read',
      ),
    );
    await srs.addCard(
      SRSCard.newCard(
        id: 'rt_2',
        word: '書く',
        reading: 'かく',
        meaning: 'to write',
      ),
    );

    final service = AnkiPackageService(srsService: srs);
    final bytes = await service.exportDeck(deckName: 'RoundTrip');

    final imported = await service.importPackage(bytes);

    expect(imported.length, 2);
    final byWord = {for (final c in imported) c.word: c};
    expect(byWord['読む'], isNotNull);
    expect(byWord['読む']!.reading, 'よむ');
    expect(byWord['読む']!.meaning, contains('read'));
    expect(byWord['書く'], isNotNull);
    // ids are namespaced by the importer
    expect(imported.every((c) => c.id.startsWith('anki_')), isTrue);
  });

  test('import merges into the service without duplicates', () async {
    final storage = _MemStorage();
    final srs = SRSService(storage);
    await srs.initialize();

    await srs.addCard(
      SRSCard.newCard(
        id: 'rt_1',
        word: '読む',
        reading: 'よむ',
        meaning: 'to read',
      ),
    );

    final service = AnkiPackageService(srsService: srs);
    final bytes = await service.exportDeck(deckName: 'Dup');
    await service.importAndMerge(bytes);

    // same word twice, different ids (namespaced import id)
    expect(srs.allCards.length, 2);
  });
}
