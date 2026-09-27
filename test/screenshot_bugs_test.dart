import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/presentation/screens/analyze_screen.dart';

void main() {
  group('DictionaryEntry structured definitions', () {
    // Regression: structured-content nodes went through Map.toString(),
    // producing Dart literal syntax that no jsonDecode can parse, so the
    // renderer fell back to showing the raw JSON string on the card.

    test('json-string columns with node elements round-trip as json', () {
      const raw =
          '[{"tag":"ul","lang":"ja","data":{"content":"sense-note"},'
          '"content":[{"tag":"li","content":"gone"}]}]';
      final entry = DictionaryEntry.fromJson({
        'term': 'example',
        'reading': 'ignored',
        'definitions': raw,
      });
      expect(entry.definitions, hasLength(1));
      // critical: the definition must parse back as valid JSON
      expect(() => jsonDecode(entry.definitions.first), returnsNormally);
      final decoded = jsonDecode(entry.definitions.first);
      expect((decoded as List).first['tag'], 'ul');
    });

    test('already-decoded lists with nodes are re-encoded as json', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'example',
        'reading': 'ignored',
        'definitions': [
          {'tag': 'li', 'content': 'sense-a'},
        ],
      });
      expect(entry.definitions, hasLength(1));
      expect(() => jsonDecode(entry.definitions.first), returnsNormally);
    });

    test('plain gloss lists stay as plain strings', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'dog',
        'reading': 'dog',
        'definitions': '["a cat", "a dog"]',
      });
      expect(entry.definitions, ['a cat', 'a dog']);
    });

    test('non-json strings pass through untouched', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'dog',
        'reading': 'dog',
        'definitions': 'just a gloss',
      });
      expect(entry.definitions, ['just a gloss']);
    });

    test('tag lists of plain strings keep working', () {
      final entry = DictionaryEntry.fromJson({
        'term': 'x',
        'reading': 'r',
        'definitions': [],
        'termTags': '["noun", "common"]',
      });
      expect(entry.termTags, ['noun', 'common']);
    });
  });

  group('measureSearchBarHeight', () {
    test('matches a single line at default zoom', () {
      expect(
        measureSearchBarHeight(text: '日本語', screenWidth: 1200, fontSize: 15),
        96,
      );
    });

    test('grows when zoomed text wraps onto more lines', () {
      const sentence = '嗯，魔鳞病痊愈以后，我精神好得很呢，每天准备四五顿饭都没问题';
      final base = measureSearchBarHeight(
        text: sentence,
        screenWidth: 1200,
        fontSize: 15,
      );
      // the sentence is short enough to fit on one line at this
      // width/zoom; at 2x zoom it must wrap and grow the bar
      final zoomed = measureSearchBarHeight(
        text: sentence,
        screenWidth: 1200,
        fontSize: 30,
      );
      expect(zoomed, greaterThan(base));
    });

    test('at 2x zoom the old 96px estimate did overflow this sentence', () {
      const sentence = '嗯，魔鳞病痊愈以后，我精神好得很呢，每天准备四五顿饭都没问题';
      // font 15 * 2x zoom = 30; the old fixed char-count estimate returned
      // 96 here; real wrapping needs more than that.
      final zoomed = measureSearchBarHeight(
        text: sentence,
        screenWidth: 1200,
        fontSize: 30,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: sentence,
          style: const TextStyle(fontSize: 30, height: 1.4),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1200 - 32 - 12 - 130 - 48 - 48 - 2);
      expect(
        96,
        lessThan(28 + 28 + tp.height),
        reason: '96px cannot hold the wrapped text at this zoom',
      );
      // the measured bar must cover: container padding 28 + field
      // content padding 28 + real text height
      expect(zoomed, greaterThanOrEqualTo(28 + 28 + tp.height));
    });

    test('clamps so a huge paste cannot eat the whole screen', () {
      final enormous = List.filled(2000, '字').join();
      final height = measureSearchBarHeight(
        text: enormous,
        screenWidth: 1200,
        fontSize: 15,
      );
      expect(height, lessThanOrEqualTo(288));
    });
  });
}
