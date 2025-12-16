import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // General settings section
          const Text(
            'General Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Language selection
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dictionary Language',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    value: appState.language,
                    items: const [
                      DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                      DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                      DropdownMenuItem(value: 'ko', child: Text('Korean')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        appState.setLanguage(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Theme settings
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme'),
                    value: appState.darkMode,
                    onChanged: (value) {
                      appState.setDarkMode(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Search settings section
          const Text(
            'UI & Navigation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Auto-hide Navigation'),
                    subtitle: const Text('Hide navigation bar when mouse is not near bottom'),
                    value: appState.autoHideNavigation,
                    onChanged: (value) => appState.setAutoHideNavigation(value),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Default Flex Mode'),
                    subtitle: const Text('Use flexible grid layout for word lists by default'),
                    value: appState.defaultFlexMode,
                    onChanged: (value) => appState.setDefaultFlexMode(value),
                  ),
                  const Divider(),
                   const ListTile(
                    title: Text('Keyboard Shortcuts'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ctrl + 1: Search'),
                        Text('Ctrl + 2: Reader'),
                        Text('Ctrl + 3: Lists'),
                        Text('Ctrl + 4: Dictionaries'),
                        Text('Ctrl + 5: Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search settings section
          const Text(
            'Search Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Search options
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Options',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Clipboard Monitor'),
                    subtitle: const Text('Automatically search for clipboard content'),
                    value: appState.clipboardMonitor,
                    onChanged: (value) {
                      appState.setClipboardMonitor(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Automatic Kana Conversion'),
                    subtitle: const Text('Convert romaji to kana while typing'),
                    value: appState.automaticKanaConversion,
                    onChanged: (value) {
                      appState.setAutomaticKanaConversion(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Display options
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display Options',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Particles'),
                    subtitle: const Text('Highlight Japanese particles in text'),
                    value: appState.showParticles,
                    onChanged: (value) {
                      appState.setShowParticles(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Show Kanji'),
                    subtitle: const Text('Display kanji information'),
                    value: appState.showKanji,
                    onChanged: (value) {
                      appState.setShowKanji(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Minimum Frequency'),
                    subtitle: const Text('Filter words by frequency (lower = more common)'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        controller: TextEditingController(text: appState.minFrequency.toString()),
                        onChanged: (value) {
                          final intValue = int.tryParse(value);
                          if (intValue != null) {
                            appState.setMinFrequency(intValue);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // About section
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yomitan Search',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text('Version 1.0.0'),
                  const SizedBox(height: 16),
                  const Text(
                    'A Japanese language learning tool with dictionary and word saving features.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Open privacy policy
                    },
                    child: const Text('Privacy Policy'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Open terms of service
                    },
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
