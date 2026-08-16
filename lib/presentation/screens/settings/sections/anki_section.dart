import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/data/services/anki_connect_service.dart';
import 'package:lang/utils/screen_size.dart';

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
            Text(localizations.ankiProfiles, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAnkiDeckDropdown(context, appState, localizations),
            const SizedBox(height: 16),
            _buildProfileDropdown(context, appState, localizations),
          ],
        ),
      ),
    );
  }

  Widget _buildAnkiDeckDropdown(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.currentAnkiDeck, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: appState.ankiDeck,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          items: appState.ankiDecks.map((deck) => DropdownMenuItem(
            value: deck,
            child: Text(deck),
          )).toList(),
          onChanged: (value) => appState.setAnkiDeck(value!),
        ),
      ],
    );
  }

  Widget _buildProfileDropdown(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.currentProfile, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: appState.currentProfile,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          items: appState.profiles.map((profile) => DropdownMenuItem(
            value: profile,
            child: Text(profile),
          )).toList(),
          onChanged: (value) => appState.setCurrentProfile(value!),
        ),
      ],
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
            Text(localizations.ankiConnect, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAnkiConnectForm(context, appState, localizations),
          ],
        ),
      ),
    );
  }

  Widget _buildAnkiConnectForm(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(localizations.ankiConnectEnabled),
          value: appState.ankiConnectEnabled,
          onChanged: (value) => appState.setAnkiConnectEnabled(value),
        ),
        if (appState.ankiConnectEnabled) ...[
          TextFormField(
            initialValue: appState.ankiConnectUrl,
            decoration: InputDecoration(
              labelText: 'AnkiConnect URL',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => appState.setAnkiConnectUrl(value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: appState.ankiConnectModel,
            decoration: InputDecoration(
              labelText: localizations.ankiConnectModel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => appState.setAnkiConnectModel(value),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(localizations.ankiSyncOnSave),
            value: appState.ankiSyncOnSave,
            onChanged: (value) => appState.setAnkiSyncOnSave(value),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final service = AnkiConnectService(appState.ankiConnectUrl);
              final connected = await service.testConnection();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(connected ? 'AnkiConnect connected!' : 'Connection failed'),
                    backgroundColor: connected ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.link),
            label: const Text('Test Connection'),
          ),
        ],
      ],
    );
  }
}