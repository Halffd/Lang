import 'dictionary_service.dart';
import 'package:lang/domain/entities/dictionary.dart';
import '../datasources/radical_data.dart';
import '../datasources/kanji_decomposition_data.dart';

class RadicalSearchResult {
  final String character;
  final KanjiEntry? kanjiEntry;
  final KanjiDecomposition? decomposition;

  RadicalSearchResult({
    required this.character,
    this.kanjiEntry,
    this.decomposition,
  });
}

class RadicalSearchService {
  final DictionaryService _dictionaryService;
  List<String>? _allKanjiCharacters;

  RadicalSearchService(this._dictionaryService);

  Future<List<String>> _getAllKanjiCharacters() async {
    if (_allKanjiCharacters != null) return _allKanjiCharacters!;

    final results = await _dictionaryService.searchKanji('一');
    final db = await _dictionaryService.yomichanDatabase;
    final rows = await db.query('kanji', columns: ['character']);
    _allKanjiCharacters = rows.map((r) => r['character'] as String).toList();
    return _allKanjiCharacters!;
  }

  Future<List<RadicalSearchResult>> searchByRadicals(List<KangxiRadical> selectedRadicals) async {
    if (selectedRadicals.isEmpty) return [];

    final allKanji = await _getAllKanjiCharacters();
    final allDecompKanji = KanjiDecompositionData.allKanji;
    final combined = <String>{...allKanji, ...allDecompKanji};

    final radicalChars = selectedRadicals.map((r) => r.displayChar).toList();
    final radicalVariants = <String>{};
    for (final r in selectedRadicals) {
      radicalVariants.add(r.character);
      radicalVariants.add(r.displayChar);
      radicalVariants.addAll(r.variants);
    }

    final matching = <String>[];
    for (final kanji in combined) {
      if (kanji.length != 1) continue;

      bool allMatch = true;
      for (final rc in radicalChars) {
        if (!kanji.contains(rc) && !radicalVariants.any((v) => kanji.contains(v))) {
          final decomp = KanjiDecompositionData.getComponents(kanji);
          if (!decomp.contains(rc) && !decomp.any((c) => radicalVariants.contains(c))) {
            allMatch = false;
            break;
          }
        }
      }
      if (allMatch) matching.add(kanji);
    }

    final results = <RadicalSearchResult>[];
    for (final char in matching.take(100)) {
      final kanjiEntry = await _getKanjiEntry(char);
      final decomp = KanjiDecompositionData.getDecomposition(char);
      results.add(RadicalSearchResult(
        character: char,
        kanjiEntry: kanjiEntry,
        decomposition: decomp,
      ));
    }
    return results;
  }

  Future<List<RadicalSearchResult>> searchByComponents(List<String> components) async {
    if (components.isEmpty) return [];

    final fromDecomp = KanjiDecompositionData.findKanjiByComponents(components);
    final allKanji = await _getAllKanjiCharacters();

    final additional = <String>[];
    for (final kanji in allKanji) {
      if (kanji.length != 1) continue;
      if (fromDecomp.contains(kanji)) continue;
      bool allMatch = true;
      for (final comp in components) {
        if (!kanji.contains(comp)) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) additional.add(kanji);
    }

    final combined = <String>[...fromDecomp, ...additional];
    final results = <RadicalSearchResult>[];
    for (final char in combined.take(100)) {
      final kanjiEntry = await _getKanjiEntry(char);
      final decomp = KanjiDecompositionData.getDecomposition(char);
      results.add(RadicalSearchResult(
        character: char,
        kanjiEntry: kanjiEntry,
        decomposition: decomp,
      ));
    }
    return results;
  }

  Future<List<RadicalSearchResult>> decomposeAndSearch(String character) async {
    if (character.isEmpty) return [];

    final targetChar = character.length == 1 ? character : character[0];
    final components = KanjiDecompositionData.getComponents(targetChar);

    if (components.isEmpty) {
      final allKanji = await _getAllKanjiCharacters();
      final similar = <String>[];
      for (final k in allKanji) {
        if (k.length != 1 || k == targetChar) continue;
        for (final rc in RadicalData.all) {
          if (targetChar.contains(rc.displayChar) && k.contains(rc.displayChar)) {
            similar.add(k);
            break;
          }
        }
      }
      return _buildResults(similar);
    }

    final similar = KanjiDecompositionData.findKanjiByAnyComponent(components)
        .where((k) => k != targetChar)
        .toList();

    return _buildResults(similar);
  }

  Future<List<RadicalSearchResult>> _buildResults(List<String> characters) async {
    final results = <RadicalSearchResult>[];
    for (final char in characters.take(100)) {
      final kanjiEntry = await _getKanjiEntry(char);
      final decomp = KanjiDecompositionData.getDecomposition(char);
      results.add(RadicalSearchResult(
        character: char,
        kanjiEntry: kanjiEntry,
        decomposition: decomp,
      ));
    }
    return results;
  }

  Future<KanjiEntry?> _getKanjiEntry(String character) async {
    try {
      final results = await _dictionaryService.searchKanji(character);
      if (results.isNotEmpty) {
        return results.first.kanji;
      }
    } catch (_) {}
    return null;
  }

  void invalidateCache() {
    _allKanjiCharacters = null;
  }
}
