import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = args[0];

  switch (command) {
    case 'translate':
      await handleTranslate(args.sublist(1));
      break;
    case 'search':
      await handleSearch(args.sublist(1));
      break;
    case 'help':
      printUsage();
      break;
    default:
      print('Unknown command: $command');
      printUsage();
      exit(1);
  }
}

void printUsage() {
  print('''
Lang CLI - Language learning command line tools

Usage:
  lang <command> [options]

Commands:
  translate <text>           Translate text
    --from=<lang>            Source language (default: auto)
    --to=<lang>              Target language (default: en)
    -p, --provider=<prov>    Provider: google, gemini, mlkit (default: google)

  search <query>            Search dictionary
    --lang=<lang>            Language (default: ja)
    --limit=<n>              Max results (default: 20)

  help                       Show this help

Examples:
  lang translate 日本語 --to=en
  lang search 食べる --lang=ja
  lang translate "Hello world" --from=en --to=ja
''');
}

Future<void> handleTranslate(List<String> args) async {
  String? fromLang;
  String toLang = 'en';
  String? provider;
  List<String> textArgs = [];

  for (final arg in args) {
    if (arg.startsWith('--from=')) {
      fromLang = arg.substring(7);
    } else if (arg.startsWith('--to=')) {
      toLang = arg.substring(5);
    } else if (arg.startsWith('--provider=') || arg == '-p') {
      provider = arg.contains('=') ? arg.substring(11) : null;
    } else if (!arg.startsWith('-')) {
      textArgs.add(arg);
    }
  }

  if (textArgs.isEmpty) {
    print('Error: No text provided');
    exit(1);
  }

  final text = textArgs.join(' ');

  print('Translating: $text');
  print('From: ${fromLang ?? "auto"} -> To: $toLang');

  // Simple Google Translate API call
  try {
    final result = await googleTranslate(text, fromLang ?? 'auto', toLang);
    print('\nResult:');
    print(result);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> handleSearch(List<String> args) async {
  String lang = 'ja';
  int limit = 20;
  String? query;

  for (final arg in args) {
    if (arg.startsWith('--lang=')) {
      lang = arg.substring(7);
    } else if (arg.startsWith('--limit=')) {
      limit = int.tryParse(arg.substring(8)) ?? 20;
    } else if (!arg.startsWith('-')) {
      query = arg;
    }
  }

  if (query == null || query.isEmpty) {
    print('Error: No search query provided');
    exit(1);
  }

  print('Searching for: $query (lang: $lang, limit: $limit)');
  print('\nNote: Full search requires database setup.');
  print('For now, showing basic lookup...');

  // Basic character analysis
  for (int i = 0; i < query.length; i++) {
    final char = query[i];
    final code = char.codeUnitAt(0);
    print('$char - U+${code.toRadixString(16).toUpperCase().padLeft(4, '0')}');
  }
}

Future<String> googleTranslate(String text, String sourceLang, String targetLang) async {
  final url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}';

  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = await response.transform(const SystemEncoding().decoder).join();
  client.close();

  // Parse JSON response
  return parseGoogleTranslateResponse(body);
}

String parseGoogleTranslateResponse(String json) {
  // Simple JSON parsing for Google Translate response
  // Response format: [["translated_text","original_text",null,"model",null],...]
  try {
    // Extract content between brackets
    final match = RegExp(r'\[\[\["([^"]*)"').firstMatch(json);
    if (match != null) {
      return match.group(1) ?? json;
    }
    return json;
  } catch (e) {
    return json;
  }
}