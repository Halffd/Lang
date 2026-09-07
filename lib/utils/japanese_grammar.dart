class KanaKit {
  String toHiragana(String input) {
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 0x30A0 && c <= 0x30F6) {
        buf.writeCharCode(c - 0x60);
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  String toKatakana(String input) {
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (c >= 0x3040 && c <= 0x3096) {
        buf.writeCharCode(c + 0x60);
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  bool isKana(String input) {
    return input.runes.every((r) => (r >= 0x3040 && r <= 0x309F) || (r >= 0x30A0 && r <= 0x30FF));
  }
}

class JapaneseGrammar {
  static KanaKit? _kanaKit;
  static KanaKit get kanaKit => _kanaKit ??= KanaKit();

  static const String _godanKanaTable = 'あいうえお'
      'かきくけこ'
      'さしすせそ'
      'たちつてと'
      'なにぬねの'
      'はひふへほ'
      'まみむめも'
      'やゆよ'
      'らりるれろ'
      'わをん';

  static int _kanaRow(String kana) {
    final idx = _godanKanaTable.indexOf(kana);
    if (idx < 0) return -1;
    return idx ~/ 5;
  }

  static String _kanaAtRowCol(int row, int col) {
    if (row < 0 || row > 9 || col < 0 || col > 4) return '';
    int idx = row * 5 + col;
    if (row == 7) {
      if (col == 1) return 'ゆ';
      if (col == 2) return 'よ';
      if (col > 2) return '';
      idx = 35 + col;
    }
    if (row == 8) idx = row * 5 + col - 2;
    if (row == 9) {
      if (col == 0) return 'わ';
      if (col == 1) return 'を';
      if (col == 2) return 'ん';
      return '';
    }
    if (idx >= _godanKanaTable.length) return '';
    return _godanKanaTable[idx];
  }

  static String? _toUStem(String kana) {
    final row = _kanaRow(kana);
    if (row < 0) return null;
    final uKana = _kanaAtRowCol(row, 2);
    return (uKana.isNotEmpty) ? uKana : null;
  }

  static String? _toAStem(String kana) {
    final row = _kanaRow(kana);
    if (row < 0) return null;
    final aKana = _kanaAtRowCol(row, 0);
    return (aKana.isNotEmpty) ? aKana : null;
  }

  static String? _toIStem(String kana) {
    final row = _kanaRow(kana);
    if (row < 0) return null;
    final iKana = _kanaAtRowCol(row, 1);
    return (iKana.isNotEmpty) ? iKana : null;
  }

  static String? _toEStem(String kana) {
    final row = _kanaRow(kana);
    if (row < 0) return null;
    final eKana = _kanaAtRowCol(row, 3);
    return (eKana.isNotEmpty) ? eKana : null;
  }

  static const Map<String, String> _irregulars = {
    'する': 'する',
    'した': 'する',
    'して': 'する',
    'しない': 'する',
    'せず': 'する',
    'できる': 'する',
    'されます': 'する',
    'される': 'する',
    'させられる': 'する',
    'させます': 'する',
    'させる': 'する',
    'します': 'する',
    'しろ': 'する',
    'せよ': 'する',
    'しよう': 'する',
    'しましょう': 'する',
    'しました': 'する',
    'していない': 'する',
    'されて': 'する',
    '来る': '来る',
    '来た': '来る',
    '来て': '来る',
    '来ない': '来る',
    '来られる': '来る',
    '来させる': '来る',
    '来ます': '来る',
    '来い': '来る',
    '来よう': '来る',
    'きました': '来る',
    'こない': '来る',
    'こられます': '来る',
    'こられる': '来る',
    '行く': '行く',
    '行った': '行く',
    '行って': '行く',
    '行かない': '行く',
    '行きます': '行く',
    '行ける': '行く',
    '行こう': '行く',
    'いった': '行く',
    'いって': '行く',
    'いかない': '行く',
    'いきます': '行く',
    'いける': '行く',
    'いこう': '行く',
  };

  static List<String> deconjugate(String word) {
    final results = <String>{};

    if (_irregulars.containsKey(word)) {
      results.add(_irregulars[word]!);
    }

    if (word.endsWith('ませんでした')) {
      final stem = word.substring(0, word.length - 6);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toIStem, 'う');
    }

    if (word.endsWith('ませんでした')) {
    } else if (word.endsWith('ました')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toIStem, 'う');
    }

    if (word.endsWith('ません')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toIStem, 'う');
    }

    if (word.endsWith('なかった')) {
      final stem = word.substring(0, word.length - 4);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toAStem, 'う');
    }

    if (word.endsWith('ない')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toAStem, 'う');
    }

    if (word.endsWith('なくて')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toAStem, 'う');
    }

    if (word.endsWith('んで')) {
      final stem = word.substring(0, word.length - 2);
      for (final kana in stem.runes.toList().reversed) {
        final ch = String.fromCharCode(kana);
        final uStem = _toUStem(ch);
        if (uStem != null && ['ば', 'な', 'ま', 'だ', 'が'].contains(ch) == false) {
          final row = _kanaRow(ch);
          if (row >= 0) {
            final bKana = _kanaAtRowCol(row, 4);
            final mKana = _kanaAtRowCol(row, 2);
            if (bKana == ch || mKana == ch) {
              final prefix = stem.substring(0, stem.length - 1);
              results.add('$prefix$uStemう');
            }
          }
        }
      }
      if (stem.isNotEmpty) {
        _addGodanFromNde(stem, results);
      }
    }

    if (word.endsWith('って')) {
      final stem = word.substring(0, word.length - 2);
      if (stem.isNotEmpty) {
        _addGodanFromTte(stem, results);
      }
      results.add('$stemる');
    }

    if (word.endsWith('いて')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemく');
    }

    if (word.endsWith('いで')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemぐ');
    }

    if (word.endsWith('して')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemする');
    }

    if (word.endsWith('て') && !word.endsWith('って') && !word.endsWith('ないて') && !word.endsWith('んで') && !word.endsWith('いて') && !word.endsWith('いで') && !word.endsWith('して')) {
      final stem = word.substring(0, word.length - 1);
      results.add('$stemる');
    }

    if (word.endsWith('んだ')) {
      final stem = word.substring(0, word.length - 2);
      if (stem.isNotEmpty) {
        _addGodanFromNde(stem, results);
      }
    }

    if (word.endsWith('った')) {
      final stem = word.substring(0, word.length - 2);
      if (stem.isNotEmpty) {
        _addGodanFromTte(stem, results);
      }
      results.add('$stemる');
    }

    if (word.endsWith('いた')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemく');
    }

    if (word.endsWith('いだ')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemぐ');
    }

    if (word.endsWith('した')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemする');
    }

    if (word.endsWith('た') && !word.endsWith('った') && !word.endsWith('いた') && !word.endsWith('いだ') && !word.endsWith('んだ') && !word.endsWith('した')) {
      final stem = word.substring(0, word.length - 1);
      results.add('$stemる');
    }

    if (word.endsWith('える')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemう');
      _addGodanCandidates(stem, results, _toEStem, 'う');
    }

    if (word.endsWith('れる')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toEStem, 'う');
    }

    if (word.endsWith('られる')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
    }

    if (word.endsWith('させる')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
    }

    if (word.endsWith('せる')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toAStem, 'う');
    }

    if (word.endsWith('えば')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemう');
      _addGodanCandidates(stem, results, _toEStem, 'う');
    }

    if (word.endsWith('れば')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
    }

    if (word.endsWith('たら')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
    }

    if (word.endsWith('よう')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemる');
    }

    if (word.endsWith('おう')) {
      final stem = word.substring(0, word.length - 2);
      results.add('$stemう');
      _addGodanCandidates(stem, results, _toOStem, 'う');
    }

    if (word.endsWith('ましょう')) {
      final stem = word.substring(0, word.length - 3);
      results.add('$stemる');
      _addGodanCandidates(stem, results, _toIStem, 'う');
    }

    if (word.endsWith('ろ')) {
      final stem = word.substring(0, word.length - 1);
      results.add('$stemる');
    }

    if (word.endsWith('け')) {
      final stem = word.substring(0, word.length - 1);
      results.add('$stemく');
    }

    if (word.endsWith('かった')) {
      results.add('${word.substring(0, word.length - 3)}い');
    }

    if (word.endsWith('くない')) {
      results.add('${word.substring(0, word.length - 3)}い');
    }

    if (word.endsWith('くなかった')) {
      results.add('${word.substring(0, word.length - 5)}い');
    }

    if (word.endsWith('くて')) {
      results.add('${word.substring(0, word.length - 2)}い');
    }

    if (word.endsWith('く')) {
      final stem = word.substring(0, word.length - 1);
      if (stem.isNotEmpty && _isHiragana(stem)) {
        results.add('$stemい');
      }
    }

    if (word.endsWith('です')) {
      results.add(word.substring(0, word.length - 2));
    }

    results.add(word);
    return results.where((f) => f.isNotEmpty).toList();
  }

  static String? _toOStem(String kana) {
    final row = _kanaRow(kana);
    if (row < 0) return null;
    final oKana = _kanaAtRowCol(row, 4);
    return (oKana.isNotEmpty) ? oKana : null;
  }

  static void _addGodanCandidates(
    String stem,
    Set<String> results,
    String? Function(String) stemConverter,
    String suffix,
  ) {
    if (stem.isEmpty) return;
    final lastChar = stem[stem.length - 1];
    final converted = stemConverter(lastChar);
    if (converted != null && converted != lastChar) {
      final prefix = stem.substring(0, stem.length - 1);
      results.add(prefix + converted + suffix);
    }
  }

  static void _addGodanFromNde(String stem, Set<String> results) {
    if (stem.isEmpty) return;
    final lastChar = stem[stem.length - 1];
    final row = _kanaRow(lastChar);
    if (row < 0) return;

    final bCol = _kanaAtRowCol(row, 4);
    final nCol = _kanaAtRowCol(row, 0);
    final mCol = _kanaAtRowCol(row, 2);
    final uCol = _kanaAtRowCol(row, 2);

    if (bCol.isNotEmpty) results.add('${stem.substring(0, stem.length - 1)}$bColう');
    if (nCol.isNotEmpty) results.add('${stem.substring(0, stem.length - 1)}${_kanaAtRowCol(row, 2)}う');
    if (mCol.isNotEmpty) results.add('${stem.substring(0, stem.length - 1)}$mColう');

    final uKana = _kanaAtRowCol(row, 2);
    if (uKana.isNotEmpty) results.add('${stem.substring(0, stem.length - 1)}$uKanaう');
  }

  static void _addGodanFromTte(String stem, Set<String> results) {
    if (stem.isEmpty) return;
    final lastChar = stem[stem.length - 1];
    final row = _kanaRow(lastChar);
    if (row < 0) return;

    final uKana = _kanaAtRowCol(row, 2);
    if (uKana.isNotEmpty) {
      results.add('${stem.substring(0, stem.length - 1)}$uKanaう');
    }

    results.add('$stemつ');
    results.add('$stemる');
    results.add('$stemう');
  }

  static bool _isHiragana(String text) {
    return RegExp(r'^[\u3040-\u309F]+$').hasMatch(text);
  }

  static String normalizeVerb(String word) {
    final forms = deconjugate(word);
    if (forms.length > 1) return forms.first;
    return word;
  }

  static List<String> getAllPossibleForms(String word) {
    final forms = <String>{};
    forms.addAll(deconjugate(word));

    if (hasKanji(word)) {
      try {
        final hiragana = kanaKit.toHiragana(word);
        if (hiragana != word) {
          forms.addAll(deconjugate(hiragana));
        }
      } catch (e) {
      }
    }

    return forms.toList();
  }

  static bool hasKanji(String text) {
    return RegExp(r'[\u4e00-\u9faf]').hasMatch(text);
  }
}