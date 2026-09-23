import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/datasources/supabase_data_source.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/repositories/ai_repository.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/presentation/providers/user_data_provider.dart';
import 'package:lang/presentation/providers/ai_provider.dart';
import 'ai_exercise_parser.dart';
import 'ai_lesson_page.dart';
import 'lesson_widgets.dart';

/// One user-configured prompt template for AI lesson generation.
class AiLessonTemplate {
  final String name;
  final String systemPrompt;
  final LessonTypeFocus focus;
  final int cardCount;

  const AiLessonTemplate({
    required this.name,
    required this.systemPrompt,
    this.focus = LessonTypeFocus.mixed,
    this.cardCount = 12,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'system': systemPrompt,
    'focus': focus.name,
    'count': cardCount,
  };

  factory AiLessonTemplate.fromJson(Map<String, dynamic> j) => AiLessonTemplate(
    name: j['name'] ?? 'Default',
    systemPrompt: j['system'] ?? '',
    focus:
        LessonTypeFocus.values.asNameMap()[j['focus']] ?? LessonTypeFocus.mixed,
    cardCount: j['count'] ?? 12,
  );
}

enum LessonTypeFocus {
  /// mix of everything we can grade
  mixed,

  /// focus on written practice (translation + spelling)
  written,

  /// focus on meaning recall (mc)
  meaning,

  /// looking at glyphs (kanji/characters only)
  glyph,
}

/// Generates a lesson deck by calling the AI provider with the selected
/// template. Result is parsed as JSON and bulk-added to SRS.
class AiLessonGenerator {
  final AiRepository repo;
  final SRSService srs;
  final String deckId;

  /// Optional: when wired, generated exercises also seed the shared bank.
  final SupabaseDataSource? supabaseDs;

  AiLessonGenerator({
    required this.repo,
    required this.srs,
    required this.deckId,
    this.supabaseDs,
  });

  /// Stable deck id derived from the template name so cards don't clash.
  static String deckIdFor(String name) {
    return 'ai_lesson_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }

  /// Load templates from storage. Defaults shipped in the app:
  static const kDefaultTemplates = [
    AiLessonTemplate(
      name: 'Daily words',
      systemPrompt:
          'Generate 12 Japanese vocabulary cards as JSON. Each card has keys: word, reading, meaning, example (short Japanese sentence). Target CEFR N5-level.',
      cardCount: 12,
    ),
    AiLessonTemplate(
      name: 'Grammar drill',
      systemPrompt:
          'Generate 8 grammar-pattern cards as JSON. Each card has: pattern (e.g., 「〜ませんか？」), description (what it means), exampleSentence (Japanese using the pattern).',
      cardCount: 8,
    ),
    AiLessonTemplate(
      name: 'Kanji only',
      systemPrompt:
          'Generate 10 kanji-focused cards as JSON. Each card: kanji (word), reading (hiragana), meaning (english).',
      focus: LessonTypeFocus.glyph,
      cardCount: 10,
    ),
    AiLessonTemplate(
      name: 'Writing practice',
      systemPrompt:
          'Generate 6 short Japanese sentences for handwriting/typing practice, with English translation. JSON with: word, meaning, reading.',
      focus: LessonTypeFocus.written,
      cardCount: 6,
    ),
  ];

  static Future<List<AiLessonTemplate>> load(StorageService storage) async {
    final raw = storage.getStringSync('ai_lesson_templates');
    if (raw == null || raw.isEmpty) return kDefaultTemplates.toList();
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AiLessonTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return kDefaultTemplates.toList();
    }
  }

