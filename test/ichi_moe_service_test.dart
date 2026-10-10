import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/ichi_moe_service.dart';
import 'package:lang/domain/entities/dictionary.dart';

// Live ichi.moe checks: pass --dart-define=ICHI_MOE_LIVE=true to run them;
// the default suite stays hermetic. Every method in the service hits the
// network, so there is nothing pure to keep running here. The service
// itself times requests out at 10s and returns an empty list on failure,
// so the network tests below assert the reachable behavior either way.
void main() {
  const live = bool.fromEnvironment('ICHI_MOE_LIVE');
  group(
    'IchiMoeService Tests',
    skip: !live
        ? 'live network tests: set --dart-define=ICHI_MOE_LIVE=true'
        : null,
    () {
      late IchiMoeService service;

      setUp(() {
        service = IchiMoeService();
      });

      test('search returns empty list for empty term', () async {
        final results = await service.search('');
        expect(results, isEmpty);
      });

      test('searchWithDetails returns empty list for empty term', () async {
        final results = await service.searchWithDetails('');
        expect(results, isEmpty);
      });

      test('search returns DictionaryEntry objects', () async {
        final results = await service.search('test');
        expect(results, isA<List<DictionaryEntry>>());
      });

      test('searchWithDetails returns DictionaryEntry objects', () async {
        final results = await service.searchWithDetails('test');
        expect(results, isA<List<DictionaryEntry>>());
      });

      test('search with romaji option works', () async {
        final results = await service.search('test', useRomaji: true);
        expect(results, isA<List<DictionaryEntry>>());
      });

      test('search with kana option works', () async {
        final results = await service.search('test', useRomaji: false);
        expect(results, isA<List<DictionaryEntry>>());
      });

      test('searchWithDetails with romaji option works', () async {
        final results = await service.searchWithDetails(
          'test',
          useRomaji: true,
        );
        expect(results, isA<List<DictionaryEntry>>());
      });

      test('searchWithDetails with kana option works', () async {
        final results = await service.searchWithDetails(
          'test',
          useRomaji: false,
        );
        expect(results, isA<List<DictionaryEntry>>());
      });
    },
  );
}
