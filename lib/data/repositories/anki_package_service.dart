import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/data/repositories/srs_service.dart';

class AnkiPackageService {
  final SRSService srsService;

  AnkiPackageService({required this.srsService});

  Future<Uint8List> exportDeck({
    String? deckId,
    String? deckName,
    List<SRSCard>? cards,
  }) async {
    cards ??= deckId != null
        ? srsService.getCardsByDeck(deckId)
        : srsService.allCards;

    if (cards.isEmpty) {
      throw Exception('No cards to export');
    }

    final targetDeckName = deckName ?? (deckId != null
        ? srsService.getDeckById(deckId)?.name ?? 'LangDeck'
        : 'LangDeck');

    final archive = Archive();

    final dbBytes = _createAnkiDb(cards, targetDeckName);
    archive.addFile(ArchiveFile('collection.anki2', dbBytes.length, dbBytes));

    archive.addFile(ArchiveFile('media', 0, <int>[]));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData ?? []);
  }

  Uint8List _createAnkiDb(List<SRSCard> cards, String deckName) {
    final db = sqlite3.open(':memory:');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    db.execute('''
      CREATE TABLE col (
        id INTEGER PRIMARY KEY,
        crt INTEGER NOT NULL,
        mod INTEGER NOT NULL,
        scm INTEGER NOT NULL,
        ver INTEGER NOT NULL,
        dty INTEGER NOT NULL,
        conf TEXT NOT NULL,
        models TEXT NOT NULL,
        decks TEXT NOT NULL,
        dconf TEXT NOT NULL,
        tags TEXT NOT NULL
      );

      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        guid TEXT NOT NULL UNIQUE,
        mid INTEGER NOT NULL,
        mod INTEGER NOT NULL,
        usn INTEGER NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        flds TEXT NOT NULL,
        sfld INTEGER NOT NULL,
        csum INTEGER NOT NULL,
        flags INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL DEFAULT ''
      );

      CREATE TABLE cards (
        id INTEGER PRIMARY KEY,
        nid INTEGER NOT NULL,
        did INTEGER NOT NULL,
        ord INTEGER NOT NULL,
        mod INTEGER NOT NULL,
        usn INTEGER NOT NULL,
        type INTEGER NOT NULL,
        queue INTEGER NOT NULL,
        due INTEGER NOT NULL,
        ivl INTEGER NOT NULL,
        factor INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        lapses INTEGER NOT NULL,
        left INTEGER NOT NULL,
        odue INTEGER NOT NULL,
        odid INTEGER NOT NULL,
        flags INTEGER NOT NULL DEFAULT 0,
        data TEXT NOT NULL DEFAULT ''
      );

      CREATE TABLE revlog (
        id INTEGER PRIMARY KEY,
        cid INTEGER NOT NULL,
        usn INTEGER NOT NULL,
        ease INTEGER NOT NULL,
        ivl INTEGER NOT NULL,
        lastIvl INTEGER NOT NULL,
        factor INTEGER NOT NULL,
        time INTEGER NOT NULL,
        type INTEGER NOT NULL
      );

      CREATE INDEX idx_notes_guid ON notes(guid);
      CREATE INDEX idx_cards_nid ON cards(nid);
      CREATE INDEX idx_cards_did ON cards(did);
      CREATE INDEX idx_revlog_cid ON revlog(cid);
    ''');

    db.execute(
      "INSERT INTO col VALUES (1, $now, $now, $now, 11, 0, "
      "'{\"curDeck\":1,\"lsrp\":1,\"timeLim\":0}', "
      "'{}', "
      "'{\"1\":{\"name\":\"$deckName\",\"extendRev\":10,\"browserCollapsed\":false,\"collapsed\":false,\"daysSinceAck\":0,\"type\":1,\"mod\":$now}}', "
      "'{\"1\":{\"name\":\"Default\",\"revs\":5,\"lapse\":8,\"leeches\":1,\"stop\":0,\"mult\":0,\"minIvl\":1,\"maxIvl\":36500,\"hardfactor\":1300}}', "
      "'[]')",
    );

    const modelId = 1730000000000;
    final modelJson = _generateModelJson(modelId);
    db.execute(
      "UPDATE col SET models = '{\"$modelId\":$modelJson}' WHERE id = 1",
    );

    const deckId = 1;

    int noteId = 1;
    int cardId = 1;

    for (final card in cards) {
      final guid = _generateGuid();
      final mod = now;
      final usn = -1;

      final front = _escapeSqlite(card.word);
      final back = _escapeSqlite(card.meaning);
      final reading = card.reading != null ? _escapeSqlite(card.reading!) : '';
      final flds = '$front\x1f$reading\x1f$back\x1f\x1f\x1f\x1f\x1f\x1f\x1f';

      final sfld = card.word.hashCode.abs() % 2000000000;
      final csum = _calcCsum(card.word);

      final tags = '';

      db.execute(
        "INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum) VALUES ($noteId, '$guid', $modelId, $mod, $usn, '$tags', '$flds', $sfld, $csum)",
      );

      final due = card.dueDate.millisecondsSinceEpoch ~/ 1000;
      final ivl = card.interval;
      final factor = (card.easeFactor * 1000).round();
      final type = card.type == CardType.newCard ? 0 : card.type == CardType.learning ? 1 : 2;
      final queue = card.type == CardType.suspended ? -1 : (card.type == CardType.newCard ? 0 : 2);

      db.execute(
        "INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, left, odue, odid) "
        "VALUES ($cardId, $noteId, $deckId, 0, $mod, $usn, $type, $queue, $due, $ivl, $factor, ${card.reviewCount}, 0, 0, 0, 0)",
      );

      noteId++;
      cardId++;
    }

    db.execute("UPDATE col SET decks = '{\"1\":{\"name\":\"$deckName\",\"extendRev\":10,\"browserCollapsed\":false,\"collapsed\":false,\"daysSinceAck\":0,\"type\":1,\"mod\":$now,\"id\":1}}' WHERE id = 1");

    final dbBytes = db.export();
    db.dispose();

    return Uint8List.fromList(dbBytes);
  }

  String _escapeSqlite(String s) {
    return s.replaceAll("'", "''").replaceAll("\n", " ");
  }

  String _generateGuid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    String guid = '';
    int n = now;
    for (int i = 0; i < 10; i++) {
      guid += chars[n % chars.length];
      n ~/= chars.length;
    }
    return guid;
  }

  int _calcCsum(String str) {
    int sum = 0;
    for (int i = 0; i < str.length; i++) {
      sum = (sum * 31 + str.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return sum.abs();
  }

  String _generateModelJson(int modelId) {
    return '{"sortf":0,"tmpls":[{"qfmt":"{{FrontSide}}\\n\\n{{Front}}","afmt":"{{FrontSide}}\\n\\n{{Back}}","name":"Forward","ord":0,"bafmt":"","bqfmt":""}],"flds":[{"name":"Front","sticky":false,"rtl":false,"ord":0,"font":"Liberation Sans","size":20},{"name":"Back","sticky":false,"rtl":false,"ord":1,"font":"Liberation Sans","size":20},{"name":"Reading","sticky":false,"rtl":false,"ord":2,"font":"Liberation Sans","size":20}],"did":1,"latexPre":"\\documentclass[12pt]{article}\\n\\usepackage{amssymb}\\n\\usepackage{amsmath}\\n\\usepackage{wasysym}\\n\\usepackage[T2A]{fontenc}\\n\\usepackage[russian]{babel}\\n\\pagestyle{empty}\\n\\begin{document}","latexPost":"\\end{document}","name":"Basic","tags":[],"id":$modelId,"mod":${DateTime.now().millisecondsSinceEpoch ~/ 1000},"req":[[0,"any",[0]]]}';
  }

  Future<List<SRSCard>> importPackage(Uint8List data) async {
    final archive = ZipDecoder().decodeBytes(data);

    Uint8List? collectionData;
    final mediaMap = <String, Uint8List>{};

    for (final file in archive) {
      if (file.name == 'collection.anki2') {
        collectionData = Uint8List.fromList(file.content as List<int>);
      } else if (file.name.startsWith('media/') && file.name != 'media/') {
        final name = file.name.replaceFirst('media/', '');
        mediaMap[name] = Uint8List.fromList(file.content as List<int>);
      }
    }

    if (collectionData == null) {
      throw Exception('Invalid .apkg file: no collection found');
    }

    return _parseAnkiDb(collectionData, mediaMap);
  }

  Future<List<SRSCard>> _parseAnkiDb(
    Uint8List dbData,
    Map<String, Uint8List> mediaMap,
  ) async {
    final cards = <SRSCard>[];

    try {
      final db = sqlite3.openDatabase(dbData);

      final stmt = db.prepare('SELECT id, flds FROM notes');
      final result = stmt.select();

      for (final row in result) {
        final noteId = row[0] as int;
        final flds = row[1] as String;
        final fields = flds.split('\x1f');

        final word = fields.isNotEmpty ? fields[0] : '';
        final reading = fields.length > 1 && fields[1].isNotEmpty ? fields[1] : null;
        final meaning = fields.length > 2 ? fields[2] : '';

        if (word.isNotEmpty) {
          cards.add(SRSCard.newCard(
            id: 'anki_$noteId',
            word: word,
            reading: reading,
            meaning: meaning.isNotEmpty ? meaning : ' ',
          ));
        }
      }

      stmt.dispose();
      db.dispose();
    } catch (e) {
      throw Exception('Failed to parse Anki database: $e');
    }

    return cards;
  }

  Future<void> importAndMerge(Uint8List data) async {
    final importedCards = await importPackage(data);

    for (final card in importedCards) {
      final existing = srsService.getCardById(card.id);
      if (existing == null) {
        await srsService.addCard(card);
      }
    }
  }
}