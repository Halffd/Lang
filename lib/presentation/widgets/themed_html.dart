import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:lang/utils/font_scale.dart';

/// Theme-aware HTML renderer for dictionary content (Wiktionary HTML,
/// kanjipedia origin/usage text, structured definitions).
///
/// Raw [HtmlWidget] output ignores the app theme: wiktionary tables and
/// lists render white-on-white in dark mode, links show in the library
/// default red/blue, and iframes keep their white page background. This
/// wrapper injects theme-derived CSS so everything inherits the ambient
/// text color and surface.
class ThemedHtml extends StatelessWidget {
  final String html;
  final double fontSize;

  const ThemedHtml(this.html, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    final border = '1px solid ${_hex(theme.colorScheme.outline, 0.24)}';
    final muted = _hex(onSurface, 0.55);

    return HtmlWidget(
      html,
      textStyle: TextStyle(
        fontSize: fs(context, fontSize, 'translations'),
        color: onSurface,
      ),
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'a':
            return {'color': _hex(primary), 'text-decoration': 'underline'};
          case 'table':
          case 'thead':
          case 'tbody':
          case 'tr':
          case 'td':
          case 'th':
          case 'caption':
            // wiktionary inflection tables hardcode white backgrounds
            return {
              'background-color': 'transparent !important',
              'color': 'inherit !important',
              'border': border,
              'border-collapse': 'collapse',
              'padding': '2px 4px',
            };
          case 'iframe':
          case 'img':
          case 'video':
          case 'audio':
            return {
              'background-color': 'transparent !important',
              'max-width': '100%',
            };
          case 'blockquote':
            return {
              'color': muted,
              'border-left':
                  '3px solid ${_hex(theme.colorScheme.outline, 0.24)}',
              'margin': '4px 0',
              'padding-left': '8px',
            };
          case 'code':
          case 'pre':
            return {
              'background-color': muted,
              'color': 'inherit !important',
              'border-radius': '4px',
            };
          case 'hr':
            return {'border': 'none', 'border-top': border};
          default:
            return null;
        }
      },
    );
  }

  /// #RRGGBB with optional alpha (0.0–1.0), for inline CSS injection.
  static String _hex(Color color, [double? alpha]) {
    final a = ((alpha ?? color.a) * 255).round().clamp(0, 255);
    final argb =
        (a << 24) |
        ((color.r * 255).round() << 16) |
        ((color.g * 255).round() << 8) |
        (color.b * 255).round();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
