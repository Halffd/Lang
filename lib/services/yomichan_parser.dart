import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import '../models/dictionary.dart';
import 'database.dart';

class YomichanParser {
  final File zipFile;
  Archive? _archive;
  
  YomichanParser(this.zipFile);
  
  Future<void> loadArchive() async {
    final bytes = await zipFile.readAsBytes();
    _archive = ZipDecoder().decodeBytes(bytes);
  }
  
  Future<Map<String, dynamic>> getIndex() async {
    final indexFile = _archive!.findFile('index.json');
    if (indexFile == null) {
      throw Exception('index.json not found in dictionary');
    }
    
    final content = utf8.decode(indexFile.content as List<int>);
    return jsonDecode(content) as Map<String, dynamic>;
  }
  
  Future<List<List<dynamic>>> parseTermBanks() async {
    final allTerms = <List<dynamic>>[];
    
    for (final file in _archive!.files) {
      if (file.name.startsWith('term_bank_') && file.name.endsWith('.json')) {
        final content = utf8.decode(file.content as List<int>);
        final bank = jsonDecode(content) as List<dynamic>;
        allTerms.addAll(bank.cast<List<dynamic>>());
      }
    }
    
    return allTerms;
  }
  
  Future<List<List<dynamic>>> parseKanjiBanks() async {
    final allKanji = <List<dynamic>>[];
    
    for (final file in _archive!.files) {
      if (file.name.startsWith('kanji_bank_') && file.name.endsWith('.json')) {
        final content = utf8.decode(file.content as List<int>);
        final bank = jsonDecode(content) as List<dynamic>;
        allKanji.addAll(bank.cast<List<dynamic>>());
      }
    }
    
    return allKanji;
  }
  
  Future<List<List<dynamic>>> parseTagBanks() async {
    final allTags = <List<dynamic>>[];
    
    for (final file in _archive!.files) {
      if (file.name.startsWith('tag_bank_') && file.name.endsWith('.json')) {
        final content = utf8.decode(file.content as List<int>);
        final bank = jsonDecode(content) as List<dynamic>;
        allTags.addAll(bank.cast<List<dynamic>>());
      }
    }
    
    return allTags;
  }
  
  Future<List<List<dynamic>>> parseMetaBanks() async {
    final allMeta = <List<dynamic>>[];
    
    for (final file in _archive!.files) {
      if (file.name.startsWith('term_meta_bank_') && file.name.endsWith('.json')) {
        final content = utf8.decode(file.content as List<int>);
        final bank = jsonDecode(content) as List<dynamic>;
        allMeta.addAll(bank.cast<List<dynamic>>());
      }
    }
    
    return allMeta;
  }
}

class ImportProgress {
  final String status;
  final double progress;
  
  ImportProgress({required this.status, required this.progress});
}