  static Future<void> saveTemplates(
    StorageService s,
    List<AiLessonTemplate> templates,
  ) async {
    await s.setString(
      'ai_lesson_templates',
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  /// Call the configured AI provider. Returns the deck id created.
  Future<String> generateForTemplate(
    AiLessonTemplate template,
    String provider,
    String? apiKey,
  ) async {
    final userPrompt =
        '''${template.systemPrompt}

Return a JSON array (and nothing else — no markdown fences, no comment) where each element conforms to one of these exact shapes:
{"word":"<the vocabulary word>","reading":"<kana or latin reading>","meaning":"<translation>", "sentence":"<optional short example>"}
or
{"pattern":"<grammar pattern>", "description":"<what it does>", "example":"<Japanese sentence using it>"}

Card count: ${template.cardCount}.
''';

    final raw = await repo.generateText(userPrompt, provider, apiKey: apiKey);
    final cards = <SRSCard>[];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      for (final e in parsed) {
        final m = e as Map<String, dynamic>;
        final card = SRSCard(
          id: '${deckId}_${DateTime.now().millisecondsSinceEpoch}_${cards.length}',
          word: (m['word'] ?? m['kanji'] ?? m['pattern'] ?? '?').toString(),
          reading: m['reading']?.toString(),
          meaning: (m['meaning'] ?? m['description'] ?? '').toString(),
          deck: deckId,
          nextReview: DateTime.now(),
          tags: ['ai', template.name],
        );
        cards.add(card);
      }
    } catch (e) {
      throw FormatException('AI returned invalid JSON: $e\n\nRaw: $raw');
    }
    if (cards.isEmpty) {
      throw const FormatException('AI returned no usable cards');
    }
    await srs.bulkAddCards(cards);
    return deckId;
  }

  /// Bank-first hybrid: fetch pre-generated exercises (instant, free), then
  /// top up with live generation if short. Insert what we generate back into
  /// the bank so the next request doesn't pay for it again.
  Future<List<AiExercise>> getLesson(
    AiLessonTemplate template,
    String language,
    String provider,
    String? apiKey, {
    int limit = 50,
    Set<String> knownWords = const {},
  }) async {
    // 1) pre-generated bank (main languages = instant, zero cost per user)
    if (supabaseDs != null) {
      try {
        final rows = await supabaseDs!.fetchExerciseBank(
          language: language,
          level: template.name,
          limit: limit,
        );
        if (rows.length >= limit) {
          final bank = rows
              .whereType<Map<String, dynamic>>()
              .map(_exerciseFromBankRow)
              .toList();
          return bank.take(limit).toList();
        }
      } catch (_) {
        /* bank absent offline — fall through */
      }
    }

    // 2) full live generation for the whole request (bank short or missing)
    final raw = await generateInteractive(
      template.systemPrompt,
      provider,
      apiKey,
      limit: limit,
      knownWords: knownWords,
    );

    // 3) persist generated exercises into the bank for later reuse.
    if (supabaseDs != null && raw.isNotEmpty) {
      try {
        await supabaseDs?.insertExerciseBank(
          raw.map((e) => _bankRowFor(e, language, template.name)).toList(),
        );
      } catch (_) {
        /* seeding the bank is best-effort */
      }
    }
    return raw.take(limit).toList();
  }

  AiExercise _exerciseFromBankRow(Map<String, dynamic> r) {
    return AiExercise(
      type: r['type']?.toString() ?? 'flashcard',
      prompt: r['prompt']?.toString() ?? '',
      promptSub: r['prompt_sub']?.toString(),
      answer: r['answer']?.toString() ?? '',
      choices: (r['choices'] as List?)?.map((e) => e.toString()).toList(),
      pairs: (r['pairs'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(
            (p) => {
              'left': p['left'].toString(),
              'right': p['right'].toString(),
            },
          )
          .toList(),
      breakdown: (r['breakdown'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(AiBreakdownPart.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> _bankRowFor(
    AiExercise e,
    String language,
    String level,
  ) {
    return {
      'language': language,
      'level': level,
      'type': e.type,
      'prompt': e.prompt,
      'prompt_sub': e.promptSub,
      'answer': e.answer,
      'choices': e.choices,
      'pairs': e.pairs,
      'breakdown': e.breakdown == null
          ? null
          : [
              for (final b in e.breakdown!)
                {'char': b.char, 'reading': b.reading, 'meaning': b.meaning},
            ],
      'prompt_hash': e.prompt.toLowerCase().trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      ),
      'qa_status': 'pending',
      'source': 'user_ai',
    };
  }

  ///
  /// [knownWords] handling per review guidance: small vocab sets go into the
  /// prompt as a soft constraint; big sets are post-filtered only (else the
  /// prompt becomes a token disaster).
  Future<List<AiExercise>> generateInteractive(
    String systemPrompt,
    String provider,
    String? apiKey, {
    int limit = 50,
    Set<String> knownWords = const {},
  }) async {
    var userPrompt = '$systemPrompt\n\n$kAiLessonScratchPrompt';

    if (knownWords.isNotEmpty && knownWords.length <= 200) {
      final list = knownWords.take(200).join(', ');
      userPrompt +=
          '\n\nAvoid generating exercises made ONLY from these '
          'already-mastered words: $list. Each exercise must include at least '
          'one word NOT in this list.';
    }
    // Hard constraint trailing — models weigh the end more.
    userPrompt += '\n\nMax exercises: $limit.';

    final raw = await repo.generateText(userPrompt, provider, apiKey: apiKey);
    final result = AiLessonResult.parse(raw);

    var exercises = result.exercises;

    if (knownWords.length > 200) {
      exercises = exercises.where((e) {
        if (e.type == 'match') return true;
        final words = e.prompt.split(RegExp(r'\s+'));
        return words.any(
          (w) => !knownWords.contains(
            w.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' '),
          ),
        );
      }).toList();
    }

    exercises = exercises.take(limit).toList();
    if (exercises.isEmpty) {
      throw const FormatException('AI returned no usable exercises');
    }
    return exercises;
  }
}

/// Small widget in the study screen to pick an AI template and generate.
class AiDeckGeneratorSheet extends StatefulWidget {
  const AiDeckGeneratorSheet({super.key});

  @override
  State<AiDeckGeneratorSheet> createState() => _AiDeckGeneratorSheetState();
}

class _AiDeckGeneratorSheetState extends State<AiDeckGeneratorSheet> {
  List<AiLessonTemplate> _templates = [];
  AiLessonTemplate? _selected;
  bool _loading = false;
  String? _error;
  String _provider = 'Gemini';
  int _limit = 50;
  List<AiExercise>? _lastInteractive;
  final _apiController = TextEditingController();
  final _templateNameCtrl = TextEditingController();
  final _templatePromptCtrl = TextEditingController();
  bool _editingTemplate = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<StorageService>();
    final t = await AiLessonGenerator.load(s);
    if (!mounted) return;
    setState(() {
      _templates = t;
      _selected = t.isEmpty ? null : t.first;
      _provider = 'Gemini';
    });
  }

  Future<void> _generate() async {
    final t = _selected;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final aiProvider = context.read<AiProvider>();
      final srs = context.read<SRSService>();
      final generator = AiLessonGenerator(
        repo: aiProvider.repository,
        srs: srs,
        deckId: AiLessonGenerator.deckIdFor(t.name),
      );
      final newDeckId = await generator.generateForTemplate(
        t,
        _provider,
        _apiController.text.isEmpty ? null : _apiController.text,
      );
      // Ensure deck exists so the node appears
      if (!srs.decks.any((d) => d.id == newDeckId)) {
        await srs.addDeck(
          SrsDeck(
            id: newDeckId,
            name: t.name,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Generated "${t.name}" deck')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Generates an interactive typed-exercise lesson and opens [AiLessonPage].
  Future<void> _generateInteractive() async {
    final t = _selected;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final aiProvider = context.read<AiProvider>();
      final generator = AiLessonGenerator(
        repo: aiProvider.repository,
        srs: context.read<SRSService>(),
        deckId: AiLessonGenerator.deckIdFor(t.name),
      );
      final ds = context.read<UserDataProvider>().dataSource;
      final exercises = await generator.getLesson(
        t,
        context.read<AppState>().learningLanguage,
        _provider,
        _apiController.text.isEmpty ? null : _apiController.text,
        limit: _limit,
        knownWords: context.read<AppState>().savedWords.toSet(),
      );
      if (!mounted) return;
      setState(() {
        _lastInteractive = exercises;
        _loading = false;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AiLessonPage(lesson: AiLessonResult(exercises), title: t.name),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI-generated lesson',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<AiLessonTemplate>(
                    value: _selected,
                    isExpanded: true,
                    items: _templates
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selected = v;
                      if (v != null) {
                        _templateNameCtrl.text = v.name;
                        _templatePromptCtrl.text = v.systemPrompt;
                      }
                    }),
                  ),
                ),
                IconButton(
                  icon: Icon(_editingTemplate ? Icons.close : Icons.edit),
                  tooltip: 'Custom template',
                  onPressed: () => setState(() {
                    _editingTemplate = !_editingTemplate;
                    if (_editingTemplate && _selected != null) {
                      _templateNameCtrl.text = _selected!.name;
                      _templatePromptCtrl.text = _selected!.systemPrompt;
                    }
                  }),
                ),
              ],
            ),
            if (_editingTemplate) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _templateNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Template name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _templatePromptCtrl,
                decoration: const InputDecoration(
                  labelText: 'System prompt',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save as new'),
                    onPressed: _saveTemplateAsNew,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    onPressed: _deleteTemplate,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // limit selector
            Row(
              children: [
                const Text('Max exercises'),
                Expanded(
                  child: Slider(
                    value: _limit.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '$_limit',
                    onChanged: (v) => setState(() => _limit = v.round()),
                  ),
                ),
                Text('$_limit'),
              ],
            ),
            TextField(
              controller: _apiController,
              decoration: const InputDecoration(
                labelText: 'API key (optional)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading || _selected == null ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_loading ? 'Generating…' : 'Save deck'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _loading || _selected == null
                        ? null
                        : _generateInteractive,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play now'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Raw JSON + breakdown of the last generation
            if (_lastInteractive != null) ...[
              TextButton.icon(
                icon: const Icon(Icons.data_object, size: 16),
                label: const Text('View JSON'),
                onPressed: () => _showJson(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.travel_explore, size: 16),
                label: const Text('Word breakdown'),
                onPressed: () => _showBreakdown(),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'AI-generated cards are tagged "[ai]" and stored in a "{selected?.name ?? '
              '}" deck.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the raw JSON of the last generation in a dialog.
  void _showJson() {
    final ex = _lastInteractive;
    if (ex == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(
      ex
          .map(
            (e) => {
              'type': e.type,
              'prompt': e.prompt,
              if (e.promptSub != null) 'prompt_sub': e.promptSub,
              'answer': e.answer,
              if (e.choices != null) 'choices': e.choices,
              if (e.pairs != null) 'pairs': e.pairs,
              if (e.breakdown != null)
                'breakdown': e.breakdown!
                    .map(
                      (b) => {
                        'char': b.char,
                        if (b.reading != null) 'reading': b.reading,
                        'meaning': b.meaning,
                      },
                    )
                    .toList(),
            },
          )
          .toList(),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lesson JSON'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Per-character/word breakdown: reuse the JSON breakdown if present, else
  /// fetch per word via [BreakdownCache] (cached, so repeats don't refire).
  Future<void> _showBreakdown() async {
    final ex = _lastInteractive;
    if (ex == null || ex.isEmpty) return;
    final existing = [
      for (final e in ex) ...(e.breakdown ?? const <AiBreakdownPart>[]),
    ];
    if (existing.isNotEmpty) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => BreakdownSheet(parts: existing),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final aiProvider = context.read<AiProvider>();
      final cache = BreakdownCache(aiProvider.repository.breakdown);
      final words = ex
          .map((e) => e.prompt)
          .where((p) => p.trim().isNotEmpty)
          .take(20)
          .toSet(); // dedupe — cloze/match reuse vocab
      final fetched = <AiBreakdownPart>[];
      for (final w in words) {
        fetched.addAll(
          await cache.get(
            w,
            apiKey: _apiController.text.isEmpty ? null : _apiController.text,
          ),
        );
      }
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => BreakdownSheet(parts: fetched),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Breakdown failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveTemplateAsNew() async {
    final name = _templateNameCtrl.text.trim();
    final prompt = _templatePromptCtrl.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;
    final t = AiLessonTemplate(name: name, systemPrompt: prompt);
    final next = [..._templates.where((x) => x.name != name), t];
    final s = context.read<StorageService>();
    await AiLessonGenerator.saveTemplates(s, next);
    if (!mounted) return;
    setState(() {
      _templates = next;
      _selected = t;
      _editingTemplate = false;
    });
  }

  Future<void> _deleteTemplate() async {
    final name = _selected?.name;
    if (name == null) return;
    final next = _templates.where((x) => x.name != name).toList();
    final s = context.read<StorageService>();
    await AiLessonGenerator.saveTemplates(s, next);
    if (!mounted) return;
    setState(() {
      _templates = next;
      _selected = next.isEmpty ? null : next.first;
      _editingTemplate = false;
    });
  }

  @override
  void dispose() {
    _apiController.dispose();
    _templateNameCtrl.dispose();
    _templatePromptCtrl.dispose();
    super.dispose();
  }
}
