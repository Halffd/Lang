// IdeographicUtil: radical/component detection, structural
// similarity search, script detection delegation.

import 'package:flutter_test/flutter_test.dart';

import 'package:lang/utils/ideographic_util.dart';

void main() {
  group('getComponents', () {
    test('finds table-backed radicals', () {
      final comps = IdeographicUtil.getComponents('休');
      expect(comps, contains('亻')); // person radical
      expect(comps, contains('木')); // tree
    });

    test('multi-component character', () {
      final comps = IdeographicUtil.getComponents('好');
      // 女 + 子
      expect(comps, containsAll(['女', '子']));
    });

    test('character itself when no decomposition known', () {
      expect(IdeographicUtil.getComponents('你'), ['你']);
    });

    test('empty input', () {
      expect(IdeographicUtil.getComponents(''), isEmpty);
    });
  });

  group('findCharactersByParticle', () {
    test('filters by radical substring', () {
      final found = IdeographicUtil.findCharactersByParticle('氵', [
        '河',
        '林',
        '海',
        '火',
      ]);
      expect(found, ['河', '海']);
    });

    test('no match returns empty', () {
      expect(
        IdeographicUtil.findCharactersByParticle('氵', ['林', '火']),
        isEmpty,
      );
    });
  });

  group('decomposeCharacter', () {
    test('report shape', () {
      final report = IdeographicUtil.decomposeCharacter('好');
      expect(report['character'], '好');
      expect(report['components'], isNotEmpty);
      expect(report['hasComponents'], isTrue);
      expect(report['componentCount'], greaterThan(1));
    });
  });

  group('findSimilarByStructure', () {
    test('finds characters sharing components', () {
      // 明 = 日+月; 晶 = 日×3 shares 日; 林 = 木×2 shares nothing
      final similar = IdeographicUtil.findSimilarByStructure('明', [
        '晶',
        '林',
        '好',
      ]);
      expect(similar, contains('晶'));
      expect(similar, isNot(contains('林')));
    });

    test('excludes the character itself', () {
      final similar = IdeographicUtil.findSimilarByStructure('好', ['好', '妈']);
      expect(similar, isNot(contains('好')));
    });
  });

  group('script detection delegation', () {
    test('containsIdeographic', () {
      expect(IdeographicUtil.containsIdeographic('你好'), isTrue);
      expect(IdeographicUtil.containsIdeographic('hi'), isFalse);
    });

    test('containsChinese vs containsKanji', () {
      // both han ranges; detection differs by context api
      expect(IdeographicUtil.containsChinese('中'), isTrue);
      expect(IdeographicUtil.containsKanji('日'), isTrue);
    });
  });
}
