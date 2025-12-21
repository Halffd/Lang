import 'package:flutter/material.dart';
import '../utils/character_breakdown.dart';

class CharacterBreakdownWidget extends StatelessWidget {
  final List<CharacterInfo> characterInfos;
  final String originalWord;
  final VoidCallback? onClose;

  const CharacterBreakdownWidget({
    Key? key,
    required this.characterInfos,
    required this.originalWord,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Breakdown of: $originalWord',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: characterInfos.map((charInfo) {
                return _buildCharacterCard(context, charInfo);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(BuildContext context, CharacterInfo charInfo) {
    if (!charInfo.isIdeographic) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          charInfo.character,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _showCharacterDetails(context, charInfo);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: charInfo.pinyin.isNotEmpty ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: charInfo.pinyin.isNotEmpty ? Colors.blue[200]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              charInfo.character,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (charInfo.pinyin.isNotEmpty)
              Text(
                charInfo.pinyin,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
              ),
            if (charInfo.meaning.isNotEmpty && charInfo.meaning.length < 30)
              Text(
                charInfo.meaning,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _showCharacterDetails(BuildContext context, CharacterInfo charInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Details for: ${charInfo.character}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (charInfo.pinyin.isNotEmpty)
                _buildDetailRow('Pinyin:', charInfo.pinyin),
              if (charInfo.onyomi.isNotEmpty)
                _buildDetailRow('On\'yomi:', charInfo.onyomi),
              if (charInfo.kunyomi.isNotEmpty)
                _buildDetailRow('Kun\'yomi:', charInfo.kunyomi),
              if (charInfo.meaning.isNotEmpty)
                _buildDetailRow('Meaning:', charInfo.meaning),
              if (charInfo.definitions.isNotEmpty)
                ..._buildDefinitions(charInfo.definitions),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildDefinitions(List<String> definitions) {
    return [
      const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text(
          'Definitions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      ...definitions.asMap().entries.map((entry) {
        final index = entry.key;
        final definition = entry.value;
        return Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
          child: Text('${index + 1}. $definition'),
        );
      }).toList(),
    ];
  }
}