import 'package:flutter/material.dart';
import 'package:kana_kit/kana_kit.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSearch;
  final VoidCallback onClear;
  final bool automaticKanaConversion;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onClear,
    this.automaticKanaConversion = true,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final KanaKit _kanaKit = KanaKit();
  bool _isComposing = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    if (_isComposing || !widget.automaticKanaConversion) return;
    
    final text = widget.controller.text;
    if (text == _lastText) return;
    
    // Only convert if the text contains romaji
    if (_containsRomaji(text)) {
      final hiragana = _kanaKit.toHiragana(text);
      if (hiragana != text) {
        final selection = widget.controller.selection;
        widget.controller.text = hiragana;
        // Preserve cursor position after conversion
        widget.controller.selection = TextSelection.collapsed(
          offset: selection.baseOffset + (hiragana.length - text.length),
        );
      }
    }
    
    _lastText = widget.controller.text;
  }

  bool _containsRomaji(String text) {
    // Simple check for romaji characters
    final romajiRegex = RegExp(r'[a-zA-Z]');
    return romajiRegex.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Search Japanese words, kanji, or phrases',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.onClear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            widget.onSearch(value);
          }
        },
        onChanged: (value) {
          setState(() {});
        },
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
