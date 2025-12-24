import 'package:flutter/material.dart';

class TagRenderer {
  // Define color mappings separately since shades can't be used in const maps
  static Color getColorForTag(String tagCode) {
    switch (tagCode.toLowerCase()) {
      case 'adj-i':
        return Colors.blue;
      case 'adj-na':
        return Colors.blue.shade600;
      case 'adj-pn':
        return Colors.green;
      case 'adj-t':
        return Colors.blue.shade300;
      case 'adv':
        return Colors.orange;
      case 'adv-to':
        return Colors.orange.shade600;
      case 'aux':
        return Colors.purple;
      case 'aux-v':
        return Colors.purple.shade600;
      case 'conj':
        return Colors.teal;
      case 'exp':
        return Colors.deepPurple;
      case 'int':
        return Colors.pink;
      case 'n':
        return Colors.red;
      case 'n-adv':
        return Colors.red.shade400;
      case 'n-pref':
        return Colors.red.shade600;
      case 'n-suf':
        return Colors.red.shade700;
      case 'n-t':
        return Colors.red.shade800;
      case 'pref':
        return Colors.cyan;
      case 'prt':
        return Colors.amber;
      case 'suf':
        return Colors.lime;
      case 'v1':
        return Colors.green;
      case 'v5':
        return Colors.green.shade600;
      case 'v5aru':
        return Colors.green.shade700;
      case 'v5k':
        return Colors.green.shade400;
      case 'v5g':
        return Colors.green.shade500;
      case 'v5s':
        return Colors.green.shade300;
      case 'v5t':
        return Colors.green.shade200;
      case 'v5n':
        return Colors.green.shade100;
      case 'v5b':
        return Colors.green.shade800;
      case 'v5m':
        return Colors.green.shade900;
      case 'v5r':
        return Colors.green.shade700;
      case 'v5u':
        return Colors.green.shade300;
      case 'vk':
        return Colors.blue;
      case 'vs':
        return Colors.blue.shade600;
      case 'vs-i':
        return Colors.blue.shade700;
      case 'vt':
        return Colors.purple;
      case 'vi':
        return Colors.purple.shade600;
      case 'num':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  // Mapping from tag codes to user-friendly names
  static const Map<String, String> tagNames = {
    'adj-i': 'i-adjective',
    'adj-na': 'na-adjective',
    'adj-pn': 'pre-noun',
    'adj-t': 'taru adjective',
    'adv': 'adverb',
    'adv-to': 'adverb taking to',
    'aux': 'auxiliary',
    'aux-v': 'auxiliary verb',
    'conj': 'conjunction',
    'exp': 'expression',
    'int': 'interjection',
    'n': 'noun',
    'n-adv': 'noun adverb',
    'n-pref': 'noun prefix',
    'n-suf': 'noun suffix',
    'n-t': 'time noun',
    'pref': 'prefix',
    'prt': 'particle',
    'suf': 'suffix',
    'v1': 'ichidan verb',
    'v5': 'godan verb',
    'v5aru': 'godan aru verb',
    'v5k': 'godan ku verb',
    'v5g': 'godan gu verb',
    'v5s': 'godan su verb',
    'v5t': 'godan tsu verb',
    'v5n': 'godan nu verb',
    'v5b': 'godan bu verb',
    'v5m': 'godan mu verb',
    'v5r': 'godan ru verb',
    'v5u': 'godan u-verb',
    'vk': 'kuru verb',
    'vs': 'suru verb',
    'vs-i': 'suru adj',
    'vt': 'transitive',
    'vi': 'intransitive',
    'num': 'numeric',
  };

  static Widget renderTag(String tagCode, {double? size}) {
    final tagName = tagNames[tagCode.toLowerCase()] ?? tagCode;
    final color = getColorForTag(tagCode.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: size ?? 10, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              tagName,
              style: TextStyle(
                fontSize: size != null ? size * 0.7 : 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> renderTags(List<String> tagCodes) {
    if (tagCodes.isEmpty) return [];

    return tagCodes
        .map((tag) => renderTag(tag))
        .toList();
  }
}