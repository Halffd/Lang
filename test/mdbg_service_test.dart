import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/datasources/remote/mdbg_service.dart';

/// Fixture derived from a real mdbg.net worddict page for
/// "本堂主说的没错吧": one row per candidate reading, alternate readings of
/// the same characters separated by td.separator rows.
final _sampleRows = '''
<table class="wordresults"><tbody>
<tr><td class="otxttop" colspan="5"></td></tr>
<tr class="row"><td width="12%" class="otxtbot">本</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt3">本</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt3">běn</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">(bound form) root; stem  <strong>/</strong> (bound form) origin; source  <strong>/</strong> originally; initially </div></td><td class="tail"><div class="hsk">HSK 1</div></td></tr>
<tr><td class="otxttop" colspan="5"></td></tr>
<tr class="row"><td width="12%" class="otxtbot">堂</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt2">堂</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt2">táng</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">(main) hall  <strong>/</strong> CL: <a class="word" href="d">間｜间</a> </div></td><td class="tail"><div class="hsk">HSK 7-9</div></td></tr>
<tr><td class="otxttop" colspan="5"></td></tr>
<tr class="row"><td width="12%" class="otxtmid">说</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt4">说</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt4">shuì</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">to persuade </div></td><td class="tail"><div class="hanzi"><a href="#"><span class="mpt4">說</span><wbr></a></div></td></tr>
<tr><td class="otxtmid"></td><td class="separator" colspan="4"></td></tr>
<tr class="row"><td width="12%" class="otxtmid">&nbsp;</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt1">说</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt1">shuō</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">to speak; to talk; to say  <strong>/</strong> to explain; to comment </div></td><td class="tail"><div class="hanzi"><a href="#"><span class="mpt1">說</span><wbr></a></div><div class="hsk">HSK 1</div></td></tr>
<tr><td class="otxtbot"></td><td class="separator" colspan="4"></td></tr>
<tr class="row"><td width="12%" class="otxtbot">&nbsp;</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt1">说</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt1">shuō</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">variant of <a class="word" href="d">說｜说</a> </div></td><td class="tail"><div class="hanzi"><a href="#"><span class="mpt1">説</span><wbr></a></div><div class="hsk">HSK 1</div></td></tr>
<tr><td class="otxttop" colspan="5"></td></tr>
<tr class="row"><td width="12%" class="otxtbot">没错</td><td class="head"><div class="hanzi"><a href="#"><span class="mpt2">没</span><wbr><span class="mpt4">错</span><wbr></a></div><div class="pinyin"><a href="#"><span class="mpt2">méi</span><wbr><span class="mpt4">cuò</span><wbr></a></div></td><td class="actions"></td><td class="details"><div class="defs">that's right  <strong>/</strong> sure!  <strong>/</strong> can't go wrong </div></td><td class="tail"><div class="hanzi"><a href="#"><span class="mpt2">沒</span><wbr><span class="mpt4">錯</span><wbr></a></div><div class="hsk">HSK 4</div></td></tr>
</tbody></table>
''';

String _page(String body) =>
    '<html><body><div id="contentarea">$body</div></body></html>';

void main() {
  final service = MdbgService();
  late List<MdbgEntry> results;

  setUp(() {
    results = service.parseResults(_page(_sampleRows));
  });

  group('MdbgService parsing of real worddict markup', () {
    test('parses primary rows from table.wordresults tr.row', () {
      expect(results.map((e) => e.word), ['本', '堂', '说', '没错']);
    });

    test('extracts tone-marked pinyin, one span per syllable', () {
      expect(results.first.pinyin, 'běn');
      expect(results[3].pinyin, 'méi cuò');
    });

    test('splits definitions at slash separators, keeping inner text', () {
      expect(results.first.definitions, [
        '(bound form) root; stem',
        '(bound form) origin; source',
        'originally; initially',
      ]);
      // link text inside a definition stays in its segment
      expect(results[1].definitions[1], 'CL: 間｜间');
    });

    test('captures HSK levels where present', () {
      expect(results.first.hskLevel, 'HSK 1');
      expect(results[3].hskLevel, 'HSK 4');
      expect(results[2].hskLevel, isNull); // 说 shuì row has none
    });

    test('captures traditional form only when it differs', () {
      expect(results.first.traditional, isNull);
      expect(results[2].traditional, '說');
      expect(results[3].traditional, '沒錯');
    });

    test('groups alternate readings under the primary entry', () {
      final shuo = results[2];
      expect(shuo.variants, hasLength(2));
      expect(shuo.variants[0].pinyin, 'shuō');
      expect(shuo.variants[1].traditional, '説');
    });

    test('tracks the query slice each row answers', () {
      expect(results.first.originalText, '本');
      expect(results[3].originalText, '没错');
    });

    test('empty page yields no results, not an exception', () {
      expect(service.parseResults('<html></html>'), isEmpty);
      expect(service.parseResults(''), isEmpty);
    });
  });

  // Live smoke test, same convention as test/wiktionary_service_test.dart.
  group('MdbgService live lookup', () {
    test('real page for 没错 parses to a sensible entry', () async {
      final entry = await service
          .lookupWord('没错')
          .timeout(const Duration(seconds: 20));
      if (entry == null) {
        markTestSkipped('network unavailable');
        return;
      }
      expect(entry.word, contains('没'));
      expect(entry.definitions.join(' '), contains('right'));
      expect(entry.pinyin, isNotEmpty);
    });
  });
}
