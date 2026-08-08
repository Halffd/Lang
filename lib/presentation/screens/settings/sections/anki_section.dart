import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/app_state.dart';
import '../../data/services/anki_connect_service.dart';
import '../../utils/screen_size.dart';

class AnkiSettingsSection extends StatelessWidget {
  const AnkiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.advancedSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildAnkiProfilesCard(context, appState, localizations),
        _buildAnkiConnectCard(context, appState, localizations),
      ],
    );
  }

  Widget _buildAnkiProfilesCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.ankiProfiles, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildAnkiDeckDropdown(context, appState, localizations),
            const SizedBox(height: 16),
            _buildProfileDropdown(context, appState, localizations),
          ],
        ),
      ),
    );
  }

  Widget _buildAnkiDeckDropdown(BuildContext context, AppState appState, AppLocalizations localizations) {
    return ScreenSize.isCompact(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.currentAnkiDeck),
              const SizedBox(height: 8),
              _buildDropdown(
                context: context,
                value: appState.ankiDecks.contains(appState.currentAnkiDeck)
                    ? appState.currentAnkiDeck
                    : (appState.ankiDecks.isNotEmpty ? appState.ankiDecks.first : 'Default'),
                items: appState.ankiDecks.isNotEmpty
                    ? appState.ankiDecks.map((deck) => DropdownMenuItem(value: deck, child: Text(deck))).toList()
                    : [const DropdownMenuItem(value: 'Default', child: Text('Default'))],
                onChanged: (value) {
                  if (value != null) {
                    appState.setCurrentAnkiDeck(value);
                  }
                },
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 3, child: Text(localizations.currentAnkiDeck)),
              Expanded(
                flex: 4,
                child: _buildDropdown(
                  context: context,
                  value: appState.ankiDecks.contains(appState.currentAnkiDeck)
                      ? appState.currentAnkiDeck
                      : (appState.ankiDecks.isNotEmpty ? appState.ankiDecks.first : 'Default'),
                  items: appState.ankiDecks.isNotEmpty
                      ? appState.ankiDecks.map((deck) => DropdownMenuItem(value: deck, child: Text(deck))).toList()
                      : [const DropdownMenuItem(value: 'Default', child: Text('Default'))],
                  onChanged: (value) {
                    if (value != null) {
                      appState.setCurrentAnkiDeck(value);
                    }
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildProfileDropdown(BuildContext context, AppState appState, AppLocalizations localizations) {
    return ScreenSize.isCompact(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.currentProfile),
              const SizedBox(height: 8),
              _buildDropdown(
                context: context,
                value: appState.profiles.contains(appState.currentProfile)
                    ? appState.currentProfile
                    : (appState.profiles.isNotEmpty ? appState.profiles.first : 'Default'),
                items: appState.profiles.isNotEmpty
                    ? appState.profiles.map((profile) => DropdownMenuItem(value: profile, child: Text(profile))).toList()
                    : [const DropdownMenuItem(value: 'Default', child: Text('Default'))],
                onChanged: (value) {
                  if (value != null) {
                    appState.setCurrentProfile(value);
                  }
                },
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 3, child: Text(localizations.currentProfile)),
              Expanded(
                flex: 4,
                child: _buildDropdown(
                  context: context,
                  value: appState.profiles.contains(appState.currentProfile)
                      ? appState.currentProfile
                      : (appState.profiles.isNotEmpty ? appState.profiles.first : 'Default'),
                  items: appState.profiles.isNotEmpty
                      ? appState.profiles.map((profile) => DropdownMenuItem(value: profile, child: Text(profile))).toList()
                      : [const DropdownMenuItem(value: 'Default', child: Text('Default'))],
                  onChanged: (value) {
                    if (value != null) {
                      appState.setCurrentProfile(value);
                    }
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildAnkiConnectCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('AnkiConnect', style: const TextStyle(fontWeight: FontWeight.bold))),
                Switch(value: appState.ankiConnectEnabled, onChanged: (v) => appState.setAnkiConnectEnabled(v)),
              ],
            ),
            const SizedBox(height: 8),
            if (appState.ankiConnectEnabled) ...[
              const Text('API URL', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://127.0.0.1:8765',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                controller: TextEditingController(text: appState.ankiConnectUrl),
                onChanged: (v) => appState.setAnkiConnectUrl(v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final service = AnkiConnectService(appState.ankiConnectUrl);
                  final ok = await service.testConnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'AnkiConnect connected' : 'Connection failed'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.wifi_find, size: 18),
                label: const Text('Test Connection'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        labelText: 'Deck',
                      ),
                      value: appState.ankiDecks.contains(appState.currentAnkiDeck)
                          ? appState.currentAnkiDeck
                          : (appState.ankiDecks.isNotEmpty ? appState.ankiDecks.first : 'Default'),
                      items: appState.ankiDecks.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) {
                        if (v != null) appState.setCurrentAnkiDeck(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Fetch decks from AnkiConnect',
                    onPressed: () async {
                      final service = AnkiConnectService(appState.ankiConnectUrl);
                      try {
                        final decks = await service.getDeckNames();
                        appState.setAnkiDecks(decks);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Found ${decks.length} decks')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Basic',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        labelText: 'Note Type',
                      ),
                      controller: TextEditingController(text: appState.ankiConnectModel),
                      onChanged: (v) => appState.setAnkiConnectModel(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Fetch note types from AnkiConnect',
                    onPressed: () async {
                      final service = AnkiConnectService(appState.ankiConnectUrl);
                      try {
                        final models = await service.getModelNames();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => SimpleDialog(
                              title: const Text('Select Note Type'),
                              children: models.map((m) => SimpleDialogOption(
                                onPressed: () {
                                  appState.setAnkiConnectModel(m);
                                  Navigator.pop(ctx);
                                },
                                child: Text(m),
                              )).toList(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Auto-sync to Anki', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Send to Anki when saving a word', style: TextStyle(fontSize: 12)),
                value: appState.ankiSyncOnSave,
                onChanged: (v) => appState.setAnkiSyncOnSave(v),
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}