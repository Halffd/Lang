import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/handlebars_engine.dart';

void main() {
  group('HandlebarsEngine basics', () {
    test('plain text passes through', () {
      expect(HandlebarsEngine.render('hello', {}), 'hello');
    });

    test('comments stripped', () {
      expect(HandlebarsEngine.render('{{~! comment ~}}text', {}), 'text');
    });

    test('simple variable', () {
      expect(
        HandlebarsEngine.render('{{expression}}', {'expression': '読む'}),
        '読む',
      );
    });

    test('unescaped triple stash', () {
      expect(
        HandlebarsEngine.render('{{{glossary}}}', {'glossary': '<b>bold</b>'}),
        '<b>bold</b>',
      );
    });

    test('escaped double stash escapes html', () {
      expect(
        HandlebarsEngine.render('{{glossary}}', {'glossary': '<b>bold</b>'}),
        '&lt;b&gt;bold&lt;/b&gt;',
      );
    });

    test('dot and this', () {
      // {{.}} renders the current each-item
      expect(
        HandlebarsEngine.render('{{#each words}}{{.}} {{/each}}', {
          'words': ['a', 'b'],
        }),
        'a b ',
      );
    });
  });

  group('inline partials', () {
    test('define and invoke', () {
      const t =
          '{{#*inline "glossary"}}'
          'DEF:{{expression}}'
          '{{/inline}}'
          '{{~> glossary ~}}';
      expect(HandlebarsEngine.render(t, {'expression': '読む'}), 'DEF:読む');
    });

    test('partial with args', () {
      const t =
          '{{#*inline "fmt"}}[{{x}}]{{/inline}}'
          '{{~> fmt x=expression ~}}';
      expect(HandlebarsEngine.render(t, {'expression': 'neko'}), '[neko]');
    });
  });

  group('set/get', () {
    test('set literal then get', () {
      const t = '{{set "opt-mode" "harmonic" ~}}{{get "opt-mode"}}';
      expect(HandlebarsEngine.render(t, {}), 'harmonic');
    });

    test('block set', () {
      const t = '{{~#set "name"~}}dictionaries{{~/set~}}name:{{get "name"}}';
      expect(HandlebarsEngine.render(t, {}), 'name:dictionaries');
    });
  });

  group('conditionals', () {
    test('if true renders body', () {
      expect(
        HandlebarsEngine.render('{{#if merge}}yes{{else}}no{{/if}}', {
          'merge': true,
        }),
        'yes',
      );
    });

    test('if false renders else', () {
      expect(
        HandlebarsEngine.render('{{#if merge}}yes{{else}}no{{/if}}', {
          'merge': false,
        }),
        'no',
      );
    });

    test('unless', () {
      expect(
        HandlebarsEngine.render('{{#unless merge}}no merge{{/unless}}', {
          'merge': false,
        }),
        'no merge',
      );
    });
  });

  group('each', () {
    test('iterates list with dot access', () {
      const t = '{{#each glossary}}<li>{{.}}</li>{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'glossary': ['to read', 'to study'],
        }),
        '<li>to read</li><li>to study</li>',
      );
    });

    test('@index @first @last', () {
      const t = '{{#each glossary}}{{.}}{{#unless @last}},{{/unless}}{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'glossary': ['a', 'b', 'c'],
        }),
        'a,b,c',
      );
    });

    test('map iteration with key access', () {
      const t = '{{#each frequencies}}{{dictionary}}:{{frequency}};{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'frequencies': [
            {'dictionary': 'JPDB', 'frequency': '440'},
            {'dictionary': 'JMdict', 'frequency': '1200'},
          ],
        }),
        'JPDB:440;JMdict:1200;',
      );
    });
  });

  group('op helper', () {
    test('equality strict', () {
      expect(
        HandlebarsEngine.render('{{#if (op "===" type "term")}}term{{/if}}', {
          'type': 'term',
        }),
        'term',
      );
    });

    test('or', () {
      expect(
        HandlebarsEngine.render(
          '{{#if (op "||" (op ">" count 1) (op "<" count 5))}}mid{{/if}}',
          {'count': 3},
        ),
        'mid',
      );
    });

    test('not', () {
      expect(
        HandlebarsEngine.render('{{#if (op "!" compactTags)}}brief{{/if}}', {
          'compactTags': false,
        }),
        'brief',
      );
    });

    test('numeric add', () {
      expect(HandlebarsEngine.render('{{op "+" 1 2}}', {}), '3.0');
    });
  });

  group('regex', () {
    test('regexMatch outputs content when matching', () {
      const t =
          '{{~#regexMatch "^(JMdict.*)" "gu"~}}{{dictionary}}{{~/regexMatch~}}';
      expect(
        HandlebarsEngine.render(t, {'dictionary': 'JMdict (English)'}),
        'JMdict (English)',
      );
    });

    test('regexMatch empty when not matching', () {
      const t =
          '{{~#regexMatch "^(JMdict.*)" "gu"~}}{{dictionary}}{{~/regexMatch~}}';
      expect(HandlebarsEngine.render(t, {'dictionary': 'KireiCake'}), '');
    });

    test('regexReplace', () {
      const t =
          r'{{~#regexReplace "^\s+|\s+$" "" "g"~}}{{text}}{{~/regexReplace~}}';
      expect(HandlebarsEngine.render(t, {'text': '  padded  '}), 'padded');
    });

    test('regexReplace capture groups', () {
      const t =
          r'{{~#regexReplace "^(.+?)<rt>(.+?)</rt></ruby>" " $1[$2]" "g"~}}'
          '{{{html}}}{{~/regexReplace~}}';
      expect(
        HandlebarsEngine.render(t, {'html': '<ruby>読む<rt>よむ</rt></ruby>'}),
        ' <ruby>読む[よむ]',
      );
      // with wrapper pre-stripped (as jpmn templates do in a prior pass)
      expect(
        HandlebarsEngine.render(t, {'html': '読む<rt>よむ</rt></ruby>'}),
        ' 読む[よむ]',
      );
    });
  });

  group('nested contexts', () {
    test('parent access', () {
      const t = '{{#each definitions}}{{dictionary}}={{../primary}}{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'primary': 'JMdict',
          'definitions': [
            {'dictionary': 'KireiCake'},
          ],
        }),
        'KireiCake=JMdict',
      );
    });

    test('@root access', () {
      const t = '{{#each definitions}}{{@root.expression}}{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'expression': '読む',
          'definitions': [
            {'dictionary': 'KireiCake'},
          ],
        }),
        '読む',
      );
    });

    test('scope block', () {
      const t =
          '{{#scope}}{{set "any" false}}{{#if (op "!" (get "any"))}}none{{/if}}{{/scope}}';
      expect(HandlebarsEngine.render(t, {}), 'none');
    });
  });

  group('jp-mining-note style patterns', () {
    test('glossary-single partial chain', () {
      const t =
          '{{#*inline "glossary-single"}}'
          '{{#if (op "<=" glossary.length 1)}}'
          '{{#each glossary}}{{.}}{{/each}}'
          '{{else}}'
          '<ul>{{#each glossary}}<li>{{.}}</li>{{/each}}</ul>'
          '{{/if}}'
          '{{/inline}}'
          '{{~> glossary-single definition glossary=glossary ~}}';
      expect(
        HandlebarsEngine.render(t, {
          'glossary': ['to read'],
        }),
        'to read',
      );
    });

    test('dictionary categorization', () {
      const t =
          r'{{~set "bilingual-dict-regex" "^(([Jj][Mm][Dd]ict)(.*))$" ~}}'
          '{{~#regexMatch (get "bilingual-dict-regex") "gu"~}}'
          '{{dictionaryName}}'
          '{{~/regexMatch~}}';
      expect(
        HandlebarsEngine.render(t, {'dictionaryName': 'JMdict (English)'}),
        'JMdict (English)',
      );
      expect(HandlebarsEngine.render(t, {'dictionaryName': '大辞林'}), '');
    });

    test('frequency harmonic sort', () {
      const t =
          '{{#each frequencies}}{{frequency}}{{#unless @last}},{{/unless}}{{/each}}';
      expect(
        HandlebarsEngine.render(t, {
          'frequencies': [
            {'frequency': '440'},
            {'frequency': '1200'},
          ],
        }),
        '440,1200',
      );
    });
  });
}
