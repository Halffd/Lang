import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/dictionary.dart' as model;
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/presentation/screens/import_screen.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/utils/font_scale.dart';

class DictionaryListScreen extends StatefulWidget {
  const DictionaryListScreen({super.key});

  @override
  State<DictionaryListScreen> createState() => _DictionaryListScreenState();
}

class _DictionaryListScreenState extends State<DictionaryListScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  List<model.YomichanDictionary> _dictionaries = [];
  Map<int, model.DictionaryStats> _stats = {};
  bool _isLoading = true;
  final Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    setState(() => _isLoading = true);

    try {
      final dictionaries = await _dictionaryService.getAllDictionaries();
      final stats = <int, model.DictionaryStats>{};

      for (final dict in dictionaries) {
        stats[dict.id!] = await _dictionaryService.getDictionaryStats(dict.id!);
      }

      // Sort by priority (higher priority first)
      dictionaries.sort((a, b) => b.priority.compareTo(a.priority));

      setState(() {
        _dictionaries = dictionaries;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dictionaries: $e')),
        );
      }
    }
  }

  Future<void> _navigateToImport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportScreen()),
    );

    if (result == true) {
      _loadDictionaries();
    }
  }

  Future<void> _toggleDictionary(model.YomichanDictionary dict) async {
    try {
      await _dictionaryService.updateDictionary(
        dict.copyWith(enabled: !dict.enabled),
      );
      await _loadDictionaries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating dictionary: $e')),
        );
      }
    }
  }

  void _toggleFavorite(int id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  Future<void> _editDictionary(model.YomichanDictionary dict) async {
    final nameController = TextEditingController(text: dict.title);
    final descController = TextEditingController(text: dict.description ?? '');
    final priorityController = TextEditingController(text: dict.priority.toString());

    // per-profile conditions for this dictionary
    final appState = context.read<AppState>();
    final profile = appState.yomitanOptions.activeProfile;
    final settings = profile.dictionarySettings.forDictionary(dict.title);
    final languagesController = TextEditingController(
      text: settings.languages.join(', '),
    );
    final readingsController = TextEditingController(
      text: settings.readingPatterns.join(', '),
    );
    final regexController = TextEditingController(text: settings.termRegex ?? '');
    final posController = TextEditingController(
      text: settings.partOfSpeechTags.join(', '),
    );
    bool conditionEnabled = !settings.hasNoConditions;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Edit Dictionary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priorityController,
                decoration: const InputDecoration(labelText: 'Priority (higher = first)'),
                keyboardType: TextInputType.number,
              ),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Lookup conditions (active profile)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: fs(context, 13))),
              ),
              SwitchListTile(
                dense: true,
                title: Text('Use conditions', style: TextStyle(fontSize: fs(context, 13))),
                subtitle: Text(
                    'Dictionary only matches lookups meeting all conditions',
                    style: TextStyle(fontSize: fs(context, 11))),
                value: conditionEnabled,
                onChanged: (v) => setDialogState(() => conditionEnabled = v),
              ),
              if (conditionEnabled) ...[
                TextField(
                  controller: languagesController,
                  decoration: const InputDecoration(
                    labelText: 'Languages (comma separated)',
                    hintText: 'ja, zh',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: readingsController,
                  decoration: const InputDecoration(
                    labelText: 'Reading patterns (exact or *)',
                    hintText: 'よ*, た*',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: regexController,
                  decoration: const InputDecoration(
                    labelText: 'Term regex',
                    hintText: '^\u3041-\u3096 pattern or empty',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: posController,
                  decoration: const InputDecoration(
                    labelText: 'Part-of-speech tags (comma separated)',
                    hintText: 'noun, verb',
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final priority = int.tryParse(priorityController.text) ?? dict.priority;
              await _dictionaryService.updateDictionary(
                dict.copyWith(
                  title: nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  priority: priority,
                ),
              );
              // save per-profile conditions
              if (conditionEnabled) {
                settings.languages = _splitList(languagesController.text);
                settings.readingPatterns = _splitList(readingsController.text);
                settings.termRegex = regexController.text.trim().isEmpty
                    ? null
                    : regexController.text.trim();
                settings.partOfSpeechTags = _splitList(posController.text);
              } else {
                settings.languages = [];
                settings.readingPatterns = [];
                settings.termRegex = null;
                settings.partOfSpeechTags = [];
              }
              appState.setYomitanOptions(appState.yomitanOptions);
              if (mounted) {
                Navigator.pop(ctx);
                _loadDictionaries();
              }
            },
            child: const Text('Save'),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _setPriority(model.YomichanDictionary dict, int delta) async {
    final newPriority = dict.priority + delta;
    await _dictionaryService.updateDictionary(
      dict.copyWith(priority: newPriority),
    );
    _loadDictionaries();
  }

  Future<void> _reorderDictionaries(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    setState(() {
      final dict = _dictionaries.removeAt(oldIndex);
      _dictionaries.insert(newIndex, dict);
    });

    // Update priorities based on new order (higher index = lower priority)
    for (int i = 0; i < _dictionaries.length; i++) {
      final dict = _dictionaries[i];
      final newPriority = _dictionaries.length - i;
      if (dict.priority != newPriority) {
        await _dictionaryService.updateDictionary(
          dict.copyWith(priority: newPriority),
        );
      }
    }
    _loadDictionaries();
  }

  Future<void> _deleteDictionary(model.YomichanDictionary dict) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dictionary'),
        content: Text('Are you sure you want to delete "${dict.title}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dictionaryService.deleteDictionary(dict.id!);
      await _loadDictionaries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${dict.title}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting dictionary: $e')),
        );
      }
    }
  }

  Future<void> _showDictionaryInfo(model.YomichanDictionary dict) async {
    final stats = _stats[dict.id!];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dict.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Name', dict.name),
              if (dict.revision != null)
                _buildInfoRow('Revision', dict.revision!),
              if (dict.author != null)
                _buildInfoRow('Author', dict.author!),
              if (dict.description != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(dict.description!),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Statistics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (stats != null) ...[
                _buildInfoRow('Entries', stats.entries.toString()),
                _buildInfoRow('Kanji', stats.kanji.toString()),
              ],
              const SizedBox(height: 12),
              _buildInfoRow('Priority', dict.priority.toString()),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Imported',
                _formatDate(dict.importedAt),
              ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionaries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDictionaries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dictionaries.isEmpty
              ? _buildEmptyState()
              : _buildDictionaryList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToImport,
        icon: const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Dictionaries',
              style: TextStyle(
                fontSize: fs(context, 20, 'headers'),
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import a Yomichan dictionary to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs(context, 14),
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDictionaryList() {
    return ReorderableListView.builder(
      itemCount: _dictionaries.length,
      onReorder: _reorderDictionaries,
      itemBuilder: (context, index) {
        final dict = _dictionaries[index];
        final stats = _stats[dict.id!];
        final isFavorite = _favoriteIds.contains(dict.id);

        return Card(
          key: ValueKey(dict.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: dict.enabled ? Colors.blue : Colors.grey,
                      child: Text(
                        dict.title[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (isFavorite)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Icon(Icons.star, size: 16, color: Colors.amber[700]),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dict.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: dict.enabled ? null : Colors.grey,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dict.priority > 0 ? Colors.purple[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${dict.priority}',
                        style: TextStyle(
                          fontSize: fs(context, 10),
                          color: dict.priority > 0 ? Colors.purple[700] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dict.revision != null)
                      Text('Revision: ${dict.revision}'),
                    if (stats != null)
                      Text('${stats.entries} entries • ${stats.kanji} kanji'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Priority controls
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: 'Increase priority',
                      onPressed: () => _setPriority(dict, 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      tooltip: 'Decrease priority',
                      onPressed: dict.priority > 0 ? () => _setPriority(dict, -1) : null,
                    ),
                    Switch(
                      value: dict.enabled,
                      onChanged: (_) => _toggleDictionary(dict),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'info') {
                          _showDictionaryInfo(dict);
                        } else if (value == 'edit') {
                          _editDictionary(dict);
                        } else if (value == 'delete') {
                          _deleteDictionary(dict);
                        } else if (value == 'favorite') {
                          _toggleFavorite(dict.id!);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(isFavorite ? Icons.star : Icons.star_border,
                                   color: isFavorite ? Colors.amber[700] : null),
                              const SizedBox(width: 12),
                              Text(isFavorite ? 'Unfavorite' : 'Favorite'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline),
                              SizedBox(width: 12),
                              Text('Info'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
              // Drag handle indicator
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 60),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  static List<String> _splitList(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
