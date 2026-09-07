import 'package:flutter/material.dart';

class ImportWordsSheet extends StatefulWidget {
  final Function(List<String>) onImport;

  const ImportWordsSheet({required this.onImport, super.key});

  @override
  State<ImportWordsSheet> createState() => _ImportWordsSheetState();
}

class _ImportWordsSheetState extends State<ImportWordsSheet> {
  final _controller = TextEditingController();
  String _inputMethod = 'paste';
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _importing = true);

    try {
      List<String> words = [];

      if (_inputMethod == 'paste') {
        words = _controller.text
            .split(RegExp(r'[\s\n,;]+'))
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toSet()
            .toList();
      } else if (_inputMethod == 'csv') {
        final lines = _controller.text.split('\n');
        for (final line in lines) {
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            words.add(parts[0].trim().replaceAll('"', ''));
          }
        }
      }

      if (words.isNotEmpty) {
        await widget.onImport(words);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Scaffold(
        appBar: AppBar(
          title: const Text('Import Words'),
          actions: [
            if (!_importing)
              TextButton(
                onPressed: _import,
                child: const Text('Import'),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'paste', label: Text('Paste'), icon: Icon(Icons.content_paste)),
                  ButtonSegment(value: 'csv', label: Text('CSV'), icon: Icon(Icons.table_chart)),
                ],
                selected: {_inputMethod},
                onSelectionChanged: (s) => setState(() => _inputMethod = s.first),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: _inputMethod == 'paste'
                        ? 'Paste words separated by spaces, commas, or newlines...'
                        : 'Paste CSV data (word,reading,meaning)...',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _controller.clear(),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _importing ? null : _import,
                      child: _importing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Import'),
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
}