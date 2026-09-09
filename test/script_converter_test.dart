import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/script_converter.dart';
import 'package:lang/utils/pinyin_util.dart';

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

  group('ScriptConverter.detect more scripts', () {
    test('detects hiragana vs katakana', () {
      expect(ScriptConverter.detect('あ'), ScriptType.hiragana);
      expect(ScriptConverter.detect('ア'), ScriptType.katakana);
    });
    test('detects latin', () {
      expect(ScriptConverter.detect('abc'), ScriptType.latin);
    });
    test('detects mixed', () {
      expect(ScriptConverter.detect('abcあ'), ScriptType.mixed);
    });
    test('detects empty as unknown', () {
      expect(ScriptConverter.detect(''), ScriptType.unknown);
    });
    test('detects hanzi/kanji', () {
      expect(ScriptConverter.detect('漢'), ScriptType.hanzi);
    });
    test('detects bopomofo', () {
      expect(ScriptConverter.detect('ㄅ'), ScriptType.bopomofo);
    });
    test('detects greek', () {
      expect(ScriptConverter.detect('ελ'), ScriptType.greek);
    });
    test('detects cyrillic ukrainian text', () {
      expect(ScriptConverter.detect('привіт'), ScriptType.cyrillic);
    });
  });

  group('ScriptConverter romaji/kana', () {
    test('romajiToHiragana basics', () {
      expect(ScriptConverter.romajiToHiragana('neko'), 'ねこ');
      expect(ScriptConverter.romajiToHiragana('shi'), 'し');
      expect(ScriptConverter.romajiToHiragana('tsu'), 'つ');
    });
    test('romajiToHiragana digraphs', () {
      expect(ScriptConverter.romajiToHiragana('kya'), 'きゃ');
      expect(ScriptConverter.romajiToHiragana('sha'), 'しゃ');
    });
    test('romajiToHiragana geminate', () {
      expect(ScriptConverter.romajiToHiragana('kka'), 'っか');
    });
    test('romajiToHiragana passes through unknown', () {
      expect(ScriptConverter.romajiToHiragana('neko!'), 'ねこ!');
    });
    test('romajiToKatakana', () {
      expect(ScriptConverter.romajiToKatakana('neko'), 'ネコ');
    });
    test('kanaToRomaji roundtrip', () {
      expect(ScriptConverter.kanaToRomaji('ねこ'), 'neko');
      expect(ScriptConverter.kanaToRomaji('きゃ'), 'kya');
    });
    test('hiragana <-> katakana', () {
      expect(ScriptConverter.hiraganaToKatakana('さくら'), 'サクラ');
      expect(ScriptConverter.katakanaToHiragana('サクラ'), 'さくら');
    });
  });

  group('PinyinUtil tone placement', () {
    test('tone goes on the main vowel', () {
      expect(PinyinUtil.convertToneNumbers('hao3'), 'hǎo');
      expect(PinyinUtil.convertToneNumbers('ni3'), 'nǐ');
    });
    test('joined syllables', () {
      expect(PinyinUtil.convertToneNumbers('zhong1wen2'), 'zhōngwén');
      expect(PinyinUtil.convertToneNumbers('ni3hao3'), 'nǐhǎo');
    });
    test('space separated', () {
      expect(PinyinUtil.convertToneNumbers('ni3 hao3'), 'nǐ hǎo');
    });
    test('iu and ui rules', () {
      expect(PinyinUtil.convertToneNumbers('liu2'), 'liú');
      expect(PinyinUtil.convertToneNumbers('gui4'), 'guì');
      expect(PinyinUtil.convertToneNumbers('shui3'), 'shuǐ');
    });
    test('ou rule marks o', () {
      expect(PinyinUtil.convertToneNumbers('zou3'), 'zǒu');
    });
    test('neutral tone 5 has no mark', () {
      expect(PinyinUtil.convertToneNumbers('ma5'), 'ma');
      expect(PinyinUtil.convertToneNumbers('men5'), 'men');
    });
    test('v and u: substitutes for ü', () {
      expect(PinyinUtil.convertToneNumbers('lv4'), 'lǜ');
      expect(PinyinUtil.convertToneNumbers('lu:4'), 'lǜ');
      expect(PinyinUtil.convertToneNumbers('nu:3'), 'nǚ');
    });
    test('no tone digit passes through', () {
      expect(PinyinUtil.convertToneNumbers('hao'), 'hao');
      expect(PinyinUtil.convertToneNumbers(''), '');
    });
  });

  group('ScriptConverter pinyin/bopomofo', () {
    test('latinToPinyin dispatch', () {
      expect(ScriptConverter.latinToPinyin('zhong1wen2'), 'zhōngwén');
      expect(ScriptConverter.latinToPinyin('ni3 hao3'), 'nǐ hǎo');
    });
    test('bopomofoToPinyin', () {
      expect(ScriptConverter.bopomofoToPinyin('ㄅ'), 'b');
      expect(ScriptConverter.bopomofoToPinyin('ㄓ'), 'zh');
    });
    test('pinyinToBopomofo', () {
      expect(ScriptConverter.pinyinToBopomofo('b'), 'ㄅ');
    });
  });

  group('ScriptConverter.latinToHangul more', () {
    test('tense consonants', () {
      expect(ScriptConverter.latinToHangul('ppal'), '빨');
      expect(ScriptConverter.latinToHangul('kkam'), '깜');
    });
    test('spaces preserved', () {
      expect(ScriptConverter.latinToHangul('jal ga'), '잘 가');
    });
    test('uppercase input tolerated', () {
      expect(ScriptConverter.latinToHangul('GO'), '고');
    });
    test('gamsa', () {
      expect(ScriptConverter.latinToHangul('gamsa'), '감사');
    });
    test('naneun', () {
      expect(ScriptConverter.latinToHangul('naneun'), '나는');
    });
  });

  group('ScriptConverter.latinToCyrillic more', () {
    test('shch digraph', () {
      expect(ScriptConverter.latinToCyrillic('shchuka'), 'щука');
    });
    test('yu ya digraphs', () {
      expect(ScriptConverter.latinToCyrillic('yulia'), 'юлиа');
    });
    test('hard sign', () {
      expect(ScriptConverter.latinToCyrillic("pod''ezd"), 'подъезд');
    });
  });

  group('ScriptConverter.latinToGreek more', () {
    test('final sigma', () {
      final r = ScriptConverter.latinToGreek('sos');
      expect(r.runes.last, 0x03C2);
    });
    test('medial sigma stays sigma', () {
      expect(ScriptConverter.latinToGreek('sosi'), 'σοσι');
    });
    test('digraphs', () {
      expect(ScriptConverter.latinToGreek('thermos'), 'θερμος');
    });
  });

  group('ScriptConverter.latinToGeorgian more', () {
    test('digraphs', () {
      expect(ScriptConverter.latinToGeorgian('tskhali'), 'ცხალი');
      expect(ScriptConverter.latinToGeorgian('dzveli'), 'ძველი');
    });
  });

  group('ScriptConverter.latinToArmenian more', () {
    test('digraph', () {
      expect(ScriptConverter.latinToArmenian('khach'), 'խաչ');
    });
  });

  group('ScriptConverter.latinToHebrew more', () {
    test('mi with final yod', () {
      final r = ScriptConverter.latinToHebrew('mi');
      expect(r.runes.last, 0x05D9); // י yod
    });
    test('word-final alef', () {
      final r = ScriptConverter.latinToHebrew('ima');
      expect(r.runes.last, 0x05D0); // א alef
    });
    test('sofit final mem', () {
      final r = ScriptConverter.latinToHebrew('shalom');
      expect(r.runes.last, 0x05DD); // ם mem sofit
    });
  });

  group('ScriptConverter.latinToArabic more', () {
    test('word-final alif', () {
      final r = ScriptConverter.latinToArabic('marhaba');
      expect(r.runes.last, 0x0627); // ا alif
    });
    test('short vowels omitted inside', () {
      final r = ScriptConverter.latinToArabic('klb');
      expect(r, 'كلب'); // k-l-b
    });
    test('hamza apostrophe', () {
      // apostrophe is a hamza carrier and does not end the word:
      // 'a' before it stays omitted, no bogus word-final alif
      expect(ScriptConverter.latinToArabic("ta'nin"), 'تءنن');
      expect(ScriptConverter.latinToArabic('taniin'), 'تنين');
    });
  });

  group('ScriptConverter edge cases', () {
    test('empty input returns empty', () {
      expect(ScriptConverter.latinToHangul(''), '');
      expect(ScriptConverter.latinToGreek(''), '');
      expect(ScriptConverter.latinToHebrew(''), '');
      expect(ScriptConverter.latinToArabic(''), '');
      expect(ScriptConverter.latinToGeorgian(''), '');
      expect(ScriptConverter.latinToArmenian(''), '');
      expect(ScriptConverter.latinToCyrillic(''), '');
      expect(ScriptConverter.latinToThai(''), '');
      expect(ScriptConverter.latinToDevanagari(''), '');
      expect(ScriptConverter.latinToUkrainian(''), '');
      expect(ScriptConverter.latinToBulgarian(''), '');
      expect(ScriptConverter.latinToSerbian(''), '');
    });
    test('non-latin pass through untouched', () {
      expect(ScriptConverter.latinToHangul('안녕'), '안녕');
      expect(ScriptConverter.latinToGreek('ε'), 'ε');
    });
    test('looksLikeRomaji', () {
      expect(ScriptConverter.looksLikeRomaji('abc'), true);
      expect(ScriptConverter.looksLikeRomaji('a b-c'), true);
      expect(ScriptConverter.looksLikeRomaji('あ'), false);
      expect(ScriptConverter.looksLikeRomaji('123'), false);
    });
    test('supportsLatinToScript full coverage', () {
      for (final lang in [
        'ja', 'zh', 'ko', 'ru', 'uk', 'bg', 'sr', 'el',
        'ka', 'hy', 'he', 'iw', 'ar', 'hi', 'th',
      ]) {
        expect(ScriptConverter.supportsLatinToScript(lang), true,
            reason: lang);
      }
      for (final lang in ['en', 'fr', 'de', 'xx', '']) {
        expect(ScriptConverter.supportsLatinToScript(lang), false,
            reason: lang);
      }
    });
  });

  group('ScriptConverter.latinToDevanagari more', () {
    test('inherent vowel', () {
      // ka -> क (a is inherent, not written)
      expect(ScriptConverter.latinToDevanagari('ka'), 'क');
      expect(ScriptConverter.latinToDevanagari('na'), 'न');
    });
    test('vowel signs', () {
      // ki -> कि, kaa -> का
      expect(ScriptConverter.latinToDevanagari('ki'), 'कि');
      expect(ScriptConverter.latinToDevanagari('kaa'), 'का');
      expect(ScriptConverter.latinToDevanagari('ku'), 'कु');
      expect(ScriptConverter.latinToDevanagari('ke'), 'के');
    });
    test('aspirated consonants', () {
      expect(ScriptConverter.latinToDevanagari('dha'), 'ध');
      expect(ScriptConverter.latinToDevanagari('kha'), 'ख');
      expect(ScriptConverter.latinToDevanagari('bha'), 'भ');
    });
    test('namaste', () {
      expect(ScriptConverter.latinToDevanagari('namaste'), 'नमस्ते');
    });
  });

  group('ScriptConverter.latinToThai more', () {
    test('aspirated consonants', () {
      // kh -> ข, ph -> พ, th -> ท
      final r = ScriptConverter.latinToThai('khao');
      expect(r, contains('ข'));
      final r2 = ScriptConverter.latinToThai('phom');
      expect(r2, contains('พ'));
    });
    test('ng digraph', () {
      expect(ScriptConverter.latinToThai('ng'), 'ง');
    });
  });

  group('ScriptConverter.hanziToPinyin', () {
    test('common word', () async {
      expect(await ScriptConverter.hanziToPinyin('你好'), 'nǐ hǎo');
    });
    test('mixed hanzi and latin', () async {
      expect(await ScriptConverter.hanziToPinyin('漢x'), '漢 x');
    });
  });

  group('ScriptConverter.looksLikePinyin', () {
    test('accepts pinyin-shaped words', () {
      expect(ScriptConverter.looksLikePinyin('ni hao'), true);
      expect(ScriptConverter.looksLikePinyin('zhongwen'), true);
    });
  });

  group('ScriptConverter.latinToHebrew multi-word', () {
    test('mater works per word, not per string', () {
      // shalom ima -> שלום אמא (shalom keeps its ו mid-sentence)
      final r = ScriptConverter.latinToHebrew('shalom ima');
      expect(r, 'שלום אמא');
    });
    test('sofit per word', () {
      // both words get final forms: ם for m, א for a
      final r = ScriptConverter.latinToHebrew('shalom, ima');
      expect(r, 'שלום, אמא');
    });
  });

  group('ScriptConverter kana edge cases', () {
    test('kanaToRomaji handles katakana', () {
      expect(ScriptConverter.kanaToRomaji('ネコ'), 'neko');
      expect(ScriptConverter.kanaToRomaji('サクラ'), 'sakura');
    });
    test('kanaToRomaji mixed scripts', () {
      expect(ScriptConverter.kanaToRomaji('あア'), 'aa');
    });
    test('iw legacy hebrew code dispatches', () {
      expect(ScriptConverter.latinToScript('shalom', 'iw'), 'שלום');
    });
  });

}
