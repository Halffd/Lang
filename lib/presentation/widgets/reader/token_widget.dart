import 'package:flutter/material.dart';
import '../../../domain/entities/dictionary.dart';
import '../../../data/repositories/dictionary_service.dart';

class TokenWidget extends StatelessWidget {
  final Token token;
  final bool isSelected;
  final bool isDeleted;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;  // For right-click functionality
  final double fontSize;
  final double definitionFontSize;

  const TokenWidget({
    Key? key,
    required this.token,
    required this.isSelected,
    required this.isDeleted,
    required this.onTap,
    this.onSecondaryTap,
    this.fontSize = 24,
    this.definitionFontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,  // Add right-click functionality
      child: Container(
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
            // Show definition below the word if available
            if (token.entry != null && token.entry!.definitions.isNotEmpty)
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
      ),
    );
  }
}