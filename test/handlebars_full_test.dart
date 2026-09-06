import 'package:flutter_test/flutter_test.dart';
import 'package:lang/utils/handlebars_engine.dart';

/// Exhaustive HandlebarsEngine coverage: every operator, block
/// type, regex form, whitespace control, context path, helper,
/// partial, and error path the engine supports.
void main() {
  String R(String t, [Map<String, dynamic> d = const {}]) =>
      HandlebarsEngine.render(t, d);

  // ==========================================================
  // Text and expressions
  // ==========================================================

  group('text and expressions', () {
    test('empty template', () {
      expect(R(''), '');
    });

    test('whitespace-only template', () {
      expect(R('   \n  '), '   \n  ');
    });

    test('unicode text passes through', () {
      expect(R('日本語テキスト русский العربية'), '日本語テキスト русский العربية');
    });

    test('multiple variables mixed with text', () {
      expect(R('a {{x}} b {{y}} c', {'x': '1', 'y': '2'}), 'a 1 b 2 c');
    });

    test('nested path lookup', () {
      expect(
        R('{{definition.cloze.sentence}}', {
          'definition': {
            'cloze': {'sentence': '本を読む。'},
          },
        }),
        '本を読む。',
      );
    });

    test('array index path', () {
      expect(
        R('{{items.0}} and {{items.1}}', {
          'items': ['a', 'b'],
        }),
        'a and b',
      );
    });

    test('missing variable renders empty', () {
      expect(R('[{{missing}}]'), '[]');
    });

    test('null variable renders empty', () {
      expect(R('[{{x}}]', {'x': null}), '[]');
    });

    test('boolean true renders "true"', () {
      expect(R('{{flag}}', {'flag': true}), 'true');
    });

    test('integer renders without decimal', () {
      expect(R('{{n}}', {'n': 42}), '42');
    });

    test('double renders with decimal', () {
      expect(R('{{n}}', {'n': 3.5}), '3.5');
    });

    test('list renders toString form', () {
      expect(
        R('{{list}}', {
          'list': [1, 2],
        }),
        contains('1'),
      );
    });

    test('escaping covers all five entities', () {
      expect(R('{{v}}', {'v': '<>&"\'``'}), '&lt;&gt;&amp;&quot;&#x27;``');
    });

    test('triple stash does not escape', () {
      expect(R('{{{v}}}', {'v': '<b>&</b>'}), '<b>&</b>');
    });

    test('expression with extra spaces', () {
      expect(R('{{  x  }}', {'x': 'y'}), 'y');
    });
  });

  // ==========================================================
  // Comments
  // ==========================================================

  group('comments', () {
    test('simple comment', () {
      expect(R('a{{! note }}b'), 'ab');
    });

    test('tilde comment', () {
      expect(R('a{{~! note ~}}b'), 'ab');
    });

    test('multiline comment content ignored', () {
      expect(R('x{{~! multi\nline\ncomment ~}}y'), 'xy');
    });
  });

  // ==========================================================
  // Whitespace control
  // ==========================================================

  group('whitespace control ~', () {
    test('leading tilde trims left text', () {
      expect(R('a  {{~x}}', {'x': 'b'}), 'ab');
    });

    test('trailing tilde trims following text left', () {
      expect(R('{{x~}}  b', {'x': 'a'}), 'ab');
    });

    test('both tildes', () {
      expect(R('a  {{~x~}}  b', {'x': 'X'}), 'aXb');
    });

    test('newline trimmed before block open', () {
      expect(
        R('text\n{{~#if flag~}}\n  body\n{{~/if~}}\nmore', {'flag': true}),
        'textbodymore',
      );
    });

    test('tilde on else branch', () {
      // canonical handlebars: ~} right of open, ~else~ and ~/if~ eat
      // all surrounding whitespace -> 'a' + 'no' + 'b'
      expect(
        R('a {{~#if f~}} yes {{~else~}} no {{~/if~}} b', {'f': false}),
        'anob',
      );
    });
  });

  // ==========================================================
  // if / unless / else
  // ==========================================================

  group('if blocks', () {
    test('if with literal true', () {
      expect(R('{{#if true}}yes{{/if}}'), 'yes');
    });

    test('if with literal false renders else', () {
      expect(R('{{#if false}}yes{{else}}no{{/if}}'), 'no');
    });

    test('empty string falsy', () {
      expect(R('{{#if x}}yes{{else}}no{{/if}}', {'x': ''}), 'no');
    });

    test('zero falsy', () {
      expect(R('{{#if x}}yes{{else}}no{{/if}}', {'x': 0}), 'no');
    });

    test('"false" string falsy', () {
      expect(R('{{#if x}}yes{{else}}no{{/if}}', {'x': 'false'}), 'no');
    });

    test('non-empty string truthy', () {
      expect(R('{{#if x}}yes{{/if}}', {'x': 'a'}), 'yes');
    });

    test('empty list falsy', () {
      expect(R('{{#if l}}yes{{else}}no{{/if}}', {'l': <int>[]}), 'no');
    });

    test('non-empty list truthy', () {
      expect(
        R('{{#if l}}yes{{/if}}', {
          'l': [1],
        }),
        'yes',
      );
    });

    test('empty map falsy', () {
      expect(
        R('{{#if m}}yes{{else}}no{{/if}}', {'m': <String, dynamic>{}}),
        'no',
      );
    });

    test('missing value falsy', () {
      expect(R('{{#if missing}}yes{{else}}no{{/if}}'), 'no');
    });

    test('if with parenthesized condition', () {
      expect(
        R('{{#if (op "===" t "term")}}term{{else}}other{{/if}}', {'t': 'term'}),
        'term',
      );
    });
  });

  group('unless blocks', () {
    test('unless true renders nothing', () {
      expect(R('a{{#unless true}}x{{/unless}}b'), 'ab');
    });

    test('unless false renders body', () {
      expect(R('{{#unless false}}body{{/unless}}'), 'body');
    });

    test('unless with else', () {
      expect(
        R('{{#unless flag}}no-flag{{else}}flag{{/unless}}', {'flag': true}),
        'flag',
      );
    });
  });

  // ==========================================================
  // each
  // ==========================================================

  group('each blocks', () {
    test('scalar list with dot', () {
      expect(
        R('{{#each l}}{{.}}{{/each}}', {
          'l': ['x', 'y', 'z'],
        }),
        'xyz',
      );
    });

    test('map items with key access', () {
      expect(
        R('{{#each defs}}{{dictionary}}:{{reading}};{{/each}}', {
          'defs': [
            {'dictionary': 'JMdict', 'reading': 'よむ'},
            {'dictionary': 'KireiCake', 'reading': 'よむ'},
          ],
        }),
        'JMdict:よむ;KireiCake:よむ;',
      );
    });

    test('@index iteration', () {
      expect(
        R('{{#each l}}{{@index}}{{/each}}', {
          'l': ['a', 'b', 'c'],
        }),
        '012',
      );
    });

    test('@first only on first', () {
      expect(
        R('{{#each l}}{{#if @first}}F{{/if}}{{.}}{{/each}}', {
          'l': ['a', 'b'],
        }),
        'Fa b'.replaceAll(' ', ''),
      );
    });

    test('@last only on last', () {
      expect(
        R('{{#each l}}{{.}}{{#if @last}}L{{/if}}{{/each}}', {
          'l': ['a', 'b'],
        }),
        'abL',
      );
    });

    test('comma separator via unless @last', () {
      expect(
        R('{{#each l}}{{.}}{{#unless @last}},{{/unless}}{{/each}}', {
          'l': ['a', 'b', 'c'],
        }),
        'a,b,c',
      );
    });

    test('empty list with else', () {
      expect(R('{{#each l}}x{{else}}empty{{/each}}', {'l': <int>[]}), 'empty');
    });

    test('parent access inside each', () {
      expect(
        R('{{#each defs}}{{.}}={{../primary}};{{/each}}', {
          'primary': 'P',
          'defs': ['d1', 'd2'],
        }),
        'd1=P;d2=P;',
      );
    });

    test('nested each loops', () {
      expect(
        R('{{#each outer}}[{{#each inner}}{{.}}{{/each}}]{{/each}}', {
          'outer': [
            {
              'inner': ['a', 'b'],
            },
            {
              'inner': ['c'],
            },
          ],
        }),
        '[ab][c]',
      );
    });

    test('null in list renders empty', () {
      expect(
        R('{{#each l}}[{{.}}]{{/each}}', {
          'l': [null, 'a'],
        }),
        '[]​[a]'.replaceAll('​', ''),
      );
    });

    test('each over non-list renders nothing', () {
      expect(R('a{{#each x}}b{{/each}}c', {'x': 'str'}), 'ac');
    });
  });

  // ==========================================================
  // scope / with
  // ==========================================================

  group('scope blocks', () {
    test('scope preserves data access', () {
      expect(R('{{#scope}}{{x}}{{/scope}}', {'x': 'inner'}), 'inner');
    });

    test('scope isolates set variables between sibling scopes', () {
      // jpmn pattern: any-flag scoped per glossary
      const t =
          '{{#scope}}{{set "any" false}}{{#if (op "!" (get "any"))}}'
          'first{{/if}}{{/scope}}'
          '{{#scope}}{{set "any" true}}{{#if (get "any")}}second{{/if}}{{/scope}}';
      expect(R(t), 'firstsecond');
    });

    test('nested scopes with @root access', () {
      expect(
        R('{{#each defs}}{{#scope}}{{@root.word}}{{/scope}}{{/each}}', {
          'word': 'W',
          'defs': [
            {'d': 1},
            {'d': 2},
          ],
        }),
        'WW',
      );
    });
  });

  group('with blocks', () {
    test('with map context shifts lookup', () {
      expect(
        R('{{#with cloze}}{{sentence}}{{/with}}', {
          'cloze': {'sentence': 'S'},
        }),
        'S',
      );
    });

    test('with null renders nothing', () {
      expect(R('a{{#with x}}b{{/with}}c'), 'ac');
    });
  });

  // ==========================================================
  // set / get
  // ==========================================================

  group('set and get', () {
    test('set string literal', () {
      expect(R('{{set "mode" "harmonic" ~}}{{get "mode"}}'), 'harmonic');
    });

    test('set boolean true', () {
      expect(R('{{set "f" true ~}}{{#if (get "f")}}on{{/if}}'), 'on');
    });

    test('set boolean false', () {
      expect(
        R('{{set "f" false ~}}{{#if (get "f")}}on{{else}}off{{/if}}'),
        'off',
      );
    });

    test('set from data variable', () {
      expect(
        R('{{set "v" primary ~}}{{get "v"}}', {'primary': 'JMdict'}),
        'JMdict',
      );
    });

    test('set number', () {
      expect(R('{{set "n" 42 ~}}{{get "n"}}'), '42');
    });

    test('block set captures body as value', () {
      expect(
        R('{{~#set "name"~}}dictionaries{{~/set~}}{{get "name"}}'),
        'dictionaries',
      );
    });

    test('block set with variables in body', () {
      expect(
        R('{{~#set "sel"~}}{{x}}-{{y}}{{~/set~}}[{{get "sel"}}]', {
          'x': 'a',
          'y': 'b',
        }),
        '[a-b]',
      );
    });

    test('set overwrites previous value', () {
      expect(R('{{set "v" 1 ~}}{{set "v" 2 ~}}{{get "v"}}'), '2');
    });

    test('get unknown variable renders empty', () {
      expect(R('[{{get "nothing"}}]'), '[]');
    });

    test('set value with regex chars preserved', () {
      // regression: $ inside set value previously broke parsing
      expect(
        R(r'{{~set "rx" "^(([Jj][Mm])D(.+))$" ~}}[{{get "rx"}}]'),
        r'[^(([Jj][Mm])D(.+))$]',
      );
    });

    test('set value with parens preserved', () {
      expect(R(r'{{~set "rx" "^(a)(b)?$" ~}}[{{get "rx"}}]'), r'[^(a)(b)?$]');
    });

    test('get inside subexpression used by op', () {
      expect(R('{{set "n" 5 ~}}{{#if (op ">" (get "n") 3)}}big{{/if}}'), 'big');
    });

    test('variable persists across sibling nodes', () {
      expect(
        R('{{set "v" x ~}}first:{{get "v"}} second:{{get "v"}}', {'x': 'V'}),
        'first:V second:V',
      );
    });
  });

  // ==========================================================
  // op helper - comparisons
  // ==========================================================

  group('op comparisons', () {
    test('== string equality', () {
      expect(R('{{#if (op "==" a "x")}}eq{{/if}}', {'a': 'x'}), 'eq');
    });

    test('== different types coerced', () {
      expect(R('{{#if (op "==" a "1")}}eq{{/if}}', {'a': 1}), 'eq');
    });

    test('!= inequality', () {
      expect(R('{{#if (op "!=" a "x")}}ne{{/if}}', {'a': 'y'}), 'ne');
    });

    test('=== strict equal same type', () {
      expect(R('{{#if (op "===" a "term")}}s{{/if}}', {'a': 'term'}), 's');
    });

    test('=== strict unequal types', () {
      // 1 vs "1": runtimeType differs but toString equal -> false
      expect(R('{{#if (op "===" a "1")}}s{{else}}d{{/if}}', {'a': 1}), 'd');
    });

    test('!== strict inequality', () {
      expect(R('{{#if (op "!==" a 1)}}d{{/if}}', {'a': 2}), 'd');
    });

    test('< less than', () {
      expect(R('{{#if (op "<" a 5)}}lt{{/if}}', {'a': 3}), 'lt');
    });

    test('<= boundary', () {
      expect(R('{{#if (op "<=" a 5)}}le{{/if}}', {'a': 5}), 'le');
    });

    test('> greater than', () {
      expect(R('{{#if (op ">" a 5)}}gt{{/if}}', {'a': 9}), 'gt');
    });

    test('>= boundary', () {
      expect(R('{{#if (op ">=" a 5)}}ge{{/if}}', {'a': 5}), 'ge');
    });

    test('numeric strings compare as numbers', () {
      expect(R('{{#if (op "<" a "10")}}lt{{/if}}', {'a': '9'}), 'lt');
    });
  });

  group('op logical', () {
    test('&& both true', () {
      expect(
        R('{{#if (op "&&" a b)}}both{{/if}}', {'a': true, 'b': true}),
        'both',
      );
    });

    test('&& one false', () {
      expect(
        R('{{#if (op "&&" a b)}}both{{else}}no{{/if}}', {
          'a': true,
          'b': false,
        }),
        'no',
      );
    });

    test('|| either true', () {
      expect(
        R('{{#if (op "||" a b)}}yes{{/if}}', {'a': false, 'b': true}),
        'yes',
      );
    });

    test('|| both false', () {
      expect(
        R('{{#if (op "||" a b)}}yes{{else}}no{{/if}}', {
          'a': false,
          'b': false,
        }),
        'no',
      );
    });

    test('unary ! on true', () {
      expect(R('{{#if (op "!" flag)}}off{{/if}}', {'flag': false}), 'off');
    });

    test('unary ! on non-empty string', () {
      expect(
        R('{{#if (op "!" flag)}}off{{else}}on{{/if}}', {'flag': 'x'}),
        'on',
      );
    });

    test('unary ! on empty string', () {
      expect(R('{{#if (op "!" flag)}}off{{/if}}', {'flag': ''}), 'off');
    });

    test('nested logic', () {
      expect(
        R('{{#if (op "||" (op ">" n 10) (op "&&" m true))}}combo{{/if}}', {
          'n': 5,
          'm': true,
        }),
        'combo',
      );
    });

    test('unary minus', () {
      // {{op "-" 5}} isn't valid (needs 2 operands); unary via 2 args
      expect(R('{{#if (op "<" (op "-" 0 a) 1)}}neg{{/if}}', {'a': 5}), 'neg');
    });
  });

  group('op arithmetic', () {
    test('addition', () {
      expect(R('{{op "+" 1 2}}'), '3.0');
    });

    test('subtraction', () {
      expect(R('{{op "-" 10 4}}'), '6.0');
    });

    test('multiplication', () {
      expect(R('{{op "*" 3 4}}'), '12.0');
    });

    test('division', () {
      expect(R('{{op "/" 10 4}}'), '2.5');
    });

    test('modulo', () {
      expect(R('{{op "%" 10 3}}'), '1.0');
    });

    test('add with variables', () {
      expect(R('{{op "+" a b}}', {'a': 2, 'b': 3}), '5.0');
    });

    test('string numeric add coerces', () {
      expect(R('{{op "+" a b}}', {'a': '2', 'b': '3'}), '5.0');
    });

    test('addition inside each for counters', () {
      expect(
        R(
          '{{set "count" 0 ~}}{{#each l}}{{set "count" (op "+" (get "count") 1) ~}}{{/each}}{{get "count"}}',
          {
            'l': [1, 2, 3, 4],
          },
        ),
        '4.0',
      );
    });
  });

  group('op bit shift', () {
    test('>> floors like int shift', () {
      // jpmn uses (op ">>" x 0) to floor doubles
      expect(R('{{op ">>" 644.7 0}}'), '644');
    });

    test('>> zero on integer', () {
      expect(R('{{op ">>" 12 0}}'), '12');
    });

    test('>> actual shift', () {
      expect(R('{{op ">>" 8 2}}'), '2');
    });
  });

  group('op invalid', () {
    test('unknown operator renders empty', () {
      expect(R('[{{op "^^^" 1 2}}]'), '[]');
    });

    test('op with missing operand renders empty', () {
      expect(R('[{{op "+" 1}}]'), '[]');
    });
  });

  // ==========================================================
  // concat / spread / property / lookup helpers
  // ==========================================================

  group('built-in helpers', () {
    test('concat joins arguments', () {
      expect(R('{{concat a "-" b}}', {'a': 'x', 'b': 'y'}), 'x-y');
    });

    test('concat used to build variable names (jpmn pattern)', () {
      // {{set (concat "used_" .) true}} - not directly supported;
      // test concat output usage instead
      expect(R('{{concat "used_" "v5"}}'), 'used_v5');
    });

    test('spread merges lists', () {
      expect(
        R('{{#each (spread a b)}}{{.}}{{/each}}', {
          'a': ['x'],
          'b': ['y', 'z'],
        }),
        'xyz',
      );
    });

    test('property length of list', () {
      expect(
        R('{{#if (op ">" (property glossary "length") 1)}}many{{/if}}', {
          'glossary': ['a', 'b'],
        }),
        'many',
      );
    });

    test('property of map', () {
      expect(
        R('{{property m "k"}}', {
          'm': {'k': 'val'},
        }),
        'val',
      );
    });

    test('lookup maps key to value', () {
      expect(
        R('{{lookup m "b"}}', {
          'm': {'a': '1', 'b': '2'},
        }),
        '2',
      );
    });

    test('lookup missing key empty', () {
      expect(
        R('[{{lookup m "zz"}}]', {
          'm': {'a': '1'},
        }),
        '[]',
      );
    });
  });

  // ==========================================================
  // regexMatch / regexReplace
  // ==========================================================

  group('regexMatch', () {
    test('matching content passes through', () {
      expect(
        R('{{~#regexMatch "^JM" "u"~}}{{d}}{{~/regexMatch~}}', {'d': 'JMdict'}),
        'JMdict',
      );
    });

    test('non-matching content dropped', () {
      expect(
        R('{{~#regexMatch "^JM" "u"~}}{{d}}{{~/regexMatch~}}', {'d': '大辞林'}),
        '',
      );
    });

    test('pattern from variable', () {
      expect(
        R(
          '{{set "rx" "^K" ~}}{{~#regexMatch (get "rx") "gu"~}}{{d}}{{~/regexMatch~}}',
          {'d': 'KireiCake'},
        ),
        'KireiCake',
      );
    });

    test('character class patterns', () {
      expect(
        R('{{~#regexMatch "^[Jj][Mm]" "gu"~}}{{d}}{{~/regexMatch~}}', {
          'd': 'jmdict',
        }),
        'jmdict',
      );
    });

    test('alternation pattern', () {
      expect(
        R('{{~#regexMatch "^(JMdict|CEDICT)" "gu"~}}{{d}}{{~/regexMatch~}}', {
          'd': 'CEDICT',
        }),
        'CEDICT',
      );
    });

    test('tags pattern from jpmn (on-mim detection)', () {
      final out = R(
        r'{{~#regexMatch "(, |^)on-mim(, |$)" "gu"~}}{{t}}{{~/regexMatch~}}',
        {'t': 'n, on-mim, something'},
      );
      expect(out, 'n, on-mim, something');
    });

    test('regexMatch helper form (parenthesized)', () {
      expect(
        R('{{#if (regexMatch "^J" "" d)}}match{{else}}no{{/if}}', {
          'd': 'JMdict',
        }),
        'match',
      );
    });

    test('invalid pattern drops content, no crash', () {
      expect(
        R('{{~#regexMatch "[unclosed" "u"~}}{{d}}{{~/regexMatch~}}', {
          'd': 'x',
        }),
        '',
      );
    });
  });

  group('regexReplace', () {
    test('simple replacement', () {
      expect(
        R(
          '{{~#regexReplace "world" "there" "g"~}}hello world{{~/regexReplace~}}',
        ),
        'hello there',
      );
    });

    test('strip whitespace pattern from jpmn', () {
      expect(
        R(
          r'{{~#regexReplace "^\s+|\s+$" "" "g"~}}  padded  {{~/regexReplace~}}',
        ),
        'padded',
      );
    });

    test('capture group substitution', () {
      final out = R(
        '{{~#regexReplace "^(.+?)<rt>(.+?)</rt></ruby>" '
        '" '
        r'$1'
        '['
        r'$2'
        ']'
        r'" "g"~}}'
        'yomu<rt>よむ</rt></ruby>{{~/regexReplace~}}',
      );
      expect(out.trim(), 'yomu[よむ]');
    });

    test('global flag replaces all occurrences', () {
      expect(R('{{~#regexReplace "a" "b" "g"~}}aaa{{~/regexReplace~}}'), 'bbb');
    });

    test('replacement with variable content', () {
      expect(
        R('{{~#regexReplace "❌" "✖" "g"~}}{{f}}{{~/regexReplace~}}', {
          'f': '❌440❌',
        }),
        '✖440✖',
      );
    });

    test('span stripping pattern from jpmn', () {
      // handlebars string literals escape inner quotes as \"
      expect(
        R(
          '{{~#regexReplace "(<span class=\\"term\\">)|(</span>)" "" "g"~}}'
          'a<span class="term">b</span>c{{~/regexReplace~}}',
        ),
        'abc',
      );
    });

    test('first-line wrap pattern (jpmn opt-wrap-first-line)', () {
      final out = R(
        '{{~#regexReplace "^(.*?)<br>" "'
        r'$1'
        '|" "g"~}}line1<br>line2{{~/regexReplace~}}',
      );
      expect(out, 'line1|line2');
    });

    test('invalid pattern passes content through', () {
      expect(
        R('{{~#regexReplace "[bad" "x" "g"~}}keep{{~/regexReplace~}}'),
        'keep',
      );
    });
  });

  // ==========================================================
  // Inline partials
  // ==========================================================

  group('inline partials', () {
    test('partial sees outer data', () {
      const t = '{{#*inline "p"}}{{x}}{{/inline}}{{> p}}';
      expect(R(t, {'x': 'outer'}), 'outer');
    });

    test('partial invoked with explicit args', () {
      const t = '{{#*inline "p"}}[{{word}}]{{/inline}}{{> p word=term}}';
      expect(R(t, {'term': 'T'}), '[T]');
    });

    test('partial invoked multiple times', () {
      const t =
          '{{#*inline "p"}}({{x}}){{/inline}}'
          '{{> p x=1}}{{> p x=2}}{{> p x=3}}';
      expect(R(t), '(1)(2)(3)');
    });

    test('partial using each inside', () {
      const t =
          '{{#*inline "list"}}'
          '{{#each items}}<{{.}}>{{/each}}'
          '{{/inline}}'
          '{{> list items=l}}';
      expect(
        R(t, {
          'l': ['a', 'b'],
        }),
        '<a><b>',
      );
    });

    test('partial referencing another partial', () {
      const t =
          '{{#*inline "inner"}}I({{v}}){{/inline}}'
          '{{#*inline "outer"}}O[{{> inner v=x}}]{{/inline}}'
          '{{> outer x=7}}';
      expect(R(t), 'O[I(7)]');
    });

    test('partial with conditional content', () {
      const t =
          '{{#*inline "gloss"}}'
          '{{#if (op "<=" glossary.length 1)}}{{#each glossary}}{{.}}{{/each}}'
          '{{else}}<ul>{{#each glossary}}<li>{{.}}</li>{{/each}}</ul>'
          '{{/if}}'
          '{{/inline}}'
          '{{> gloss glossary=g1}}|{{> gloss glossary=g2}}';
      expect(
        R(t, {
          'g1': ['only'],
          'g2': ['a', 'b'],
        }),
        'only|<ul><li>a</li><li>b</li></ul>',
      );
    });

    test('unknown partial renders empty', () {
      expect(R('a{{> missing}}b'), 'ab');
    });

    test('partial args do not leak to next invocation', () {
      const t =
          '{{#*inline "p"}}{{word}}{{/inline}}'
          '{{> p word=a}}{{> p}}';
      expect(R(t, {'a': 'A'}), 'A');
    });

    test('whitespace controlled partial invocation', () {
      const t = '{{#*inline "p"}}x{{/inline}}a {{~> p ~}} b';
      // l~ trims 'a ' -> 'a'; r~ trims ' b' -> 'b'
      expect(R(t), 'axb');
    });
  });

  group('renderWithPartials', () {
    test('pre-registered partial invocation', () {
      final out = HandlebarsEngine.renderWithPartials(
        'Hello {{> name}}',
        {'name': '{{first}} {{last}}'},
        {'first': 'Ada', 'last': 'Lovelace'},
      );
      expect(out, 'Hello Ada Lovelace');
    });

    test('pre-registered partial with data access', () {
      final out = HandlebarsEngine.renderWithPartials(
        '{{> freq}}',
        {'freq': '{{#each frequencies}}{{frequency}},{{/each}}'},
        {
          'frequencies': [
            {'frequency': '440'},
            {'frequency': '1200'},
          ],
        },
      );
      expect(out, '440,1200,');
    });

    test('inline partial overrides pre-registered one', () {
      final out = HandlebarsEngine.renderWithPartials(
        '{{#*inline "p"}}inline-version{{/inline}}{{> p}}',
        {'p': 'pre-registered'},
        {},
      );
      expect(out, 'inline-version');
    });
  });

  // ==========================================================
  // Registered helpers (hasMedia / getMedia / custom)
  // ==========================================================

  group('registered helpers', () {
    test('custom helper with args', () {
      final out = HandlebarsEngine.render(
        '{{shout "hi"}}',
        {},
        helpers: {'shout': (String s) => '${s.toUpperCase()}!'},
      );
      expect(out, 'HI!');
    });

    test('helper in if condition (parenthesized)', () {
      final out = HandlebarsEngine.render(
        '{{#if (hasMedia "audio")}}has{{else}}none{{/if}}',
        {},
        helpers: {'hasMedia': (String m) => m == 'audio'},
      );
      expect(out, 'has');
    });

    test('helper result in triple stash (bare call)', () {
      final out = HandlebarsEngine.render(
        '{{{getMedia "clipboardText"}}}',
        {},
        helpers: {'getMedia': (String m) => 'media:$m'},
      );
      expect(out, 'media:clipboardText');
    });

    test('helper with multiple args', () {
      final out = HandlebarsEngine.render(
        '{{join a b}}',
        {'a': 'x', 'b': 'y'},
        helpers: {'join': (String a, String b) => '$a+$b'},
      );
      expect(out, 'x+y');
    });

    test('helper exception renders empty', () {
      final out = HandlebarsEngine.render(
        '[{{boom "x"}}]',
        {},
        helpers: {'boom': (String x) => throw Exception('nope')},
      );
      expect(out, '[]');
    });

    test('helper not registered renders empty', () {
      expect(R('[{{nope "x"}}]'), '[]');
    });
  });

  // ==========================================================
  // Context paths
  // ==========================================================

  group('context paths', () {
    test('../ escapes each scope', () {
      expect(
        R('{{#each items}}{{../root}}-{{.}};{{/each}}', {
          'root': 'R',
          'items': ['a', 'b'],
        }),
        'R-a;R-b;',
      );
    });

    test('../../ escapes two levels', () {
      expect(
        R('{{#each outer}}{{#each inner}}{{../../top}}{{/each}}{{/each}}', {
          'top': 'T',
          'outer': [
            {
              'inner': ['x'],
            },
          ],
        }),
        'T',
      );
    });

    test('@root bypasses each scope', () {
      expect(
        R('{{#each items}}{{@root.word}}{{/each}}', {
          'word': 'W',
          'items': [1, 2],
        }),
        'WW',
      );
    });

    test('@root from nested each', () {
      expect(
        R('{{#each o}}{{#each i}}{{@root.k}}{{/each}}{{/each}}', {
          'k': 'K',
          'o': [
            {
              'i': [1],
            },
            {
              'i': [2],
            },
          ],
        }),
        'KK',
      );
    });
  });

  // ==========================================================
  // Realistic jp-mining-note patterns
  // ==========================================================

  group('jp-mining-note realistic templates', () {
    test('full dictionary categorization flow', () {
      // real jpmn style: regexMatch body holds the dictionary name;
      // a wrapping block-set captures the match output as a value
      const t =
          r'{{~#set "bilingual" "^(JMdict \(English\))$" ~}}'
          r'{{~#set "utility" "^(JMdict Forms)$" ~}}'
          '{{#each definitions}}'
          '{{dictionary}}='
          r'{{~#set "match" ~}}'
          r'{{~#regexMatch (get "bilingual") "gu"~}}{{dictionary}}{{~/regexMatch~}}'
          r'{{~/set~}}'
          '{{~#if (op "!==" (get "match") "")}}bi;'
          '{{~else~}}'
          r'{{~#set "match" ~}}'
          r'{{~#regexMatch (get "utility") "gu"~}}{{dictionary}}{{~/regexMatch~}}'
          r'{{~/set~}}'
          '{{~#if (op "!==" (get "match") "")}}util;'
          '{{~else~}}mono;'
          '{{~/if~}}'
          '{{~/if~}}'
          '{{~/each}}';
      final out = R(t, {
        'definitions': [
          {'dictionary': 'JMdict (English)'},
          {'dictionary': 'JMdict Forms'},
          {'dictionary': '大辞林'},
        ],
      });
      expect(out, 'JMdict (English)=bi;JMdict Forms=util;大辞林=mono;');
    });

    test('glossary-single with dictionary tags', () {
      const t =
          '{{#*inline "glossary-single"}}'
          '{{#each definitionTags}}({{name}}){{/each}}'
          '[{{dictionary}}] '
          '{{#each glossary}}{{.}}{{#unless @last}} | {{/unless}}{{/each}}'
          '{{/inline}}'
          '{{> glossary-single }}';
      expect(
        R(t, {
          'definitionTags': [
            {'name': 'v5'},
            {'name': 'common'},
          ],
          'dictionary': 'JMdict',
          'glossary': ['read', 'study'],
        }),
        '(v5)(common)[JMdict] read | study',
      );
    });

    test('frequencies list with conditional disambiguation', () {
      const t =
          '{{#if (op ">" frequencies.length 0)}}'
          '{{#each frequencies}}'
          '{{#if (op "||" (op ">" ../uniqueExpressions.length 1) (op ">" ../uniqueReadings.length 1))}}'
          '({{expression}}) {{/if}}'
          '{{dictionary}}:{{frequency}}; '
          '{{/each}}'
          '{{/if}}';
      expect(
        R(t, {
          'frequencies': [
            {'dictionary': 'JPDB', 'frequency': '440'},
          ],
          'uniqueExpressions': ['a'],
          'uniqueReadings': ['b'],
        }),
        'JPDB:440; ',
      );
    });

    test('harmonic frequency computation in template', () {
      const t =
          '{{set "sum" 0 ~}}'
          '{{set "t" 0 ~}}'
          '{{#each frequencies}}'
          '{{set "sum" (op "+" (get "sum") (op "/" 1 (op "+" 0 this.frequency))) ~}}'
          '{{set "t" (op "+" (get "t") 1) ~}}'
          '{{/each}}'
          '{{op ">>" (op "/" (get "t") (get "sum")) 0}}';
      // 2 / (1/440 + 1/1200) ≈ 644 (float precision: 643-644)
      final out = R(t, {
        'frequencies': [
          {'frequency': 440},
          {'frequency': 1200},
        ],
      });
      expect(int.parse(out), closeTo(644, 2));
    });

    test('primary definition selection with grouping (termGrouped)', () {
      const t =
          '{{~#set "primary" "JMdict (English)" ~}}'
          '<ol>{{#each definitions}}'
          '{{#if (op "===" dictionary (get "primary"))}}'
          '<li>{{#each glossary}}{{.}}{{#unless @last}}; {{/unless}}{{/each}}</li>'
          '{{/if}}'
          '{{/each}}</ol>';
      expect(
        R(t, {
          'definitions': [
            {
              'dictionary': 'KireiCake',
              'glossary': ['other'],
            },
            {
              'dictionary': 'JMdict (English)',
              'glossary': ['read', 'study'],
            },
          ],
        }),
        '<ol><li>read; study</li></ol>',
      );
    });

    test('sentence bolded furigana (jpmn-sentence-bolded-furigana-plain)', () {
      const t =
          r'{{~#regexReplace "(<span class=\\"term\\">)|(</span>)" "" "g"~}}'
          r'{{~#regexReplace "<ruby>(.+?)<rt>(.+?)</rt></ruby>" " $1[$2]" "g"~}}'
          '{{prefix}}<b>{{body}}</b>{{suffix}}'
          '{{~/regexReplace~}}'
          '{{~/regexReplace~}}';
      expect(
        R(t, {'prefix': '本を', 'body': '読む', 'suffix': '。'}),
        '本を<b>読む</b>。',
      );
    });

    test('conditional card type flags (jpmn pattern)', () {
      const t = r'{{~#set "grammar-regex" "^日本語文法辞典" ~}}'
          r'{{~set "is-grammar" "no" ~}}'
          '{{#each definitions}}'
          r'{{~#set "match" ~}}'
          r'{{~#regexMatch (get "grammar-regex") "gu"~}}{{dictionary}}{{~/regexMatch~}}'
          r'{{~/set~}}'
          '{{~#if (op "!==" (get "match") "")}}'
          r'{{~set "is-grammar" "yes" ~}}'
          '{{~/if~}}'
          '{{/each}}'
          '{{#if (op "===" (get "is-grammar") "yes")}}sentence-card{{else}}word-card{{/if}}';
      expect(
        R(t, {
          'definitions': [
            {'dictionary': 'JMdict'},
            {'dictionary': '日本語文法辞典(全集)'},
          ],
        }),
        'sentence-card',
      );
      expect(
        R(t, {
          'definitions': [
            {'dictionary': 'JMdict'},
          ],
        }),
        'word-card',
      );
    });

    test('selection-text detection chain', () {
      // simplified _jpmn-selection-text: trim clipboard content
      const t =
          r'{{~#regexReplace "^\s+|\s+$" "" "g"~}}'
          '{{selection}}{{~/regexReplace~}}';
      expect(R(t, {'selection': '  selected text  '}), 'selected text');
      expect(R(t, {'selection': ''}), '');
    });
  });

  // ==========================================================
  // Robustness / error handling
  // ==========================================================

  group('robustness', () {
    test('unterminated block renders gracefully', () {
      // no closing tag: block body to EOF
      expect(R('{{#if x}}text', {'x': true}), contains('text'));
    });

    test('stray closing tag ignored', () {
      expect(R('a{{/if}}b'), 'ab');
    });

    test('unclosed paren in condition no crash', () {
      expect(R('{{#if (op "+" 1}}x{{/if}}'), isNotNull);
    });

    test('deeply nested blocks', () {
      const t = '{{#if a}}{{#if b}}{{#if c}}abc{{/if}}{{/if}}{{/if}}';
      expect(R(t, {'a': true, 'b': true, 'c': true}), 'abc');
      expect(R(t, {'a': true, 'b': true, 'c': false}), '');
    });

    test('tags inside text strings are literal', () {
      // braces in plain text that don't form {{ }} stay
      expect(R('{ single }'), '{ single }');
    });

    test('empty tag renders empty', () {
      expect(R('a{{}}b'), 'ab');
    });

    test('large template performance sane', () {
      final words = List.generate(
        100,
        (i) => {
          'dictionary': 'd$i',
          'glossary': ['g$i'],
        },
      );
      final t =
          '{{#each definitions}}{{dictionary}}:{{#each glossary}}{{.}}{{/each}};{{/each}}';
      final out = R(t, {'definitions': words});
      expect(out.length, greaterThan(700));
      expect(out.startsWith('d0:g0;'), true);
    });
  });
}
