import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:screenshot/screenshot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/data/repositories/srs_service.dart';

class AddCardSheet extends StatefulWidget {
  final SRSCard? editCard;
  final Future<void> Function(SRSCard) onSave;
  final SRSService srsService;

  const AddCardSheet({
    this.editCard,
    required this.onSave,
    required this.srsService,
    super.key,
  });

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  late TextEditingController _wordController;
  late TextEditingController _readingController;
  late TextEditingController _meaningController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  int _priority = 3;
  int _languageLevel = 3;
  bool _saving = false;
  String? _selectedDeck;
  String? _imageBase64;
  String? _audioBase64;
  String? _videoBase64;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final bool _isRecording = false;
  bool _isPlayingAudio = false;
  String? _recordedAudioPath;
  final screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.editCard?.word ?? '');
    _readingController = TextEditingController(
      text: widget.editCard?.reading ?? '',
    );
    _meaningController = TextEditingController(
      text: widget.editCard?.meaning ?? '',
    );
    _notesController = TextEditingController(
      text: widget.editCard?.notes ?? '',
    );
    _tagsController = TextEditingController(
      text: widget.editCard?.tags.join(', ') ?? '',
    );
    _priority = widget.editCard?.priority ?? 3;
    _languageLevel = widget.editCard?.languageLevel ?? 3;
    _selectedDeck = widget.editCard?.deck;
    _imageBase64 = widget.editCard?.imageBase64;
    _audioBase64 = widget.editCard?.audioBase64;
    _videoBase64 = widget.editCard?.videoBase64;

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _readingController.dispose();
    _meaningController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<String> _parseTags(String text) {
    return text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _pickImage() async {
    final picker = await _showMediaPickerDialog();
    if (picker == null) return;

    final bytes = await picker.readAsBytes();
    final ext = picker.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
    setState(() => _imageBase64 = base64);
  }

  Future<void> _takeScreenshot() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final base64 = 'data:image/png;base64,${base64Encode(image)}';
        setState(() => _imageBase64 = base64);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Screenshot captured!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Screenshot failed: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    final picker = await _showMediaPickerDialog(allowVideo: true);
    if (picker == null) return;

    final bytes = await picker.readAsBytes();
    final ext = picker.path.split('.').last.toLowerCase();
    String mimeType = 'video/mp4';
    if (ext == 'mov') {
      mimeType = 'video/quicktime';
    } else if (ext == 'webm')
      mimeType = 'video/webm';
    final base64 = 'data:$mimeType;base64,${base64Encode(bytes)}';
    setState(() => _videoBase64 = base64);
  }

  Future<void> _recordVideo() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission required')),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (video != null) {
        final file = File(video.path);
        final bytes = await file.readAsBytes();
        final base64 = 'data:video/mp4;base64,${base64Encode(bytes)}';
        setState(() => _videoBase64 = base64);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Video recording failed: $e')));
      }
    }
  }

  Future<File?> _showMediaPickerDialog({bool allowVideo = false}) async {
    return showDialog<File>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(allowVideo ? 'Select Media' : 'Select Image'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final picker = await _createImagePicker();
              if (picker != null) Navigator.pop(ctx, picker);
            },
            child: const ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
            ),
          ),
        ],
      ),
    );
  }

  Future<File?> _createImagePicker() async {
    // Implementation would use ImagePicker
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Screenshot(
        controller: screenshotController,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.editCard != null ? 'Edit Card' : 'Add Card'),
            actions: [
              if (widget.editCard != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle delete
                  },
                ),
            ],
          ),
          body: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: 'Word/Expression *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _readingController,
                decoration: const InputDecoration(
                  labelText: 'Reading (Kana/Pinyin)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meaningController,
                decoration: const InputDecoration(
                  labelText: 'Meaning *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedDeck,
                decoration: const InputDecoration(
                  labelText: 'Deck',
                  border: OutlineInputBorder(),
                ),
                items: widget.srsService.decks
                    .map(
                      (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedDeck = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priority: $_priority',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _priority.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$_priority',
                          onChanged: (v) =>
                              setState(() => _priority = v.round()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language Level: $_languageLevel',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _languageLevel.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$_languageLevel',
                          onChanged: (v) =>
                              setState(() => _languageLevel = v.round()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Media',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_imageBase64 != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_imageBase64!.split(',').last),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => _imageBase64 = null),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo),
                    label: const Text('Image'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _takeScreenshot,
                    icon: const Icon(Icons.screenshot_monitor),
                    label: const Text('Screenshot'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Video'),
                  ),
                ],
              ),
              if (_audioBase64 != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(
                        _isPlayingAudio ? Icons.stop : Icons.play_arrow,
                      ),
                      onPressed: _isPlayingAudio ? _stopAudio : _playAudio,
                    ),
                    title: const Text('Audio Recording'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _audioBase64 = null),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Recording...' : 'Record Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _saveCard,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.editCard != null ? 'Update' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveCard() async {
    if (_wordController.text.trim().isEmpty ||
        _meaningController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word and Meaning are required')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final card = SRSCard(
        id:
            widget.editCard?.id ??
            '${_wordController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
        word: _wordController.text.trim(),
        reading: _readingController.text.trim().isEmpty
            ? null
            : _readingController.text.trim(),
        meaning: _meaningController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tags: _parseTags(_tagsController.text),
        priority: _priority,
        languageLevel: _languageLevel,
        deck: _selectedDeck,
        imageBase64: _imageBase64,
        audioBase64: _audioBase64,
        videoBase64: _videoBase64,
        nextReview: DateTime.now(),
      );

      await widget.onSave(card);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startRecording() async {
    // Implementation for audio recording
  }

  Future<void> _stopRecording() async {
    // Implementation for stopping audio recording
  }

  Future<void> _playAudio() async {
    // Implementation for playing audio
  }

  Future<void> _stopAudio() async {
    // Implementation for stopping audio
  }
}
