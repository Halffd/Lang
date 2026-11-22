import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/live_ocr/live_ocr_service.dart';
import 'package:lang/core/services/live_ocr/live_ocr_stability_gate.dart';
import 'package:lang/data/services/ocr_service.dart';

void main() {
  group('normalizeOcrText', () {
    test('collapses whitespace runs and trims', () {
      expect(normalizeOcrText('  a \n\t b  '), 'a b');
    });

    test('keeps internal single spaces', () {
      expect(normalizeOcrText('a b'), 'a b');
    });

    test('empty and whitespace-only text normalize to empty', () {
      expect(normalizeOcrText(''), '');
      expect(normalizeOcrText('   \n '), '');
    });
  });

  group('LiveOcrStabilityGate', () {
    test('first reading is not stable when repeats are required', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 2);
      expect(gate.add('hello'), isFalse);
      expect(gate.repeatCount, 1);
    });

    test('passes once the same reading repeats enough times', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 2);
      expect(gate.add('hello'), isFalse);
      expect(gate.add('hello'), isTrue);
    });

    test('a different reading resets the repeat count', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 2);
      gate.add('hello');
      gate.add('hello');
      expect(gate.repeatCount, 2);
      expect(gate.add('world'), isFalse);
      expect(gate.repeatCount, 1);
    });

    test('cosmetic whitespace differences count as the same reading', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 2);
      expect(gate.add('hello world'), isFalse);
      expect(gate.add('hello  world\n'), isTrue);
    });

    test('empty readings reset the gate and never pass', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 1);
      expect(gate.add(''), isFalse);
      expect(gate.repeatCount, 0);
      expect(gate.isStable, isFalse);
    });

    test('requiredRepeats of 1 makes every reading stable', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 1);
      expect(gate.add('hello'), isTrue);
    });

    test('reset clears the state', () {
      final gate = LiveOcrStabilityGate(requiredRepeats: 2);
      gate.add('hello');
      gate.reset();
      expect(gate.repeatCount, 0);
      expect(gate.isStable, isFalse);
    });
  });

  group('LiveOcrService', () {
    late LiveOcrService service;

    setUp(() {
      service = LiveOcrService();
      service.gate.requiredRepeats = 2;
      service.frameSource = () async => LiveOcrFrame(
        bytes: Uint8List.fromList([1, 2, 3]),
      );
    });

    tearDown(() => service.dispose());

    test('an unstable reading is not exposed as stable text', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      await service.tick();
      expect(service.result?.sourceText, 'hello');
      expect(service.result?.stable, isFalse);
      expect(service.stableText, isNull);
    });

    test('a repeated reading becomes stable and is translated', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      final translated = <String>[];
      service.translator = (text) async {
        translated.add(text);
        return 'translated:$text';
      };

      await service.tick();
      await service.tick();
      await service.translationPending;

      expect(service.stableText, 'hello');
      expect(translated, ['hello']);
      expect(service.stableTranslation, 'translated:hello');
    });

    test('the translator is not called for unstable readings', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      var calls = 0;
      service.translator = (_) async {
        calls++;
        return 'x';
      };

      await service.tick();
      expect(calls, 0);
    });

    test('a changed reading restarts the stability count', () async {
      var text = 'hello';
      service.recognizer = (_) async => OcrResult(text: text);
      var calls = 0;
      service.translator = (_) async {
        calls++;
        return 'x';
      };

      await service.tick();
      text = 'world';
      await service.tick();
      expect(service.result?.stable, isFalse);
      expect(service.stableText, isNull);
      expect(calls, 0);
    });

    test('the same text is not translated twice', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      var calls = 0;
      service.translator = (_) async {
        calls++;
        return 'translated';
      };

      await service.tick();
      await service.tick();
      await service.tick();
      expect(calls, 1);
    });

    test('whitespace-only differences keep the translation', () async {
      var text = 'hello world';
      service.recognizer = (_) async => OcrResult(text: text);
      var calls = 0;
      service.translator = (_) async {
        calls++;
        return 'translated';
      };

      await service.tick();
      await service.tick();
      await service.translationPending;
      expect(service.stableTranslation, 'translated');

      // the engine re-read the same pixels with a line break
      text = 'hello  world\n';
      await service.tick();
      expect(calls, 1);
      expect(service.stableTranslation, 'translated');
    });

    test('a failed capture reports an error and no result', () async {
      service.frameSource = () async => const LiveOcrFrame();
      service.recognizer = (_) async => OcrResult(text: 'hello');
      await service.tick();
      expect(service.result, isNull);
      expect(service.lastError, isNotNull);
    });

    test('a failed OCR reports the backend error', () async {
      service.recognizer = (_) async => OcrResult(text: '', error: 'boom');
      await service.tick();
      expect(service.lastError, 'boom');
      expect(service.stableText, isNull);
    });

    test('stopping clears the stable text', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      await service.tick();
      await service.tick();
      expect(service.stableText, 'hello');

      service.stop();
      expect(service.stableText, isNull);
      expect(service.isRunning, isFalse);
    });

    test('a translation that lands after a stop is discarded', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      final completer = Completer<String>();
      service.translator = (_) => completer.future;

      await service.tick();
      await service.tick();
      // the second tick is stable and starts the translation
      final pending = service.translationPending;
      service.stop();
      completer.complete('late translation');
      await pending;

      expect(service.stableTranslation, isNull);
      expect(service.result, isNull);
    });

    test('a translation for superseded text is discarded', () async {
      var text = 'hello';
      service.recognizer = (_) async => OcrResult(text: text);
      final completer = Completer<String>();
      service.translator = (_) => completer.future;

      await service.tick();
      await service.tick();
      final pending = service.translationPending;
      // the screen changed while the translation was in flight
      text = 'world';
      await service.tick();
      completer.complete('translation of hello');
      await pending;

      expect(service.stableTranslation, isNull);
    });

    test('clear removes the current result', () async {
      service.recognizer = (_) async => OcrResult(text: 'hello');
      await service.tick();
      service.clear();
      expect(service.result, isNull);
      expect(service.lastError, isNull);
    });
  });
}
