import 'package:flutter/material.dart';
import 'package:lang/data/repositories/srs_service.dart';

class SettingsTab extends StatefulWidget {
  final SRSService srsService;

  const SettingsTab({required this.srsService, super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int _maxReviews = 50;
  int _newCards = 10;
  bool _autoAudio = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Max Reviews per Session'),
            subtitle: Text('$_maxReviews cards'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _maxReviews.toDouble(),
                min: 10,
                max: 100,
                divisions: 9,
                label: '$_maxReviews',
                onChanged: (v) => setState(() => _maxReviews = v.round()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fiber_new),
            title: const Text('New Cards per Session'),
            subtitle: Text('$_newCards cards'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _newCards.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                label: '$_newCards',
                onChanged: (v) => setState(() => _newCards = v.round()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Auto-play Audio'),
            subtitle: const Text('Play reading when card is shown'),
            value: _autoAudio,
            onChanged: (v) => setState(() => _autoAudio = v),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Keyboard Shortcuts (Study tab)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _ShortcutRow('Space', 'Show/Hide answer'),
        const _ShortcutRow('1-5', 'Rate card (Again to Perfect)'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Export Cards?'),
                content: const Text('This would export all cards as JSON. Coming soon.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                ],
              ),
            );
          },
          icon: const Icon(Icons.upload),
          label: const Text('Export Cards (JSON)'),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcutKey;
  final String action;

  const _ShortcutRow(this.shortcutKey, this.action);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(shortcutKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(action, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}