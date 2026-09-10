import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary_display_options.dart';
import 'package:lang/utils/dictionary_media_registry.dart';
import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/json_html_renderer.dart';

/// Renders a definition string that may be plain text or a
/// JSON-encoded Yomichan structured-content node. JSON input is
/// either rendered as widgets (JsonHtmlRenderer) or flattened to
/// plain text depending on the dictionary display options.
class StructuredDefinition extends StatelessWidget {
  final String definition;

  /// Base font size for plain text (scaled through the font
  /// settings 'translations' group).
  final double fontSize;

  const StructuredDefinition({
    super.key,
    required this.definition,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // listen: false is fine — options rarely change and the host
    // screens rebuild on AppState notifications anyway
    final AppState? appState = Provider.of<AppState>(context, listen: false);
    final options =
        appState?.dictionaryDisplayOptions ?? DictionaryDisplayOptions();

    final plainStyle = TextStyle(
      fontSize: fs(context, fontSize, 'translations'),
      height: 1.4,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
    );

    try {
      final dynamic jsonContent = jsonDecode(definition);
      if (jsonContent is List || jsonContent is Map) {
        if (!options.showStructuredContent) {
          // plain-text fallback: flatten structured content
          final buf = StringBuffer();
          _flatten(jsonContent, buf);
          final flat = buf.toString().trim();
          if (flat.isNotEmpty) {
            return Text(flat, style: plainStyle);
          }
        }
        return JsonHtmlRenderer.render(
          jsonContent,
          options: options,
          mediaIndex: DictionaryMediaRegistry.mediaIndex(),
        );
      }
      return Text(definition, style: plainStyle);
    } on FormatException {
      return Text(definition, style: plainStyle);
    } catch (_) {
      return Text(definition, style: plainStyle);
    }
  }

  /// Flatten a structured-content node into readable plain text.
  static String flatten(String definition) {
    try {
      final dynamic jsonContent = jsonDecode(definition);
      final buf = StringBuffer();
      _flatten(jsonContent, buf);
      return buf.toString().trim();
    } on FormatException {
      return definition;
    } catch (_) {
      return definition;
    }
  }

  static void _flatten(dynamic node, StringBuffer out) {
    if (node is String) {
      out.write(node);
    } else if (node is List) {
      for (final c in node) {
        _flatten(c, out);
      }
    } else if (node is Map) {
      final m = node.map((k, v) => MapEntry(k.toString(), v));
      final tag = m['tag'] as String?;
      if (tag == 'br' || tag == 'line-break') {
        out.write('\n');
        return;
      }
      if (tag == 'ruby') {
        // keep just the base text
        final content = m['content'];
        if (content is List) {
          for (final child in content) {
            if (child is Map) {
              final cm = child.map((k, v) => MapEntry(k.toString(), v));
              if (cm['tag'] == 'rt' || cm['tag'] == 'rp') continue;
            }
            _flatten(child, out);
          }
        } else {
          _flatten(content, out);
        }
        return;
      }
      if (tag == 'img' || tag == 'image') return; // no alt text noise
      _flatten(m['content'], out);
    }
  }
}
