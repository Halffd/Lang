import 'package:flutter/material.dart';
import '../../../domain/entities/dictionary.dart';
import '../../../data/repositories/dictionary_service.dart' show Token;

class TokenWidget extends StatelessWidget {
  final Token token;
  final bool isSelected;
  final bool isDeleted;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final double fontSize;
  final double definitionFontSize;
  final bool showInlineDefinition;
  final bool showHoverDefinition;

  const TokenWidget({
    super.key,
    required this.token,
    required this.isSelected,
    required this.isDeleted,
    required this.onTap,
    this.onSecondaryTap,
    this.fontSize = 24,
    this.definitionFontSize = 16,
    this.showInlineDefinition = true,
    this.showHoverDefinition = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasDef = token.entry != null && token.entry!.definitions.isNotEmpty;

    Widget child = Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Colors.purple
              : (token.isWord ? Colors.grey.shade400 : Colors.transparent),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              token.text,
              softWrap: true,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDeleted ? Colors.red : Colors.black),
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                decoration: isDeleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (showInlineDefinition && hasDef)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
              child: Text(
                token.entry!.definitions.first.length > 80
                    ? '${token.entry!.definitions.first.substring(0, 80)}...'
                    : token.entry!.definitions.first,
                softWrap: true,
                style: TextStyle(
                  fontSize: definitionFontSize,
                  color: isSelected ? Colors.purple.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );

  if (!hasDef || !showHoverDefinition) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: hasDef ? () => _showDefinitionPopup(context, token.entry!, token.deconjugatedForm) : null,
      onSecondaryTap: onSecondaryTap,
      child: child,
    );
  }

    return _HoverDefinitionPopup(
      entry: token.entry!,
      deconjugatedForm: token.deconjugatedForm,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _showDefinitionPopup(context, token.entry!, token.deconjugatedForm),
        onSecondaryTap: onSecondaryTap,
        child: child,
      ),
    );
  }

  void _showDefinitionPopup(BuildContext context, DictionaryEntry entry, String? deconjugatedForm) {
    showDialog(
      context: context,
      builder: (ctx) => _DefinitionDialog(entry: entry, deconjugatedForm: deconjugatedForm),
    );
  }
}

class _HoverDefinitionPopup extends StatefulWidget {
  final DictionaryEntry entry;
  final String? deconjugatedForm;
  final Widget child;

  const _HoverDefinitionPopup({
    required this.entry,
    this.deconjugatedForm,
    required this.child,
  });

  @override
  State<_HoverDefinitionPopup> createState() => _HoverDefinitionPopupState();
}

class _HoverDefinitionPopupState extends State<_HoverDefinitionPopup> {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  void _showOverlay() {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context);
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: size.width > 300 ? size.width : 300,
              maxHeight: 200,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _DefinitionContent(entry: widget.entry, deconjugatedForm: widget.deconjugatedForm),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _isHovering = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_isHovering && mounted) _showOverlay();
        });
      },
      onExit: (_) {
        _isHovering = false;
        _hideOverlay();
      },
      child: widget.child,
    );
  }
}

class _DefinitionDialog extends StatelessWidget {
  final DictionaryEntry entry;
  final String? deconjugatedForm;

  const _DefinitionDialog({required this.entry, this.deconjugatedForm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.word),
      content: SingleChildScrollView(
        child: _DefinitionContent(entry: entry, deconjugatedForm: deconjugatedForm),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DefinitionContent extends StatelessWidget {
  final DictionaryEntry entry;
  final String? deconjugatedForm;

  const _DefinitionContent({required this.entry, this.deconjugatedForm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deconjugatedForm != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '→ $deconjugatedForm',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            if (entry.reading.isNotEmpty && entry.reading != entry.term)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  entry.reading,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (entry.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: entry.tags.map((t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ),
            ...entry.definitions.asMap().entries.map((e) => Padding(
              padding: EdgeInsets.only(top: e.key > 0 ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
