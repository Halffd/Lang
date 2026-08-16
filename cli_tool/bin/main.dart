#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:lang_cli/utils/chinese_util.dart';
import 'package:lang_cli/utils/japanese_utils.dart';
import 'package:lang_cli/utils/html_sanitizer.dart';
import 'package:lang_cli/services/wiktionary_service.dart';
import 'package:lang_cli/services/translation_service.dart';

late final ArgParser pinyinParser;
late final ArgParser chineseParser;
late final ArgParser japaneseParser;
late final ArgParser lookupParser;
late final ArgParser wiktionaryParser;
late final ArgParser translateParser;
late final ArgParser sanitizeParser;
late final ArgParser parser;

void main(List<String> args) async {
  _initializeParsers();

  try {
    final results = parser.parse(args);

    if (results.wasParsed('help')) {
      printUsage(parser);
      return;
    }

    if (results.wasParsed('version')) {
      print('lang-cli 1.0.0');
      return;
    }

    final commandName = results.command?.name;
    if (commandName == null) {
      printUsage(parser);
      return;
    }

    final command = results.command!;

    switch (commandName) {
      case 'chinese':
        await handleChinese(command);
        break;
      case 'japanese':
        await handleJapanese(command);
        break;
      case 'wiktionary':
        await handleWiktionary(command);
        break;
      case 'translate':
        await handleTranslate(command);
        break;
      case 'sanitize':
        await handleSanitize();
        break;
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    printUsage(parser);
    exit(1);
  }
}

void _initializeParsers() {
  pinyinParser = ArgParser()
    ..addOption('format',
        abbr: 'f', allowed: ['tone', 'notone', 'number'], defaultsTo: 'tone')
    ..addOption('separator', abbr: 's', defaultsTo: ' ')
    ..addFlag('help', abbr: 'h', negatable: false);

  chineseParser = ArgParser()
    ..addCommand('pinyin', pinyinParser)
    ..addCommand('detect')
    ..addCommand('normalize')
    ..addCommand('variations')
    ..addFlag('help', abbr: 'h', negatable: false);

  japaneseParser = ArgParser()
    ..addCommand('romaji')
    ..addCommand('hiragana')
    ..addCommand('katakana')
    ..addCommand('detect')
    ..addCommand('kanji')
    ..addFlag('help', abbr: 'h', negatable: false);

  lookupParser = ArgParser()
    ..addOption('language', abbr: 'l', defaultsTo: 'en')
    ..addFlag('help', abbr: 'h', negatable: false);

  wiktionaryParser = ArgParser()
    ..addCommand('lookup', lookupParser)
    ..addFlag('help', abbr: 'h', negatable: false);

  translateParser = ArgParser()
    ..addOption('from', abbr: 'f', defaultsTo: 'auto')
    ..addOption('to', abbr: 't', defaultsTo: 'en')
    ..addOption('provider',
        abbr: 'p', allowed: ['google', 'gemini'], defaultsTo: 'google')
    ..addOption('gemini-key', abbr: 'k')
    ..addFlag('help', abbr: 'h', negatable: false);

  sanitizeParser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);

  parser = ArgParser()
    ..addCommand('chinese', chineseParser)
    ..addCommand('japanese', japaneseParser)
    ..addCommand('wiktionary', wiktionaryParser)
    ..addCommand('translate', translateParser)
    ..addCommand('sanitize', sanitizeParser)
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version');
}

void printUsage(ArgParser parser) {
  print('lang-cli - Language learning CLI tool');
  print('');
  print('Usage: lang <command> [arguments]');
  print('');
  print('Commands:');
  print('  chinese     Chinese text utilities');
  print('  japanese    Japanese text utilities');
  print('  wiktionary  Wiktionary lookup');
  print('  translate   Translate text');
  print('  sanitize    Sanitize HTML');
  print('');
  print('Run "lang <command> --help" for more information on a command.');
  print('');
  print('Global options:');
  print(parser.usage);
}

Future<void> handleChinese(ArgResults command) async {
  final subcommandName = command.command?.name;
  if (subcommandName == null) {
    print('Usage: lang chinese <subcommand>');
    print('Subcommands: pinyin, detect, normalize, variations');
    return;
  }

  final subcommand = command.command!;
  final args = subcommand.rest;
  if (args.isEmpty && subcommandName != 'detect') {
    stderr.writeln('Error: Missing text argument');
    exit(1);
  }

  final text = args.join(' ');

  switch (subcommandName) {
    case 'pinyin':
      final formatStr = subcommand['format'] as String;
      final separator = subcommand['separator'] as String;
      PinyinFormat format;
      switch (formatStr) {
        case 'notone':
          format = PinyinFormat.withoutTone;
          break;
        case 'number':
          format = PinyinFormat.withToneNumber;
          break;
        case 'tone':
        default:
          format = PinyinFormat.withToneMark;
      }
      final result = ChineseUtil.toPinyin(text, format: format);
      print(result.replaceAll(' ', separator));
      break;

    case 'detect':
      final inputText = args.isEmpty ? stdin.readLineSync() ?? '' : text;
      print('Contains Chinese: ${ChineseUtil.containsChinese(inputText)}');
      print(
          'Contains Japanese Kanji: ${ChineseUtil.containsJapaneseKanji(inputText)}');
      print(
          'Contains Ideographic: ${ChineseUtil.containsIdeographic(inputText)}');
      if (ChineseUtil.containsChinese(inputText)) {
        print('Pinyin: ${ChineseUtil.toPinyin(inputText)}');
        print('Initials: ${ChineseUtil.getPinyinInitials(inputText)}');
      }
      break;

    case 'normalize':
      print(ChineseUtil.normalizeForSearch(text));
      break;

    case 'variations':
      final variations = ChineseUtil.getAllSearchVariations(text);
      for (final v in variations) {
        print(v);
      }
      break;
  }
}

