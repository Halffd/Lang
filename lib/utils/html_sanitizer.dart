import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

/// HTML Sanitizer for preventing XSS when rendering remote content
class HtmlSanitizer {
  static const List<String> _allowedTags = [
    'p',
    'br',
    'div',
    'span',
    'b',
    'i',
    'strong',
    'em',
    'u',
    'ul',
    'ol',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'code',
    'a',
    'img',
    'ruby',
    'rt',
    'rp',
    'sub',
    'sup',
    'small',
    'mark',
    'ins',
    'del',
    'table',
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
  ];

  static const List<String> _allowedAttributes = [
    'href',
    'src',
    'alt',
    'title',
    'class',
    'id',
    'style',
    'target',
    'rel',
    'cite',
    'datetime',
    'lang',
  ];

  static const List<String> _blockedProtocols = [
    'javascript:',
    'data:',
    'vbscript:',
    'file:',
    'ftp:',
    'mailto:',
  ];

  /// Sanitize HTML content from untrusted sources. Fragments
  /// (no <html> wrapper) are parsed as fragments so inline
  /// markup is not moved into a synthetic head as plain text.
  static String sanitize(String html) {
    if (html.isEmpty) return '';

    try {
      final looksLikeDocument =
          html.contains('<html') || html.contains('<body');
      if (looksLikeDocument) {
        final document = parser.parse(html);
        _sanitizeNode(document.body ?? document);
        return document.body?.outerHtml ?? document.outerHtml;
      }
      final fragment = parser.parseFragment(html);
      _sanitizeNode(fragment);
      return fragment.outerHtml;
    } catch (e) {
      // If parsing fails, return escaped text
      return _escapeHtml(html);
    }
  }

  static const List<String> _droppedTags = [
    'script',
    'style',
    'iframe',
    'svg',
    'object',
    'embed',
    'form',
    'input',
    'button',
    'link',
    'meta',
  ];

  /// Tags whose entire subtree is removed (content is unsafe).
  static bool _isDropped(String tag) => _droppedTags.contains(tag);

  static void _sanitizeNode(dom.Node node) {
    if (node is dom.Element) {
      final tagName = node.localName?.toLowerCase() ?? '';

      // Dangerous tags: drop the whole subtree, not just the wrapper
      if (_isDropped(tagName)) {
        node.remove();
        return;
      }

      // Remove disallowed tags entirely
      if (!_allowedTags.contains(tagName)) {
        // Replace with text content
        final text = node.text;
        node.replaceWith(dom.Text(text));
        return;
      }

      // Sanitize attributes
      final attrsToRemove = <Object>[];
      for (final entry in node.attributes.entries) {
        // fragment-parsed elements key attributes as Object
        final attrName = entry.key.toString().toLowerCase();
        final attrValue = entry.value;

        if (!_allowedAttributes.contains(attrName)) {
          attrsToRemove.add(entry.key);
          continue;
        }

        // Sanitize URL attributes
        if (attrName == 'href' || attrName == 'src' || attrName == 'cite') {
          final lowerValue = attrValue.toLowerCase();
          for (final proto in _blockedProtocols) {
            if (lowerValue.startsWith(proto)) {
              attrsToRemove.add(entry.key);
              break;
            }
          }
          // Only allow http/https for href/src
          if ((attrName == 'href' || attrName == 'src') &&
              !lowerValue.startsWith('http://') &&
              !lowerValue.startsWith('https://') &&
              !lowerValue.startsWith('/') &&
              !lowerValue.startsWith('#')) {
            attrsToRemove.add(entry.key);
          }
        }

        // Sanitize style attribute
        if (attrName == 'style') {
          final sanitized = _sanitizeStyle(attrValue);
          if (sanitized.isEmpty) {
            attrsToRemove.add(entry.key);
          } else {
            node.attributes[entry.key] = sanitized;
          }
        }
      }

      for (final attr in attrsToRemove) {
        node.attributes.remove(attr);
      }

      // Add security attributes to links
      if (tagName == 'a') {
        final href = node.attributes['href'];
        if (href != null &&
            (href.startsWith('http://') || href.startsWith('https://'))) {
          node.attributes['rel'] = 'noopener noreferrer';
          node.attributes['target'] = '_blank';
        }
      }

      // Sanitize image sources
      if (tagName == 'img') {
        final src = node.attributes['src'];
        if (src != null) {
          final lowerSrc = src.toLowerCase();
          if (!lowerSrc.startsWith('http://') &&
              !lowerSrc.startsWith('https://') &&
              !lowerSrc.startsWith('data:image/')) {
            node.remove();
            return;
          }
        }
      }
    }

    // Recursively sanitize children
    final children = node.nodes.toList();
    for (final child in children) {
      _sanitizeNode(child);
    }
  }

  static String _sanitizeStyle(String style) {
    if (style.isEmpty) return '';

    final allowedProperties = [
      'color',
      'background-color',
      'font-size',
      'font-weight',
      'font-style',
      'text-decoration',
      'text-align',
      'margin',
      'padding',
      'border',
      'display',
      'width',
      'height',
      'font-family',
      'line-height',
      'vertical-align',
    ];

    final declarations = style.split(';');
    final sanitized = <String>[];

    for (final decl in declarations) {
      final parts = decl.split(':');
      if (parts.length != 2) continue;

      final prop = parts[0].trim().toLowerCase();
      final value = parts[1].trim();

      if (allowedProperties.contains(prop)) {
        // Basic value sanitization; normalize whitespace so
        // 'url (' cannot smuggle a payload past the url( check
        final normalized = value.replaceAll(' ', '').toLowerCase();
        if (!normalized.contains('expression') &&
            !normalized.contains('javascript') &&
            !normalized.contains('url(') &&
            !normalized.contains('<')) {
          sanitized.add('$prop: $value');
        }
      }
    }

    return sanitized.join('; ');
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
