/// Tool: seed exercise_bank with AI-generated exercises
library;

/// Exercise-bank seeder: generates ~500 exercises per main language via AI
/// and inserts into the public.exercise_bank table with dedupe (prompt_hash).
///
/// Run:
///   SUPABASE_URL=https://your.supabase.co SUPABASE_SERVICE_KEY=... \
///   AI_API_KEY=... dart tool/generate_bank.dart [--langs ja,es] [--count 500]
///
/// QA pass afterwards: rows land with qa_status='pending' so a reviewer can
/// re-run the second AI pass on the bank offline without user-facing latency.
import 'dart:convert';
import 'dart:io';

const _schemaPrompt = '''
Return ONLY a JSON array (no markdown). Each item is an exercise:
{"type":"flashcard","prompt":"word or sentence","prompt_sub":"reading","answer":"translation"}
{"type":"mc","prompt":"word","prompt_sub":"reading","choices":["a","b","c","d"],"answer":"<one of choices>"}
{"type":"written","prompt":"translation prompt","answer":"<the language text>"}
{"type":"cloze","prompt":"sentence with ____ blank","answer":"<missing word>","choices":["o1","o2","o3","o4"]}
{"type":"match","pairs":[{"left":"a","right":"b"},{"left":"c","right":"d"}],"answer":""}
{"type":"listening","prompt":"word to hear","choices":["a","b","c","d"],"answer":"a"}
{"type":"spoken","prompt":"word to repeat","answer":"word"}
Per-character breakdown optional: "breakdown":[{"char":"漢","reading":"かん","meaning":"character"}].
''';

const _langs = {
  'ja': 'Japanese (JLPT N5-level)',
  'es': 'Spanish (A1-A2 CEFR)',
  'fr': 'French (A1-A2 CEFR)',
  'de': 'German (A1-A2 CEFR)',
  'ko': 'Korean (TOPIK 1)',
  'zh': 'Mandarin (HSK 1-2)',
  'pt': 'Portuguese (A1-A2)',
  'it': 'Italian (A1-A2)',
};

const _levels = ['A1', 'A2'];

Future<String> callAi(String prompt, String apiKey) async {
  // Best-effort provider: Cheerable Gemini endpoint (works without SDK).
  // Swap the URL per provider if needed; this tool is for admin offline use.
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
  );
  final client = HttpClient();
  final req = await client.postUrl(uri);
  req.headers.contentType = ContentType.json;
  req.write(
    jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 8192},
    }),
  );
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    throw HttpException('Gemini ${res.statusCode}: $body');
  }
  final decoded = jsonDecode(body);
  return decoded['candidates'][0]['content']['parts'][0]['text'] as String;
}

Future<int> insert(
  String url,
  String key,
  List<Map<String, dynamic>> rows,
) async {
  final client = HttpClient();
  final req = await client.postUrl(
    Uri.parse(
      '$url/rest/v1/exercise_bank?on_conflict=language,level,type,prompt_hash',
    ),
  );
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  req.headers.set('Prefer', 'resolution=merge-duplicates');
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode(rows));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return rows.length;
  }
  throw HttpException('supabase insert ${res.statusCode}: $body');
}

String normalizeHash(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

List<Map<String, dynamic>> toBankRows(
  List<Map<String, dynamic>> exercises,
  String language,
  String level,
) {
  return exercises
      .map(
        (e) => {
          'language': language,
          'level': level,
          'type': (e['type'] ?? 'flashcard').toString(),
          'prompt': (e['prompt'] ?? '').toString(),
          'prompt_sub': e['prompt_sub']?.toString(),
          'answer': (e['answer'] ?? '').toString(),
          'choices': e['choices'],
          'pairs': e['pairs'],
          'breakdown': e['breakdown'],
          'prompt_hash': normalizeHash(e['prompt'].toString()),
          'qa_status': 'pending',
          'source': 'pregenerated',
        },
      )
      .where((r) => (r['prompt'] as String).isNotEmpty)
      .toList();
}

Future<void> main(List<String> args) async {
  String? langsRaw;
  int count = 500;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--langs' && i + 1 < args.length) langsRaw = args[i + 1];
    if (args[i] == '--count' && i + 1 < args.length) {
      count = int.tryParse(args[i + 1]) ?? 500;
    }
  }

  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_SERVICE_KEY'];
  final aiKey =
      Platform.environment['AI_API_KEY'] ??
      Platform.environment['GEMINI_API_KEY'];

  if (supabaseUrl == null || supabaseKey == null || aiKey == null) {
    stderr.writeln(
      'Set SUPABASE_URL, SUPABASE_SERVICE_KEY, AI_API_KEY (or GEMINI_API_KEY) first.',
    );
    exit(1);
  }

  final langs = langsRaw?.split(',') ?? _langs.keys.toList();
  final perCall = 25; // chunks to reduce request size
  var total = 0;

  for (final lang in langs) {
    final langDesc = _langs[lang] ?? lang;
    for (final level in _levels) {
      stdout.write('== $lang $level: ');
      var got = 0;
      var remaining = count ~/ (_levels.length * 1.0).round();
      final batches = (remaining ~/ perCall) + 1;
      for (var batch = 0; batch < batches && got < remaining; batch++) {
        final toGet = remaining - got;
        final prompt =
            '''Generate ${toGet.clamp(10, perCall)} exercises for $langDesc as requested:
- Cover nouns, verbs, adjectives, particles, simple sentences.
- Mix types: mc/cloze/written/flashcard/listening/spoken/match.
- Vary words AND sentence frames — no duplicate prompts.
- Use per-word breakdown when a prompt contains multi-char words.
$_schemaPrompt''';
        try {
          final raw = await callAi(prompt, aiKey);
          var clean = raw.trim();
          if (clean.startsWith('```')) {
            clean = clean
                .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
                .replaceAll(RegExp(r'```$'), '');
          }
          final list = jsonDecode(clean) as List<dynamic>;
          final rows = toBankRows(
            list.whereType<Map<String, dynamic>>().toList(),
            lang,
            level,
          );
          if (rows.isNotEmpty) {
            total += await insert(supabaseUrl, supabaseKey, rows);
            got += rows.length;
            stdout.write('');
            stdout.flush();
          }
        } catch (e) {
          stderr.writeln('  batch $batch failed: $e');
        }
        await Future.delayed(const Duration(seconds: 2)); // rate-limit
      }
      stdout.writeln('done ($got)');
    }
  }
  stdout.writeln(
    'Total inserted: $total rows onto exercise_bank (pending QA).',
  );
}
