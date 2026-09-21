import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/repositories/ai_repository.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/presentation/providers/ai_provider.dart';

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

  AiLessonGenerator({
    required this.repo,
    required this.srs,
    required this.deckId,
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
  String _provider = 'auto';
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _selected == null ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'Generating…' : 'Generate'),
              ),
            ),
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
