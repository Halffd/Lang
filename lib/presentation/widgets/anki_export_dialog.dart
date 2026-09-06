import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:lang/data/services/anki_connect_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/entities/anki_note_data.dart';
import 'package:lang/domain/entities/anki_note_types.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';

/// Rich Anki export dialog for a word.
///
/// Fields: word, reading, sentence, secondary definitions, comments,
/// tags, deck, profile. Attachments: clipboard text, clipboard image
/// (or picked image / screenshot file), audio.
///
/// Hotkey: opened with backslash ('\') on selected word from the
/// analyze screen.
Future<void> showAnkiExportDialog(
  BuildContext context,
  AnalyzerProvider provider,
  AnalyzedWord word,
) {
  return showDialog(
    context: context,
    builder: (context) => AnkiExportDialog(provider: provider, word: word),
  );
}

class AnkiExportDialog extends StatefulWidget {
  final AnalyzerProvider provider;
  final AnalyzedWord word;

  const AnkiExportDialog({
    super.key,
    required this.provider,
    required this.word,
  });

  @override
  State<AnkiExportDialog> createState() => _AnkiExportDialogState();
}

class _AnkiExportDialogState extends State<AnkiExportDialog> {
  final _commentsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _sentenceController = TextEditingController();
  final _secondaryController = TextEditingController();

  bool _includeClipboardText = false;
  String _clipboardText = '';
  String? _imagePath;
  String? _audioUrl;
  bool _includeAudio = false;
  bool _saving = false;
  AnkiNoteType? _selectedNoteType;
  List<String> _decks = ['Default'];
  late String _selectedDeck;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _selectedDeck = appState.ankiDecks.contains(appState.currentAnkiDeck)
        ? appState.currentAnkiDeck
        : (appState.ankiDecks.isNotEmpty
              ? appState.ankiDecks.first
              : 'Default');
    _decks = List.from(appState.ankiDecks);
    if (_decks.isEmpty) _decks = ['Default'];
    _sentenceController.text = widget.word.sentence ?? '';
    _secondaryController.text = _buildSecondaryDefinitions();
    // seed tags from yomitan anki settings
    final ankiSettings = appState.yomitanOptions.activeProfile.anki;
    if (ankiSettings.tags.isNotEmpty) {
      _tagsController.text = ankiSettings.tags;
    }
    _loadClipboard();
    _loadDecks();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _tagsController.dispose();
    _sentenceController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  String _buildSecondaryDefinitions() {
    final w = widget.word;
    final parts = <String>[];
    if (w.ichiMoeDefinitions.isNotEmpty) {
      parts.addAll(w.ichiMoeDefinitions.take(5));
    }
    if (w.localDefinitions.isNotEmpty) {
      for (final d in w.localDefinitions.take(5)) {
        try {
          final g = d['glossary'];
          if (g is List) parts.add(g.join(', '));
        } catch (_) {}
      }
    }
    if (w.mdbgData != null) {
      parts.addAll(w.mdbgData!.definitions.take(5));
    }
    return parts.join('; ');
  }

