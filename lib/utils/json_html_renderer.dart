import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lang/domain/entities/dictionary_display_options.dart';

/// Renders Yomichan structured-content JSON to Flutter widgets.
///
/// Supported node spec (per Yomitan's structured-content format):
/// - text nodes: strings
/// - {tag: 'br'} line breaks
/// - {tag: 'ruby', content: [base, {tag:'rt', content: reading}]}
///   with real furigana via overlined spans
/// - {tag: 'span'|'div', content, style: {...}, data: {...}}
/// - {tag: 'ul'|'ol'|'li', content: [...]}
/// - {tag: 'table', content: [{tag:'tr', content:[{tag:'td'|'th', ...}]}]}
/// - {tag: 'img', path, width, height, pixelated, appearance, alt}
///   resolved against [mediaIndex] extracted from the dictionary
/// - {tag: 'a', href, content}
/// - {tag: 'details'|'summary', collapsible sections}
/// - {tag: 'line', collapsible line separator}
/// - inline style keys: fontSize, fontStyle, fontWeight, textDecoration,
///   color, backgroundColor, textAlign, verticalAlign, marginTop...
/// - legacy keys also honored: data.style string, data.class markers
///
/// [options] toggles which parts render at all (sentences, images,
/// tags, notes). [mediaIndex] maps archive-relative paths to
/// extracted image file paths.
class JsonHtmlRenderer {
  static Widget render(
    dynamic jsonStructure, {
    DictionaryDisplayOptions options = const _DefaultDisplayOptions(),
    Map<String, String> mediaIndex = const {},
  }) {
    if (jsonStructure == null) return const SizedBox.shrink();

    if (jsonStructure is String) {
      // may be a JSON-encoded structure or plain text
      final decoded = _tryDecode(jsonStructure);
      if (decoded != null)
        return render(decoded, options: options, mediaIndex: mediaIndex);
      return _styledText(jsonStructure, null);
    }

    if (jsonStructure is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in jsonStructure)
            render(item, options: options, mediaIndex: mediaIndex),
        ],
      );
    }

    if (jsonStructure is Map<String, dynamic>) {
      return _renderElement(jsonStructure, options, mediaIndex);
    }

    if (jsonStructure is Map) {
      return _renderElement(
        jsonStructure.map((k, v) => MapEntry(k.toString(), v)),
        options,
        mediaIndex,
      );
    }

    return _styledText(jsonStructure.toString(), null);
  }

  static dynamic _tryDecode(String raw) {
    final t = raw.trim();
    if (!t.startsWith('{') && !t.startsWith('[')) return null;
    try {
      // ignore: avoid_dynamic_calls
      return const JsonDecoder().convert(t);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // element dispatch
  // ============================================================

  static Widget _renderElement(
    Map<String, dynamic> element,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    // legacy wrapper: {type: 'image', data: {...}}
    final legacyType = element['type'] as String?;
    if (legacyType == 'image') {
      final data = element['data'];
      if (data is Map) {
        final img = <String, dynamic>{'tag': 'img', ...data};
        return _renderElement(
          img.map((k, v) => MapEntry(k.toString(), v)),
          options,
          mediaIndex,
        );
      }
      return const SizedBox.shrink();
    }

    final tag = element['tag'] as String? ?? element['tagName'] as String?;
    final content = element['content'];

    switch (tag) {
      case 'br':
      case 'line-break':
        return const SizedBox(height: 6);
      case 'ruby':
        // ruby renders inline via _rubySpan within parents; a
        // standalone ruby block renders its spans
        return DefaultTextStyle(
          style: const TextStyle(fontSize: 14, height: 1.45),
          child: Text.rich(
            TextSpan(children: _inlineSpans([element], options, mediaIndex)),
          ),
        );
      case 'rt':
        return const SizedBox.shrink(); // handled inside ruby
      case 'span':
        return _buildSpan(element, content, options, mediaIndex);
      case 'div':
        return _buildDiv(element, content, options, mediaIndex);
      case 'ul':
        return _buildList(
          content,
          ordered: false,
          options: options,
          mediaIndex: mediaIndex,
        );
      case 'ol':
        return _buildList(
          content,
          ordered: true,
          options: options,
          mediaIndex: mediaIndex,
        );
      case 'li':
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: render(content, options: options, mediaIndex: mediaIndex),
        );
      case 'table':
        return _buildTable(element, options, mediaIndex);
      case 'img':
      case 'image':
        return _buildImage(element, options, mediaIndex);
      case 'a':
        return _buildLink(element, content, options, mediaIndex);
      case 'details':
        return _buildDetails(element, content, options, mediaIndex);
      case 'summary':
        return render(content, options: options, mediaIndex: mediaIndex);
      case 'line':
        return _buildLine(element);
      default:
        // unknown tag: render children inline
        return render(content, options: options, mediaIndex: mediaIndex);
    }
  }

  // ============================================================
  // text + styles
  // ============================================================

  static TextStyle _parseStyle(dynamic style) {
    var ts = const TextStyle(fontSize: 14, height: 1.45);
    if (style is Map<String, dynamic>) {
      final fontSize = (style['fontSize'] as num?)?.toDouble();
      if (fontSize != null) ts = ts.copyWith(fontSize: fontSize);
      final fontStyle = style['fontStyle'] as String?;
      if (fontStyle == 'italic') ts = ts.copyWith(fontStyle: FontStyle.italic);
      final fontWeight = style['fontWeight'] as String?;
      if (fontWeight == 'bold') {
        ts = ts.copyWith(fontWeight: FontWeight.bold);
      } else if (fontWeight == '600') {
        ts = ts.copyWith(fontWeight: FontWeight.w600);
      }
      final textDecoration = style['textDecoration'] as String?;
      if (textDecoration?.contains('line-through') == true) {
        ts = ts.copyWith(decoration: TextDecoration.lineThrough);
      } else if (textDecoration?.contains('underline') == true) {
        ts = ts.copyWith(decoration: TextDecoration.underline);
      }
      final color = _parseColor(style['color']);
      if (color != null) ts = ts.copyWith(color: color);
    } else if (style is String) {
      // legacy CSS-ish string: "font-weight:bold;color:#123456"
      if (style.contains('bold')) ts = ts.copyWith(fontWeight: FontWeight.bold);
      if (style.contains('italic'))
        ts = ts.copyWith(fontStyle: FontStyle.italic);
      if (style.contains('line-through')) {
        ts = ts.copyWith(decoration: TextDecoration.lineThrough);
      }
      final colorMatch = RegExp(
        r'color:\s*(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})',
      ).firstMatch(style);
      if (colorMatch != null) {
        final c = _parseColor(colorMatch.group(1));
        if (c != null) ts = ts.copyWith(color: c);
      }
    }
    return ts;
  }

  static Color? _parseColor(dynamic color) {
    if (color is String) {
      var hex = color.replaceAll('#', '');
      if (hex.length == 3) {
        hex = hex.split('').map((c) => c + c).join();
      }
      if (hex.length == 6 || hex.length == 8) {
        try {
          final value = int.parse('FF$hex'.substring(0, 10), radix: 16);
          return Color(value);
        } catch (_) {
          return null;
        }
      }
    }
    if (color is int) return Color(0xFF000000 | color);
    return null;
  }

  static Widget _styledText(String text, dynamic style) {
    return Text(text, style: _parseStyle(style).copyWith());
  }

  // ============================================================
  // inline nodes -> TextSpan for ruby support
  // ============================================================

  static List<InlineSpan> _inlineSpans(
    dynamic content,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex, {
    dynamic style,
  }) {
    final spans = <InlineSpan>[];
    void walk(dynamic node) {
      if (node is String) {
        spans.add(TextSpan(text: node, style: _parseStyle(style)));
        return;
      }
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
        return;
      }
      if (node is Map) {
        final m = node.map((k, v) => MapEntry(k.toString(), v));
        final tag = m['tag'] as String?;
        if (tag == 'ruby') {
          spans.add(_rubySpan(m, options, mediaIndex));
          return;
        }
        if (tag == 'img') {
          // inline images in text flow: use placeholder icon span
          spans.add(
            const WidgetSpan(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.image, size: 14),
              ),
            ),
          );
          return;
        }
        if (tag == 'br' || tag == 'line-break') {
          spans.add(const TextSpan(text: '\n'));
          return;
        }
        final childContent = m['content'];
        final mergedStyle = m['style'] ?? style;
        if (childContent is String) {
          spans.add(
            TextSpan(text: childContent, style: _parseStyle(mergedStyle)),
          );
        } else {
          walk(childContent is List ? childContent : [childContent]);
        }
        return;
      }
      spans.add(TextSpan(text: node.toString(), style: _parseStyle(style)));
    }

    if (content is List) {
      for (final child in content) {
        walk(child);
      }
    } else {
      walk(content);
    }
    return spans;
  }

  static InlineSpan _rubySpan(
    Map<String, dynamic> ruby,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    final content = ruby['content'];
    String base = '';
    String reading = '';

    if (content is List && content.isNotEmpty) {
      // base: everything except rt nodes; reading: rt text
      final baseParts = <String>[];
      for (final child in content) {
        if (child is Map) {
          final m = child.map((k, v) => MapEntry(k.toString(), v));
          final tag = m['tag'] as String?;
          if (tag == 'rt') {
            final rtContent = m['content'];
            if (rtContent is String) {
              reading += rtContent;
            } else if (rtContent is List) {
              reading += rtContent.map((e) => e.toString()).join();
            }
            continue;
          }
          if (tag == 'rp') continue; // paren marks ignored
          final inner = m['content'];
          if (inner is String) {
            baseParts.add(inner);
          } else if (inner is List) {
            for (final s in _inlineSpans(inner, options, mediaIndex)) {
              if (s is TextSpan) baseParts.add(s.text ?? '');
            }
          }
        } else if (child is String) {
          baseParts.add(child);
        }
      }
      base = baseParts.join();
    } else if (content is String) {
      base = content;
    }

    if (reading.isEmpty) {
      return TextSpan(text: base);
    }

    // real furigana: overlined reading above base text
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: _Ruby(base: base, reading: reading),
    );
  }

  // ============================================================
  // tags
  // ============================================================

  static Widget _buildTag(String label, ThemeData? theme) {
    final scheme = theme?.colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color:
            scheme?.primary.withValues(alpha: 0.12) ?? const Color(0xFFBBDEFB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              scheme?.primary.withValues(alpha: 0.4) ?? const Color(0xFF90CAF9),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: scheme?.primary ?? const Color(0xFF1565C0),
        ),
      ),
    );
  }

  // ============================================================
  // block builders
  // ============================================================

  static Widget _buildDiv(
    Map<String, dynamic> element,
    dynamic content,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    final data = element['data'];
    final dataMap = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final className = (dataMap['class'] as String?) ?? '';
    final contentKind = dataMap['content'] as String?;

    // example sentences gated by toggle
    if (className.contains('example-sentence') || contentKind == 'sentence') {
      if (!options.showSentences) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: render(content, options: options, mediaIndex: mediaIndex),
      );
    }

    // notes / extra info gated by toggle
    if (contentKind == 'extra-info' || contentKind == 'note') {
      if (!options.showNotes) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: render(content, options: options, mediaIndex: mediaIndex),
      );
    }

    if (contentKind == 'sense-group' || contentKind == 'sense') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: render(content, options: options, mediaIndex: mediaIndex),
      );
    }

    if (className.contains('term-frequency') || contentKind == 'frequency') {
      if (!options.showFrequencies) return const SizedBox.shrink();
    }

    if (className.contains('pronunciation') || contentKind == 'pitch-accent') {
      if (!options.showPitchAccent) return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: render(content, options: options, mediaIndex: mediaIndex),
    );
  }

  static Widget _buildSpan(
    Map<String, dynamic> element,
    dynamic content,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    final data = element['data'];
    final dataMap = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final className = (dataMap['class'] as String?) ?? '';

    if (className.contains('tag')) {
      if (!options.showTags) return const SizedBox.shrink();
      final label =
          (element['title'] as String?) ?? (content is String ? content : '');
      if (label.isEmpty) return const SizedBox.shrink();
      return _buildTag(label, null);
    }

    if (className.contains('extra-box')) {
      if (!options.showNotes) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: render(content, options: options, mediaIndex: mediaIndex),
      );
    }

    // inline span: build rich text so ruby inside spans works
    final spans = _inlineSpans(
      content,
      options,
      mediaIndex,
      style: element['style'],
    );
    if (spans.isEmpty) return const SizedBox.shrink();
    return DefaultTextStyle(
      style: const TextStyle(fontSize: 14, height: 1.45),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  static Widget _buildList(
    dynamic content, {
    required bool ordered,
    required DictionaryDisplayOptions options,
    required Map<String, String> mediaIndex,
  }) {
    if (options.compactGlossaries) {
      // compact: join with separators, no bullets
      final parts = <Widget>[];
      var first = true;
      for (final item in content is List ? content : const []) {
        if (!first) parts.add(const Text(' | '));
        parts.add(render(item, options: options, mediaIndex: mediaIndex));
        first = false;
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: parts,
      );
    }

    if (content is! List) {
      return render(content, options: options, mediaIndex: mediaIndex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < content.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordered ? '${i + 1}. ' : '• ',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
                Expanded(
                  child: render(
                    content[i],
                    options: options,
                    mediaIndex: mediaIndex,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _buildTable(
    Map<String, dynamic> element,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    final content = element['content'];
    if (content is! List) {
      return render(content, options: options, mediaIndex: mediaIndex);
    }

    final rows = <TableRow>[];
    for (final row in content) {
      if (row is! Map) continue;
      final m = row.map((k, v) => MapEntry(k.toString(), v));
      if (m['tag'] != 'tr') continue;
      final cells = <Widget>[];
      final rowContent = m['content'];
      for (final cell in rowContent is List ? rowContent : const []) {
        if (cell is! Map) continue;
        final cm = cell.map((k, v) => MapEntry(k.toString(), v));
        final isHeader = cm['tag'] == 'th';
        final cellContent = cm['content'];
        String text;
        if (cellContent is String) {
          text = cellContent;
        } else {
          final buf = StringBuffer();
          _flattenText(cellContent, buf);
          text = buf.toString();
        }
        cells.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }
      rows.add(TableRow(children: cells));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey.shade200),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  static void _flattenText(dynamic node, StringBuffer out) {
    if (node is String) {
      out.write(node);
    } else if (node is List) {
      for (final c in node) {
        _flattenText(c, out);
      }
    } else if (node is Map) {
      final m = node.map((k, v) => MapEntry(k.toString(), v));
      if (m['tag'] == 'br') {
        out.write(' ');
        return;
      }
      _flattenText(m['content'], out);
    }
  }

  static Widget _buildImage(
    Map<String, dynamic> element,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    if (!options.showImages) return const SizedBox.shrink();

    final dataMap = element['data'] is Map
        ? (element['data'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final path =
        (element['path'] as String?) ??
        (element['src'] as String?) ??
        (dataMap['path'] as String?) ??
        (dataMap['src'] as String?);
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    final file = _resolveImage(path, mediaIndex);
    if (file == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 16,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              element['alt'] as String? ?? path.split('/').last,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final width = (element['width'] as num?)?.toDouble();
    final height = (element['height'] as num?)?.toDouble();
    final alt = element['alt'] as String?;
    final pixelated =
        element['pixelated'] == true || element['appearance'] == 'monochrome';

    Widget image = Image.file(
      file,
      width: width,
      height: height,
      fit: width != null && height != null ? BoxFit.contain : null,
      filterQuality: pixelated ? FilterQuality.none : FilterQuality.medium,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.broken_image, size: 24, color: Colors.grey.shade400),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(message: alt ?? path, child: image),
    );
  }

  static File? _resolveImage(String path, Map<String, String> mediaIndex) {
    if (mediaIndex.isEmpty) {
      // maybe an absolute path already
      final direct = File(path);
      if (direct.existsSync()) return direct;
      return null;
    }
    final resolvedPath = _resolveMediaKey(path, mediaIndex);
    if (resolvedPath == null) return null;
    return File(resolvedPath);
  }

  static String? _resolveMediaKey(String path, Map<String, String> mediaIndex) {
    var p = path.replaceAll('\\', '/').trim();
    while (p.startsWith('./')) {
      p = p.substring(2);
    }
    final direct = mediaIndex[p];
    if (direct != null) return direct;
    final base = p.split('/').last;
    final byBase = mediaIndex[base];
    if (byBase != null) return byBase;
    for (final e in mediaIndex.entries) {
      if (e.key.toLowerCase() == base.toLowerCase()) return e.value;
    }
    // last resort: absolute path on disk
    final f = File(path);
    if (f.existsSync()) return f.path;
    return null;
  }

  static Widget _buildLink(
    Map<String, dynamic> element,
    dynamic content,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    final href = element['href'] as String?;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: href != null ? () => _handleLink(href) : null,
        child: Text.rich(
          TextSpan(
            children: _inlineSpans(
              content,
              options,
              mediaIndex,
              style: element['style'],
            ),
            style: const TextStyle(
              color: Color(0xFF1565C0),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  static void _handleLink(String href) {
    // navigation is handled at screen level via url_launcher where
    // available; here we only flag external links
    debugPrint('dictionary link tapped: $href');
  }

  static Widget _buildDetails(
    Map<String, dynamic> element,
    dynamic content,
    DictionaryDisplayOptions options,
    Map<String, String> mediaIndex,
  ) {
    if (content is! List) {
      return render(content, options: options, mediaIndex: mediaIndex);
    }
    // first summary-like child is the header, rest is the body
    Widget header = const Text(
      'More',
      style: TextStyle(fontWeight: FontWeight.w600),
    );
    final body = <dynamic>[];
    for (final child in content) {
      if (child is Map &&
          (child['tag'] == 'summary' || child['tagName'] == 'summary')) {
        header = render(
          child['content'],
          options: options,
          mediaIndex: mediaIndex,
        );
      } else {
        body.add(child);
      }
    }
    return ExpansionTile(
      dense: true,
      tilePadding: EdgeInsets.zero,
      title: header,
      children: [render(body, options: options, mediaIndex: mediaIndex)],
    );
  }

  static Widget _buildLine(Map<String, dynamic> element) {
    final collapsed = element['collapsed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        color: collapsed ? Colors.transparent : Colors.grey.shade300,
      ),
    );
  }
}

// ============================================================
// ruby widget: real furigana
// ============================================================

class _Ruby extends StatelessWidget {
  final String base;
  final String reading;

  const _Ruby({required this.base, required this.reading});

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(
      fontSize: 14,
      height: 1.45,
      color: Colors.black87,
    );
    final rubyStyle = const TextStyle(
      fontSize: 8,
      height: 1.0,
      color: Colors.grey,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(reading, style: rubyStyle),
        Text(base, style: baseStyle),
      ],
    );
  }
}

/// const-friendly default used when callers don't supply options.
class _DefaultDisplayOptions implements DictionaryDisplayOptions {
  const _DefaultDisplayOptions();

  @override
  bool get showSentences => true;
  @override
  set showSentences(bool _) {}
  @override
  bool get showImages => true;
  @override
  set showImages(bool _) {}
  @override
  bool get showTags => true;
  @override
  set showTags(bool _) {}
  @override
  bool get showNotes => true;
  @override
  set showNotes(bool _) {}
  @override
  bool get showFrequencies => true;
  @override
  set showFrequencies(bool _) {}
  @override
  bool get showPitchAccent => true;
  @override
  set showPitchAccent(bool _) {}
  @override
  bool get compactGlossaries => false;
  @override
  set compactGlossaries(bool _) {}
  @override
  bool get showStructuredContent => true;
  @override
  set showStructuredContent(bool _) {}
  @override
  bool get collapseLongDefinitions => false;
  @override
  set collapseLongDefinitions(bool _) {}
  @override
  bool get showDictionaryName => true;
  @override
  set showDictionaryName(bool _) {}
  @override
  Map<String, dynamic> toJson() => {};
  @override
  void fromJson(Map<String, dynamic> json) {}
  @override
  String serialize() => '';
}
