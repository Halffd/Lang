// AppDatabase (drift) in-memory: entry search paths, batch
// inserts, tone queries, word occurrence tracking.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/core/services/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    await db.insertBatch([
      DriftDictionaryEntriesCompanion.insert(
        term: '読む',
        reading: const Value('よむ'),
        definitions: '["to read"]',
      ),
      DriftDictionaryEntriesCompanion.insert(
        term: '読書',
        reading: const Value('どくしょ'),
        definitions: '["reading books"]',
      ),
      DriftDictionaryEntriesCompanion.insert(
        term: '本',
        reading: const Value('ほん'),
        definitions: '["book"]',
      ),
    ]);
  }

  group('entry search', () {
    test('searchByTerm matches substring', () async {
      await seed();
      final hits = await db.searchByTerm('読');
      expect(hits.length, 2);
      expect(hits.map((e) => e.term), containsAll(['読む', '読書']));
    });

    test('searchByReading matches kana', () async {
      await seed();
      final hits = await db.searchByReading('しょ');
      expect(hits.length, 1);
      expect(hits.first.term, '読書');
    });

    test('searchBoth unions term+reading', () async {
      await seed();
      final byTermReading = await db.searchBoth('よむ');
      expect(byTermReading.map((e) => e.term), contains('読む'));
      final byKanji = await db.searchBoth('本');
      expect(byKanji.map((e) => e.term), contains('本'));
    });

    test('searchBoth empty query returns empty', () async {
      await seed();
      expect(await db.searchBoth(''), isEmpty);
    });

    test('getByTerm exact match', () async {
      await seed();
      final entry = await db.getByTerm('本');
      expect(entry, isNotNull);
      expect(entry!.reading, 'ほん');
      expect(await db.getByTerm('不在'), isNull);
    });

    test('search limit 50', () async {
      await db.insertBatch([
        for (var i = 0; i < 60; i++)
          DriftDictionaryEntriesCompanion.insert(
            term: '項$i',
            definitions: '[]',
          ),
      ]);
      expect((await db.searchByTerm('項')).length, 50);
    });
  });

  group('tones', () {
    test('insert + query by term and language', () async {
      await db.insertTone(
        DriftTonesCompanion.insert(
          dictionaryId: 1,
          term: '妈',
          reading: 'ma',
          language: 'mandarin',
          tones: '[1]',
        ),
      );
      await db.insertTone(
        DriftTonesCompanion.insert(
          dictionaryId: 1,
          term: '妈',
          reading: 'maa',
          language: 'cantonese',
          tones: '[3]',
        ),
      );

      final all = await db.getTonesByTerm('妈');
      expect(all.length, 2);

      final mando = await db.getTonesByTermAndLanguage('妈', 'mandarin');
      expect(mando.length, 1);
      expect(mando.first.tones, '[1]');
    });
  });

  group('word occurrences', () {
    test('batch insert, frequencies, clear', () async {
      await db.insertWordOccurrences([
        WordOccurrencesCompanion.insert(
          word: '読む',
          position: 0,
          sentenceId: const Value(1),
        ),
        WordOccurrencesCompanion.insert(
          word: '読む',
          position: 5,
          sentenceId: const Value(1),
        ),
        WordOccurrencesCompanion.insert(
          word: '本',
          position: 2,
          sentenceId: const Value(1),
        ),
      ]);

      final freqs = await db.getWordFrequencies();
      expect(freqs.length, 2);
      expect(freqs.first.word, '読む'); // 2 occurrences -> first
      expect(freqs.first.count, 2);
      expect(freqs.first.firstOccurrence, 0);
      expect(freqs[1].word, '本');

      // clear removes everything
      await db.clearWordOccurrences();
      expect(await db.getWordFrequencies(), isEmpty);
    });
  });
}
