import 'package:flutter/material.dart';

/// Reusable search bar widget
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final bool autoFocus;
  final FocusNode? focusNode;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onClear,
    this.hintText = 'Search...',
    this.autoFocus = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autoFocus,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.2),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: onClear,
                )
              : null,
        ),
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}