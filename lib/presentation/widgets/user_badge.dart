import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/presentation/providers/user_profile_provider.dart';

/// Compact chip for the top app bar: avatar + name + language + level/XP.
/// Tap → opens profile settings.
class UserBadge extends StatelessWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const UserProfileEditor()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : 'A',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              profile.displayName.isEmpty ? 'You' : profile.displayName,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                profile.languageTag,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Lv ${profile.level}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile editing sheet. Saves both locally and (if wired) to Supabase.
class UserProfileEditor extends StatefulWidget {
  const UserProfileEditor({super.key});

  @override
  State<UserProfileEditor> createState() => _UserSettingsSheetState();
}

class _UserSettingsSheetState extends State<UserProfileEditor> {
  late final TextEditingController _name;
  late String _native = 'en';
  late String _target = 'ja';

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfileProvider>().profile;
    _name = TextEditingController(text: p.displayName.trim());
    _native = p.nativeLanguage;
    _target = p.currentTargetLanguage;
  }

  static const _langs = [
    'en',
    'es',
    'fr',
    'de',
    'ja',
    'ko',
    'zh',
    'pt',
    'it',
    'ru',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProfileProvider>();
    final p = provider.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _langs.contains(_native) ? _native : 'en',
              decoration: const InputDecoration(labelText: 'Native language'),
              items: _langs
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _native = v ?? 'en'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _langs.contains(_target) ? _target : 'ja',
              decoration: const InputDecoration(labelText: 'Learning'),
              items: _langs
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _target = v ?? 'ja'),
            ),
            Text('Daily goal: ${p.dailyGoal} XP'),
            Slider(
              value: p.dailyGoal.toDouble().clamp(10, 300),
              min: 10,
              max: 300,
              divisions: 29,
              label: '${p.dailyGoal}',
              onChanged: (v) => context.read<UserProfileProvider>().setStats(
                dailyGoal: v.round(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _stat(Icons.military_tech, 'XP', '${p.xp}'),
                _stat(Icons.diamond, 'Gems', '${p.gems}'),
                _stat(Icons.local_fire_department, 'Streak', '${p.streak}'),
                _stat(Icons.school, 'Level', 'Lv ${p.level}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:
                  p.xpInLevel /
                  (p.xpInLevel + p.xpToLevelUp).clamp(1, double.infinity),
            ),
            Text(
              '${p.xpInLevel} / ${p.xpInLevel + p.xpToLevelUp} XP to Lv ${p.level + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (provider.error != null)
              Text(
                'Sync issue: ${provider.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: Text(provider.syncing ? 'Saving…' : 'Save profile'),
              onPressed: () async {
                await provider.update(
                  p.copyWith(
                    displayName: _name.text.trim(),
                    nativeLanguage: _native,
                    currentTargetLanguage: _target,
                    languages: [_target],
                  ),
                );
                if (mounted && context.mounted) Navigator.pop(context);
              },
            ),
            if (provider.hasRemote)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Synced to cloud', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
