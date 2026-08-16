import 'package:flutter/material.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/data/repositories/dictionary_service.dart' show Token;

class TokenWidget extends StatelessWidget {
  final Token token;
  final DictionaryService dictionaryService;
  final bool isSelected;
  final VoidCallback onTap;

  const TokenWidget({
    super.key,
    required this.token,
    required this.dictionaryService,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKanji = _isKanji(token.text);
    final hasFurigana = token.furigana != null && token.furigana!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFurigana) ...[
              Text(
                token.furigana!,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 1),
            ],
            Text(
              token.text,
              style: TextStyle(
                fontSize: isKanji ? 18 : 16,
                fontWeight: isKanji ? FontWeight.w500 : FontWeight.normal,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isKanji(String text) {
    for (final codeUnit in text.codeUnits) {
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) return true;
      if (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) return true;
      if (codeUnit >= 0x20000 && codeUnit <= 0x2A6DF) return true;
      if (codeUnit >= 0x2A700 && codeUnit <= 0x2B73F) return true;
      if (codeUnit >= 0x2B740 && codeUnit <= 0x2B81F) return true;
      if (codeUnit >= 0x2B820 && codeUnit <= 0x2CEAF) return true;
      if (codeUnit >= 0x2CEB0 && codeUnit <= 0x2EBEF) return true;
    }
    return false;
  }
}