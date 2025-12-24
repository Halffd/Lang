import 'package:flutter/material.dart';
import 'dart:convert';

class JsonHtmlRenderer {
  /// Renders a JSON structure representing HTML elements to Flutter widgets
  static Widget render(dynamic jsonStructure) {
    if (jsonStructure == null) {
      return const SizedBox.shrink();
    }

    if (jsonStructure is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: jsonStructure
            .map((item) => render(item))
            .toList(),
      );
    }

    if (jsonStructure is Map<String, dynamic>) {
      return _renderElement(jsonStructure);
    }

    // If it's a simple value, render it as text
    return Text(jsonStructure.toString());
  }

  static Widget _renderElement(Map<String, dynamic> element) {
    final tag = element['tag'] as String?;
    final data = element['data'] as Map<String, dynamic>? ?? {};
    final content = element['content'];
    final title = element['title'] as String?;

    // Handle different tags appropriately
    switch (tag) {
      case 'div':
        return _buildDiv(element, data, content, title);
      case 'span':
        return _buildSpan(element, data, content, title);
      case 'ul':
        return _buildUnorderedList(element, content);
      case 'ol':
        return _buildOrderedList(element, content);
      case 'li':
        return _buildListItem(element, content);
      case 'a':
        return _buildLink(element, content);
      case 'ruby':
        return _buildRuby(element, content);
      case 'rt':
        return _buildRubyText(element, content);
      case 'img':
        return _buildImage(element);
      default:
        // Default to rendering content if tag is unknown
        return _renderContent(content);
    }
  }

  static Widget _buildDiv(Map<String, dynamic> element, Map<String, dynamic> data, dynamic content, String? title) {
    final className = data['class'] as String?;
    
    // Special handling for certain div types based on class/content
    if (className?.contains('example-sentence') == true) {
      return _buildExampleSentence(element, content);
    }
    
    if (data['content'] == 'sense-group') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _renderContent(content),
      );
    }

    if (data['content'] == 'sense') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: _renderContent(content),
      );
    }

    if (data['content'] == 'glossary') {
      return _renderContent(content);
    }

    if (data['content'] == 'extra-info') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: _renderContent(content),
      );
    }

    return Container(
      child: _renderContent(content),
    );
  }

  static Widget _buildSpan(Map<String, dynamic> element, Map<String, dynamic> data, dynamic content, String? title) {
    final className = data['class'] as String?;
    
    // Handle different tag types
    if (className?.contains('tag') == true) {
      // This is a tag, render with specific styling
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          title ?? content?.toString() ?? '',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.blue,
          ),
        ),
      );
    }

    if (className?.contains('extra-box') == true) {
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey.shade50,
        ),
        child: _renderContent(content),
      );
    }

    // Default span styling
    return _renderContent(content);
  }

  static Widget _buildUnorderedList(Map<String, dynamic> element, dynamic content) {
    if (content is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14)),
                  Expanded(child: render(item)),
                ],
              );
            })
            .toList(),
      );
    }
    return _renderContent(content);
  }

  static Widget _buildOrderedList(Map<String, dynamic> element, dynamic content) {
    if (content is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index. ', style: const TextStyle(fontSize: 14)),
                  Expanded(child: render(item)),
                ],
              );
            })
            .toList(),
      );
    }
    return _renderContent(content);
  }

  static Widget _buildListItem(Map<String, dynamic> element, dynamic content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: render(content),
    );
  }

  static Widget _buildLink(Map<String, dynamic> element, dynamic content) {
    final href = element['href'] as String?;
    final text = content?.toString() ?? '';
    
    return InkWell(
      onTap: () {
        // Implement link navigation if needed
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  static Widget _buildRuby(Map<String, dynamic> element, dynamic content) {
    if (content is List && content.length >= 2) {
      // First element is the base text, second is the ruby annotation
      final baseText = content[0].toString();
      final rubyContent = content[1] as dynamic;
      String rubyText = '';

      // Parse the ruby content to extract the annotation
      if (rubyContent is Map<String, dynamic> && rubyContent['content'] != null) {
        if (rubyContent['content'] is String) {
          rubyText = rubyContent['content'];
        } else if (rubyContent['content'] is List) {
          // If content is a list, join the elements
          final contentList = rubyContent['content'] as List;
          rubyText = contentList.map((e) => e.toString()).join('');
        }
      }

      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87), // Base text style
          children: [
            TextSpan(
              text: baseText,
              children: [
                if (rubyText.isNotEmpty)
                  TextSpan(
                    text: '\n$rubyText',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return _renderContent(content);
  }

  static Widget _buildRubyText(Map<String, dynamic> element, dynamic content) {
    return const SizedBox.shrink(); // Ruby text is handled by the parent ruby tag
  }

  static Widget _buildImage(Map<String, dynamic> element) {
    // Image handling if needed
    return const Icon(Icons.image_outlined);
  }

  static Widget _buildExampleSentence(Map<String, dynamic> element, dynamic content) {
    if (content is List && content.length >= 2) {
      final japaneseText = render(content[0]);
      final englishText = render(content[1]);

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle(
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              child: japaneseText,
            ),
            const SizedBox(height: 4),
            DefaultTextStyle(
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              child: englishText,
            ),
          ],
        ),
      );
    }
    return _renderContent(content);
  }

  static Widget _renderContent(dynamic content) {
    if (content == null) {
      return const SizedBox.shrink();
    }

    if (content is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content
            .map((item) => render(item))
            .toList(),
      );
    }

    if (content is Map<String, dynamic>) {
      return _renderElement(content);
    }

    // If it's a simple value, render it as text with default styling
    final text = content.toString();
    return Text(
      text,
      style: const TextStyle(fontSize: 14),
    );
  }
}