  Future<void> _loadClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      if (data?.text != null && data!.text!.isNotEmpty) {
        setState(() {
          _clipboardText = data.text!;
          _includeClipboardText = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDecks() async {
    final appState = context.read<AppState>();
    final ankiEnabled =
        appState.ankiConnectEnabled ||
        appState.yomitanOptions.activeProfile.anki.enabled;
    if (!ankiEnabled) return;
    final url = appState.yomitanOptions.activeProfile.anki.enabled
        ? appState.yomitanOptions.activeProfile.anki.serverAddress
        : appState.ankiConnectUrl;
    try {
      final service = AnkiConnectService(url);
      final decks = await service.getDeckNames();
      if (decks.isNotEmpty && mounted) {
        setState(() {
          _decks = decks;
          if (!decks.contains(_selectedDeck)) {
            _selectedDeck = decks.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Pick clipboard image / screenshot',
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _imagePath = result.files.single.path);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      dialogTitle: 'Pick audio file (or leave empty for auto audio)',
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _audioUrl = result.files.single.path);
    }
  }

  Future<void> _export() async {
    final appState = context.read<AppState>();
    setState(() => _saving = true);

    final w = widget.word;

    // Build note data from the analyzed word + dialog inputs
    final noteData = AnkiNoteData.fromAnalyzedWord(
      w,
      language: appState.learningLanguage,
      hint: _commentsController.text.trim().isNotEmpty
          ? _commentsController.text.trim()
          : null,
      clipboardText: _includeClipboardText && _clipboardText.isNotEmpty
          ? _clipboardText
          : null,
      clipboardImagePath: _imagePath,
      audioPath: _audioUrl,
      selectionText: _sentenceController.text.trim().isNotEmpty
          ? _sentenceController.text.trim()
          : null,
    );

    // Note type: user selection, kanji auto-detect for single kanji
    final noteTypes = appState.ankiNoteTypes;
    final typeConfig = _selectedNoteType != null
        ? noteTypes.byType(_selectedNoteType!)
        : (noteData.type == NoteDataType.kanji
              ? noteTypes.byType(AnkiNoteType.kanji)
              : noteTypes.byType(AnkiNoteType.expression));

    final fields = <String, String>{
      for (final f in typeConfig.fields)
        if (f.name.isNotEmpty)
          f.name: AnkiMarkerRenderer.render(
            f.value,
            noteData,
            markerTemplates: noteTypes.markerTemplates,
          ),
    };

    final tags = _tagsController.text
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      final ankiSettings = appState.yomitanOptions.activeProfile.anki;
      final ankiEnabled = appState.ankiConnectEnabled || ankiSettings.enabled;
      if (ankiEnabled) {
        // yomitan anki server address wins when its integration is on
        final serverUrl = ankiSettings.enabled
            ? ankiSettings.serverAddress
            : appState.ankiConnectUrl;
        final service = AnkiConnectService(serverUrl);

        final noteId = await service.addNote(
          deckName: _selectedDeck,
          modelName: typeConfig.model,
          fields: fields,
          tags: tags,
          audio: (_includeAudio && _audioUrl != null && _audioUrl!.isNotEmpty)
              ? {
                  'path': _audioUrl!,
                  'filename': 'audio_${w.word}',
                  'fields': [typeConfig.fields.first.name],
                }
              : null,
          picture: _imagePath != null
              ? {
                  'path': _imagePath!,
                  'filename': 'img_${w.word}.png',
                  'fields': [
                    typeConfig.field('Picture').name.isNotEmpty
                        ? typeConfig.field('Picture').name
                        : typeConfig.fields.first.name,
                  ],
                }
              : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                noteId != null
                    ? 'Added to Anki deck $_selectedDeck'
                    : 'Word already exists in deck',
              ),
            ),
          );
        }
        // suspend new cards when configured
        if (ankiSettings.suspendNewCards && noteId != null) {
          try {
            await service.suspendCard(noteId);
          } catch (_) {}
        }
        // optional force sync
        if (ankiSettings.forceSyncOnAddingCard) {
          await service.forceSync();
        }
      } else {
        // AnkiConnect disabled: save to local Anki words list
        appState.addAnkiWord(w.word);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Saved to local Anki word list (AnkiConnect disabled)',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Anki export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = widget.word;

    return AlertDialog(
      title: Text('Export to Anki: ${w.word}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // word + reading row
              Row(
                children: [
                  Text(
                    w.word,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (w.reading != null && w.reading!.isNotEmpty)
                    Text(w.reading!, style: TextStyle(color: theme.hintColor)),
                ],
              ),
              const SizedBox(height: 12),

              _sectionLabel('Note type'),
              DropdownButtonFormField<AnkiNoteType>(
                initialValue: _selectedNoteType,
                hint: const Text('Auto (kanji detection)'),
                items: const [
                  DropdownMenuItem(
                    value: AnkiNoteType.expression,
                    child: Text('Expression (term)'),
                  ),
                  DropdownMenuItem(
                    value: AnkiNoteType.reading,
                    child: Text('Reading'),
                  ),
                  DropdownMenuItem(
                    value: AnkiNoteType.kanji,
                    child: Text('Kanji'),
                  ),
                  DropdownMenuItem(
                    value: AnkiNoteType.name,
                    child: Text('Name'),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedNoteType = v);
                  if (v != null) {
                    // default deck follows the note type config
                    final cfg = context.read<AppState>().ankiNoteTypes.byType(
                      v,
                    );
                    if (cfg.deck.isNotEmpty) {
                      setState(() => _selectedDeck = cfg.deck);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),

              _sectionLabel('Deck'),
              DropdownButtonFormField<String>(
                initialValue: _selectedDeck,
                items: _decks
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedDeck = v ?? _selectedDeck),
              ),
              const SizedBox(height: 12),

              _sectionLabel('Profile'),
              Text(
                'Current: ${context.read<AppState>().currentProfile}',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
              const SizedBox(height: 12),

              _sectionLabel('Sentence'),
              TextField(
                controller: _sentenceController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              _sectionLabel('Secondary definitions'),
              TextField(
                controller: _secondaryController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Auto-filled from dictionaries',
                ),
              ),
              const SizedBox(height: 12),

              _sectionLabel('Comments'),
              TextField(
                controller: _commentsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              _sectionLabel('Tags (space or comma separated)'),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'e.g. jlpt-n5 verb',
                ),
              ),
              const SizedBox(height: 12),

              // Attachments
              _sectionLabel('Attachments'),
              if (_clipboardText.isNotEmpty)
                CheckboxListTile(
                  dense: true,
                  title: const Text('Include clipboard text'),
                  subtitle: Text(
                    _clipboardText.length > 80
                        ? '${_clipboardText.substring(0, 80)}...'
                        : _clipboardText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: _includeClipboardText,
                  onChanged: (v) =>
                      setState(() => _includeClipboardText = v ?? false),
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.image),
                title: Text(
                  _imagePath != null
                      ? 'Image: ${_imagePath!.split('/').last}'
                      : 'Attach clipboard image / screenshot',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Pick image file',
                      onPressed: _pickImage,
                    ),
                    if (_imagePath != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Remove image',
                        onPressed: () => setState(() => _imagePath = null),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                dense: true,
                title: const Text('Attach audio'),
                subtitle: Text(
                  _audioUrl != null
                      ? _audioUrl!.split('/').last
                      : 'Auto-fetch audio on export (or pick file)',
                ),
                value: _includeAudio,
                onChanged: (v) async {
                  if (v && _audioUrl == null) {
                    await _pickAudio();
                  }
                  setState(() => _includeAudio = v);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _export,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
