import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/clipboard_manager_service.dart';
import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Input mode for the scanner screen.
enum ScannerMode { scanner, text }

/// Mobile text scanner (Kaku-style): capture or pick an image, run OCR,
/// show detected text blocks for selection, and push the selected text
/// into the universal clipboard manager + popup dictionary. A text mode
/// accepts typed/pasted text through the same pipeline.
///
/// Desktop: camera is unavailable; gallery/file pick + text mode still
/// work through the same OCR services.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _textCtrl = TextEditingController();
  final Set<int> _selectedBlocks = <int>{};
  List<OcrTextBlock> _blocks = [];
  String _fullText = '';
  bool _processing = false;
  String? _error;
  ScannerMode _mode = ScannerMode.scanner;
  Uint8List? _lastImage;

  final OcrService _ocr = OcrService();

  @override
  void dispose() {
    _textCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // capture + OCR
  // ------------------------------------------------------------

  /// Camera capture (mobile) → OCR.
  Future<void> _scanCamera() async {
    final picker = ImagePicker();
    final XFile? photo;
    try {
      photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'camera unavailable: $e');
      return;
    }
    if (photo == null) return;
    await _processFile(photo.path);
  }

  /// Gallery pick (mobile + desktop) → OCR.
  Future<void> _scanGallery() async {
    final picker = ImagePicker();
    final XFile? image;
    try {
      image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'gallery unavailable: $e');
      return;
    }
    if (image == null) return;
    await _processFile(image.path);
  }

  Future<void> _processFile(String path) async {
    setState(() {
      _processing = true;
      _error = null;
      _selectedBlocks.clear();
    });
    try {
      final bytes = await File(path).readAsBytes();
      final appState = context.read<AppState>();
      var engine = OcrService.engineFromName(appState.ocrEngine);
      if (engine == OcrEngine.ai) engine = OcrEngine.mlKit;
      final lang = appState.ocrLanguage;
      final language = (lang.isEmpty || lang == 'auto')
          ? appState.learningLanguage
          : lang;

      if (appState.ocrApiEndpoint.isNotEmpty) {
        _ocr.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await _ocr.recognizeFromBytes(
        bytes,
        engine: engine,
        language: language,
        apiKey: appState.ocrApiKey,
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() {
          _error = result.error ?? 'OCR failed';
          _processing = false;
        });
        return;
      }
      setState(() {
        _lastImage = bytes;
        _blocks = result.blocks;
        _fullText = result.text;
        _processing = false;
        // default: all blocks selected when there are multiple, else the
        // single full text
        if (_blocks.length > 1) {
          _selectedBlocks.addAll([for (var i = 0; i < _blocks.length; i++) i]);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _processing = false;
      });
    }
  }

  /// Selected text assembled from checked blocks (or the full text).
  String get _selectedText {
    if (_blocks.isEmpty) return _fullText;
    final parts = <String>[];
    for (var i = 0; i < _blocks.length; i++) {
      if (_selectedBlocks.contains(i)) parts.add(_blocks[i].text);
    }
    if (parts.isEmpty) return _fullText;
    return parts.join('\n');
  }

  // ------------------------------------------------------------
  // downstream actions (universal clipboard + dictionary)
  // ------------------------------------------------------------

  Future<void> _sendToClipboard() async {
    final text = _mode == ScannerMode.text
        ? _textCtrl.text.trim()
        : _selectedText.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await ClipboardManagerService.instance.addText(text, source: 'scanner');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('sent to clipboard manager'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _lookupText() async {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    // copied first so the popup dictionary's auto-copy flows work too
    await Clipboard.setData(ClipboardData(text: text));
    await ClipboardManagerService.instance.addText(text, source: 'scanner');
    if (!mounted) return;
    await PopupDictionaryController.instance.showLookupFor(text);
  }

  Future<void> _saveImageToClipboardManager() async {
    final image = _lastImage;
    if (image == null) return;
    await ClipboardManagerService.instance.addImage(image, source: 'scanner');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('image saved to clipboard manager'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  // ------------------------------------------------------------
  // text mode
  // ------------------------------------------------------------

  void _switchMode(ScannerMode mode) {
    setState(() {
      _mode = mode;
      if (mode == ScannerMode.text) {
        _textCtrl.text = _selectedText.trim();
      } else if (_textCtrl.text.trim().isNotEmpty) {
        _fullText = _textCtrl.text.trim();
        _blocks = [];
        _selectedBlocks.clear();
      }
    });
  }

  // ------------------------------------------------------------
  // build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Column(
      children: [
        // mode switch + actions
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              SegmentedButton<ScannerMode>(
                segments: const [
                  ButtonSegment(
                    value: ScannerMode.scanner,
                    icon: Icon(Icons.document_scanner, size: 18),
                    label: Text('Scanner'),
                  ),
                  ButtonSegment(
                    value: ScannerMode.text,
                    icon: Icon(Icons.keyboard, size: 18),
                    label: Text('Text'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (sel) => _switchMode(sel.first),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.content_paste, size: 18),
                tooltip: 'Paste',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text?.isNotEmpty ?? false) {
                    _switchMode(ScannerMode.text);
                    if (mounted) {
                      setState(() => _textCtrl.text = data!.text!);
                    }
                  }
                },
              ),
            ],
          ),
        ),

        // input area
        Expanded(
          child: _mode == ScannerMode.text
              ? _buildTextMode(theme, l10n)
              : _buildScannerMode(theme, l10n, isMobile),
        ),

        // downstream action bar
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _processing ? null : _sendToClipboard,
                icon: const Icon(Icons.content_copy, size: 16),
                label: Text(
                  'Clipboard',
                  style: TextStyle(fontSize: fs(context, 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _processing ? null : _lookupText,
                icon: const Icon(Icons.search, size: 16),
                label: Text(
                  'Look up',
                  style: TextStyle(fontSize: fs(context, 12)),
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedText.trim().length} chars',
                style: TextStyle(
                  fontSize: fs(context, 10.5),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // scanner mode UI
  // ------------------------------------------------------------

  Widget _buildScannerMode(
    ThemeData theme,
    AppLocalizations? l10n,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // capture buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _scanCamera,
                  icon: _processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera, size: 18),
                  label: Text(
                    isMobile ? 'Scan with camera' : 'Camera (mobile only)',
                    style: TextStyle(fontSize: fs(context, 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _processing ? null : _scanGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  'Gallery',
                  style: TextStyle(fontSize: fs(context, 12)),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.error,
                ),
              ),
            ),

          // captured image preview
          if (_lastImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.memory(
                    _lastImage!,
                    fit: BoxFit.contain,
                    cacheWidth: 900,
                  ),
                ),
              ),
            ),

          // detected blocks with selection checkboxes
          if (_blocks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${_blocks.length} text blocks',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selectedBlocks.length == _blocks.length) {
                        _selectedBlocks.clear();
                      } else {
                        for (var i = 0; i < _blocks.length; i++) {
                          _selectedBlocks.add(i);
                        }
                      }
                    }),
                    child: Text(
                      _selectedBlocks.length == _blocks.length
                          ? 'Deselect all'
                          : 'Select all',
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _blocks.length; i++)
              CheckboxListTile(
                dense: true,
                value: _selectedBlocks.contains(i),
                title: Text(
                  _blocks[i].text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selectedBlocks.add(i);
                  } else {
                    _selectedBlocks.remove(i);
                  }
                }),
              ),
          ],

          // full text fallback
          if (_fullText.isNotEmpty && _blocks.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _fullText,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),

          // save image payload
          if (_lastImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Save image to clipboard manager'),
                onPressed: _saveImageToClipboardManager,
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // text mode UI
  // ------------------------------------------------------------

  Widget _buildTextMode(ThemeData theme, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: null,
            minLines: 6,
            autofocus: _mode == ScannerMode.text,
            decoration: InputDecoration(
              hintText: 'Type or paste text…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                onPressed: () => setState(() => _textCtrl.clear()),
              ),
              const Spacer(),
              SelectableText(
                '${_textCtrl.text.trim().length} chars',
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