Future<void> handleJapanese(ArgResults command) async {
  final subcommandName = command.command?.name;
  if (subcommandName == null) {
    print('Usage: lang japanese <subcommand>');
    print('Subcommands: romaji, hiragana, katakana, detect, kanji');
    return;
  }

  final subcommand = command.command!;
  final args = subcommand.rest;
  if (args.isEmpty && subcommandName != 'detect') {
    stderr.writeln('Error: Missing text argument');
    exit(1);
  }

  final text = args.join(' ');

  switch (subcommandName) {
    case 'romaji':
      print(JapaneseUtils.toRomaji(text));
      break;
    case 'hiragana':
      print(JapaneseUtils.toHiragana(text));
      break;
    case 'katakana':
      print(JapaneseUtils.toKatakana(text));
      break;
    case 'detect':
      final inputText = args.isEmpty ? stdin.readLineSync() ?? '' : text;
      print('Contains Japanese: ${JapaneseUtils.containsJapanese(inputText)}');
      final kanji = JapaneseUtils.extractKanji(inputText);
      if (kanji.isNotEmpty) {
        print('Kanji found: ${kanji.join(', ')}');
      }
      print('Romaji: ${JapaneseUtils.toRomaji(inputText)}');
      break;
    case 'kanji':
      final kanji = JapaneseUtils.extractKanji(text);
      for (final k in kanji) {
        print(
            '$k: Kanji=${JapaneseUtils.isKanji(k)}, Hiragana=${JapaneseUtils.isHiragana(k)}, Katakana=${JapaneseUtils.isKatakana(k)}');
      }
      break;
  }
}

Future<void> handleWiktionary(ArgResults command) async {
  final subcommandName = command.command?.name;
  if (subcommandName == null) {
    print('Usage: lang wiktionary <subcommand>');
    print('Subcommands: lookup');
    return;
  }

  if (subcommandName == 'lookup') {
    final subcommand = command.command!;
    final args = subcommand.rest;
    if (args.isEmpty) {
      stderr.writeln('Error: Missing word argument');
      exit(1);
    }

    final word = args.join(' ');
    final language = subcommand['language'] as String;

    final service = WiktionaryService();
    try {
      final entries = await service.lookup(word, language: language);
      if (entries.isEmpty) {
        print('No entries found for "$word"');
      } else {
        for (final entry in entries) {
          print(entry);
          print('');
        }
      }
    } finally {
      service.dispose();
    }
  }
}

Future<void> handleTranslate(ArgResults command) async {
  final args = command.rest;
  if (args.isEmpty) {
    stderr.writeln('Error: Missing text to translate');
    exit(1);
  }

  final text = args.join(' ');
  final from = command['from'] as String;
  final to = command['to'] as String;
  final providerStr = command['provider'] as String;
  final geminiKey = command['gemini-key'] as String?;

  TranslationProvider provider;
  switch (providerStr) {
    case 'gemini':
      provider = TranslationProvider.gemini;
      break;
    case 'google':
    default:
      provider = TranslationProvider.googleCloud;
  }

  final service = TranslationService(
    geminiApiKey: geminiKey,
    provider: provider,
  );

  try {
    String sourceLang = from;
    if (sourceLang == 'auto') {
      sourceLang = _detectLanguage(text);
    }

    final request = TranslationRequest(
      sourceText: text,
      sourceLanguage: sourceLang,
      targetLanguage: to,
    );

    final result = await service.translate(request);
    print(result);
  } catch (e) {
    stderr.writeln('Translation error: $e');
    exit(1);
  }
}

Future<void> handleSanitize() async {
  final input = stdin.readLineSync() ?? '';
  final sanitized = HtmlSanitizer.sanitize(input);
  print(sanitized);
}

String _detectLanguage(String text) {
  if (JapaneseUtils.containsJapanese(text)) return 'ja';
  if (ChineseUtil.containsChinese(text)) return 'zh';
  if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko';
  if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) return 'ru';
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar';
  return 'en';
}
