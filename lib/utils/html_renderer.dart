import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';

class HtmlRenderer {
  /// Renders HTML string content to Flutter widgets with improved styling
  static Widget renderHtml(String htmlContent) {
    if (htmlContent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          margin: Margins.all(0),
          padding: HtmlPaddings.all(8),
          fontSize: FontSize(14.0),
          color: Colors.black87,
        ),
        "p": Style(
          margin: Margins.symmetric(vertical: 6.0),
          lineHeight: LineHeight(1.5),
          fontSize: FontSize(14.0),
        ),
        "div": Style(
          margin: Margins.symmetric(vertical: 6.0),
          padding: HtmlPaddings.symmetric(horizontal: 4),
        ),
        "span": Style(
          fontSize: FontSize(14.0),
          color: Colors.black87,
        ),
        "a": Style(
          color: Colors.blue.shade700,
          textDecoration: TextDecoration.underline,
        ),
        "b": Style(
          fontWeight: FontWeight.bold,
        ),
        "i": Style(
          fontStyle: FontStyle.italic,
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        "em": Style(
          fontStyle: FontStyle.italic,
          color: Colors.black87,
        ),
        "h1": Style(
          fontSize: FontSize(22.0),
          fontWeight: FontWeight.w600,
          margin: Margins.symmetric(vertical: 10.0),
          color: Colors.black87,
        ),
        "h2": Style(
          fontSize: FontSize(18.0),
          fontWeight: FontWeight.w600,
          margin: Margins.symmetric(vertical: 8.0),
          color: Colors.black87,
        ),
        "h3": Style(
          fontSize: FontSize(16.0),
          fontWeight: FontWeight.w500,
          margin: Margins.symmetric(vertical: 6.0),
          color: Colors.black87,
        ),
        "ul": Style(
          margin: Margins.symmetric(vertical: 6.0),
          padding: HtmlPaddings.only(left: 20),
        ),
        "ol": Style(
          margin: Margins.symmetric(vertical: 6.0),
          padding: HtmlPaddings.only(left: 20),
        ),
        "li": Style(
          margin: Margins.only(bottom: 4.0),
          padding: HtmlPaddings.only(left: 4.0),
          lineHeight: LineHeight(1.4),
        ),
        "blockquote": Style(
          margin: Margins.symmetric(vertical: 8.0),
          padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
          border: const Border(
            left: BorderSide(
              color: Colors.blue,
              width: 3,
            ),
          ),
          backgroundColor: Colors.grey.shade50,
        ),
        "code": Style(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade100,
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
          fontSize: FontSize(13.0),
        ),
        "pre": Style(
          margin: Margins.symmetric(vertical: 8.0),
          padding: HtmlPaddings.all(12),
          backgroundColor: Colors.grey.shade100,
        ),
      },
    );
  }

  /// Safely renders HTML content, falling back to plain text if needed
  static Widget renderHtmlSafe(String htmlContent) {
    if (htmlContent.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      // First, try to decode if it's JSON-encoded HTML
      if (htmlContent.startsWith('{') || htmlContent.startsWith('[')) {
        try {
          final decoded = jsonDecode(htmlContent);
          if (decoded is String) {
            return renderHtml(decoded);
          } else {
            // If it's not a string after decoding, return a placeholder
            return Text(decoded.toString());
          }
        } catch (e) {
          // If JSON decoding fails, treat as raw HTML
          return renderHtml(htmlContent);
        }
      } else {
        return renderHtml(htmlContent);
      }
    } catch (e) {
      // If anything goes wrong, return the raw content as text
      return Text(htmlContent);
    }
  }
}