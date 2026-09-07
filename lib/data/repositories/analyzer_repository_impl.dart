import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/audio_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/repositories/analyzer_repository.dart';
import '../datasources/analysis_remote_data_source.dart';
import '../datasources/dictionary_local_data_source.dart';
import '../datasources/dictionary_remote_data_source.dart';
import '../datasources/kanji_remote_data_source.dart';
import '../datasources/note_local_data_source.dart';
import '../datasources/remote/mdbg_service.dart';

class AnalyzerRepositoryImpl implements AnalyzerRepository {
  final AnalysisRemoteDataSource analysisRemoteDataSource;
  final DictionaryLocalDataSource dictionaryLocalDataSource;
  final DictionaryRemoteDataSource dictionaryRemoteDataSource;
  final KanjiRemoteDataSource kanjiRemoteDataSource;
  final NoteLocalDataSource noteLocalDataSource;
  final AudioService audioService;
  final MdbgService mdbgService;

  AnalyzerRepositoryImpl({
    required this.analysisRemoteDataSource,
    required this.dictionaryLocalDataSource,
    required this.dictionaryRemoteDataSource,
    required this.kanjiRemoteDataSource,
    required this.noteLocalDataSource,
    required this.audioService,
    MdbgService? mdbgService,
  }) : mdbgService = mdbgService ?? MdbgService();

  @override
  Future<void> init() async {
    await dictionaryLocalDataSource.init();
    await noteLocalDataSource.init();
    await audioService.init();
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'itemsPerRow': prefs.getInt('itemsPerRow') ?? 2,
      'itemsPerPage': prefs.getInt('itemsPerPage') ?? 50,
      'showIchiMoe': prefs.getBool('showIchiMoe') ?? true,
      'showWiktionary': prefs.getBool('showWiktionary') ?? true,
      'showKanji': prefs.getBool('showKanji') ?? true,
      'showEtymology': prefs.getBool('showEtymology') ?? true,
      'searchLimit': prefs.getInt('searchLimit') ?? 100,
    };
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    settings.forEach((key, value) {
      if (value is int) prefs.setInt(key, value);
      if (value is bool) prefs.setBool(key, value);
      if (value is String) prefs.setString(key, value);
    });
  }

  @override
  Future<List<String>> tokenizeText(String text, String lang) {
    return analysisRemoteDataSource.tokenize(text, lang);
  }

  @override
  Map<String, String> splitSentences(List<String> tokens) {
    return analysisRemoteDataSource.splitIntoSentences(tokens);
  }

  @override
  Future<List<AnalyzedWord>> lookupWord(String query, String lang) async {
    final localResults = await dictionaryLocalDataSource.lookupTerms(query);
    if (localResults.isEmpty) return [];

    return await Future.wait(localResults.map((entry) async {
      return enrichWord(
        entry['expression'],
        lang,
        showIchiMoe: true,
        showWiktionary: true,
        showKanji: true,
        showEtymology: true,
      );
    }));
  }

  @override
  Future<AnalyzedWord> enrichWord(String word, String lang, {
    bool showIchiMoe = true,
    bool showWiktionary = true,
    bool showKanji = true,
    bool showEtymology = true,
  }) async {
    int? freq;
    List<Map<String, dynamic>> localDefs = [];
    List<String> moeDefs = [];
    String? wikiHtml;
    List<String> kanjiList = [];
    Map<String, dynamic> kanjiDetails = {};
    Map<String, Map<String, String>> kanjipediaData = {};
    MdbgData? mdbgData;

    // 1. Local Lookup
    localDefs = await dictionaryLocalDataSource.lookupTerms(word);

    // 2. Frequency (Local -> Remote)
    freq = await dictionaryLocalDataSource.getFrequency(word);
    freq ??= await dictionaryRemoteDataSource.getFrequency(word, lang);

    // 3. ichi.moe (Japanese only)
    if (lang == 'ja' && showIchiMoe) {
      moeDefs = await dictionaryRemoteDataSource.ichiMoeLookup(word);
    }

    // 4. MDBG (Chinese only)
    if (lang == 'zh') {
      final mdbgEntry = await mdbgService.lookupWord(word);
      if (mdbgEntry != null) {
        mdbgData = MdbgData(
          pinyin: mdbgEntry.pinyin,
          definitions: mdbgEntry.definitions,
          traditional: mdbgEntry.traditional,
          simplified: mdbgEntry.simplified,
        );
      }
    }

    // 5. Wiktionary
    if (showWiktionary) {
      wikiHtml = await dictionaryRemoteDataSource.wiktionaryLookup(word, lang);
    }

    // 5. Kanji Analysis
    kanjiList = kanjiRemoteDataSource.extractKanji(word);
    if (showKanji) {
      for (var k in kanjiList) {
        final details = await kanjiRemoteDataSource.getKanjiDetails(k);
        if (details != null) {
          kanjiDetails[k] = details;
        }
        if (showEtymology && lang == 'ja') {
          final etym = await kanjiRemoteDataSource.getKanjipediaEtymology(k);
          if (etym != null) {
            kanjipediaData[k] = etym;
          }
        }
      }
    }

    return AnalyzedWord(
      word: word,
      frequency: freq,
      localDefinitions: localDefs,
      ichiMoeDefinitions: moeDefs,
      wiktionaryHtml: wikiHtml,
      kanjiList: kanjiList,
      kanjiDetails: kanjiDetails,
      kanjipediaData: kanjipediaData,
      mdbgData: mdbgData,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getInstalledDictionaries() {
    return dictionaryLocalDataSource.getDictionaries();
  }

  @override
  Future<void> importDictionary(Uint8List bytes) {
    return dictionaryLocalDataSource.importDictionaryArchive(bytes);
  }

  @override
  Future<void> deleteDictionary(String title) {
    return dictionaryLocalDataSource.deleteDictionary(title);
  }

  @override
  Future<void> saveWord(String word, {String? sentence}) async {
    await noteLocalDataSource.addWord(word, sentence: sentence);
  }

  @override
  Future<void> removeSavedWord(String word) async {
    await noteLocalDataSource.removeWord(word);
  }

  @override
  Future<List<Map<String, dynamic>>> getSavedWords() async {
    return await noteLocalDataSource.getSavedEntries();
  }

  @override
  Future<bool> isWordSaved(String word) async {
    return await noteLocalDataSource.isKnown(word);
  }

  @override
  Future<List<String>> getHistory() async {
    return await noteLocalDataSource.getHistory();
  }

  @override
  Future<void> addToHistory(String word) async {
    await noteLocalDataSource.addToHistory(word);
  }

  @override
  Future<void> playAudio(String text, String lang) async {
    return audioService.play(text, lang);
  }
}
