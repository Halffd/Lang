import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/script_converter.dart';

void main() {
  group('ScriptConverter.detect', () {
    test('detects hangul', () {
      expect(ScriptConverter.detect('안녕'), ScriptType.hangul);
    });
    test('detects cyrillic', () {
      expect(ScriptConverter.detect('привет'), ScriptType.cyrillic);
    });
    test('detects hebrew', () {
      expect(ScriptConverter.detect('שלום'), ScriptType.hebrew);
    });
    test('detects arabic', () {
      expect(ScriptConverter.detect('مرحبا'), ScriptType.arabic);
    });
    test('detects devanagari', () {
      expect(ScriptConverter.detect('नमस्ते'), ScriptType.devanagari);
    });
    test('detects thai', () {
      expect(ScriptConverter.detect('สวัสดี'), ScriptType.thai);
    });
  });

  group('ScriptConverter.latinToHangul', () {
    test('annyeong', () {
      final r = ScriptConverter.latinToHangul('annyeong');
      expect(r, '안녕');
    });

    test('simple syllable go', () {
      // g-o => 고
      expect(ScriptConverter.latinToHangul('go'), '고');
    });

    test('syllable with final consonant', () {
      // a-n => 안 (vowel initial uses ieung)
      expect(ScriptConverter.latinToHangul('an'), '안');
    });

    test('k vs g initials (Revised Romanization)', () {
      expect(ScriptConverter.latinToHangul('ko'), '코');
      expect(ScriptConverter.latinToHangul('go'), '고');
    });

    test('intervocalic consonant starts next syllable', () {
      // ha-se-yo, not 핫-에-요
      expect(ScriptConverter.latinToHangul('haseyo'), '하세요');
      expect(ScriptConverter.latinToHangul('annyeonghaseyo'), '안녕하세요');
    });

    test('greedy ng final does not steal syllable-initial g', () {
      // han-geul: han + geul, not hang + ul
      expect(ScriptConverter.latinToHangul('hangeul'), '한글');
    });
  });

  group('ScriptConverter.latinToCyrillic', () {
    test('privet', () {
      // p-r-i-v-e-t -> привет
      expect(ScriptConverter.latinToCyrillic('privet'), 'привет');
    });
    test('multi-char zh', () {
      expect(ScriptConverter.latinToCyrillic('zhest'), 'жест');
    });
    test('soft sign', () {
      expect(ScriptConverter.latinToCyrillic("mol'"), 'моль');
    });
  });

  group('ScriptConverter.latinToHebrew', () {
    test('shalom', () {
      final r = ScriptConverter.latinToHebrew('shalom');
      // sh->ש l->ל o (mater, vowel before final consonant)->ו m->ם
      expect(r, 'שלום');
    });

    test('ima word-initial vowel gets alef carrier', () {
      expect(ScriptConverter.latinToHebrew('ima'), 'אמא');
    });

    test('inner short vowels omitted', () {
      // abjad: inner vowels dropped
      final r = ScriptConverter.latinToHebrew('shalom');
      expect(r.runes.length, 4);
    });
  });

  group('ScriptConverter.latinToArabic', () {
    test('marhaba', () {
      final r = ScriptConverter.latinToArabic('marhaba');
      // m->م a drop r->ر h->ه b->ب a (word-final)->ا
      expect(r, 'مرهبا');
      expect(r.codeUnitAt(2), 0x0647); // ه he
    });
  });

  group('ScriptConverter.latinToDevanagari', () {
    test('namaste', () {
      final r = ScriptConverter.latinToDevanagari('namaste');
      // na->न (inherent a) m->म a? -> ा s->स t->ट? e->े
      // नमस्ते expected: न म स्त े
      expect(r, 'नमस्ते');
    });

    test('consonant cluster gets virama', () {
      // k-y -> क्य (क + virama + य)
      final r = ScriptConverter.latinToDevanagari('ky');
      expect(r, 'क्य');
    });
  });

  group('ScriptConverter.latinToThai', () {
    test('sawasdee', () {
      final r = ScriptConverter.latinToThai('sawatdee');
      // approximate - just check no latin letters remain for mapped parts
      expect(r.contains('ส'), true);
      expect(r.contains('ว'), true);
    });
  });

  group('ScriptConverter.latinToScript dispatch', () {
    test('ja converts romaji', () {
      expect(ScriptConverter.latinToScript('neko', 'ja'), 'ねこ');
    });
    test('ko converts hangul', () {
      expect(ScriptConverter.latinToScript('go', 'ko'), '고');
    });
    test('ru converts cyrillic', () {
      expect(ScriptConverter.latinToScript('privet', 'ru'), 'привет');
    });
    test('unknown language unchanged', () {
      expect(ScriptConverter.latinToScript('hello', 'en'), 'hello');
    });
    test('supportsLatinToScript', () {
      expect(ScriptConverter.supportsLatinToScript('ja'), true);
      expect(ScriptConverter.supportsLatinToScript('th'), true);
      expect(ScriptConverter.supportsLatinToScript('en'), false);
    });
  });
  group('ScriptConverter.latinToGreek', () {
    test('ellinikos with final sigma', () {
      // ends with sigma -> sofit form ς
      final r = ScriptConverter.latinToGreek('ellinikos');
      expect(r, 'ελλινικος');
      expect(r.runes.last, 0x03C2); // ς final sigma
    });

    test('theta digraph', () {
      expect(ScriptConverter.latinToGreek('thermos'), 'θερμος');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('thermos', 'el'), 'θερμος');
    });
  });

  group('ScriptConverter.latinToUkrainian', () {
    test('pryvit', () {
      // pryvit -> привіт (і = Ukrainian i, not Russian и)
      expect(ScriptConverter.latinToUkrainian('pryvit'), 'привіт');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('pryvit', 'uk'), 'привіт');
    });
  });

  group('ScriptConverter.latinToBulgarian', () {
    test('blagodaria', () {
      expect(ScriptConverter.latinToBulgarian('blagodaria'), 'благодаря');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('blagodaria', 'bg'), 'благодаря');
    });
  });

  group('ScriptConverter.latinToSerbian', () {
    test('lj nj dz digraphs', () {
      expect(ScriptConverter.latinToSerbian('ljudi'), 'људи');
      expect(ScriptConverter.latinToSerbian('konj'), 'коњ');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('zdravo', 'sr'), 'здраво');
    });
  });

  group('ScriptConverter.latinToGeorgian', () {
    test('gamarjoba', () {
      expect(ScriptConverter.latinToGeorgian('gamarjoba'), 'გამარჯობა');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('gamarjoba', 'ka'), 'გამარჯობა');
    });

    test('detect georgian script', () {
      expect(ScriptConverter.detect('გამარჯობა'), ScriptType.georgian);
    });
  });

  group('ScriptConverter.latinToArmenian', () {
    test('barev', () {
      expect(ScriptConverter.latinToArmenian('barev'), 'բարեվ');
    });

    test('hayastan', () {
      expect(ScriptConverter.latinToArmenian('hayastan'), 'հայաստան');
    });

    test('dispatch by language', () {
      expect(ScriptConverter.latinToScript('hayastan', 'hy'), 'հայաստան');
    });

    test('detect armenian script', () {
      expect(ScriptConverter.detect('հայաստան'), ScriptType.armenian);
    });
  });

}
