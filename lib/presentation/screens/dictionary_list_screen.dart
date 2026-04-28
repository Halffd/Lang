import 'package:flutter/material.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../repositories/dictionary_service.dart';
import 'import_screen.dart';

class DictionaryListScreen extends StatefulWidget {
  const DictionaryListScreen({Key? key}) : super(key: key);

  @override
  State<DictionaryListScreen> createState() => _DictionaryListScreenState();
}

class _DictionaryListScreenState extends State<DictionaryListScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  List<model.YomichanDictionary> _dictionaries = [];
  Map<int, model.DictionaryStats> _stats = {};
  bool _isLoading = true;
  
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import a Yomichan dictionary to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
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
      onReorder: (oldIndex, newIndex) {
        // Implement reordering logic here
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final dict = _dictionaries.removeAt(oldIndex);
          _dictionaries.insert(newIndex, dict);
        });
      },
      itemBuilder: (context, index) {
        final dict = _dictionaries[index];
        final stats = _stats[dict.id!];
        
        return Card(
          key: ValueKey(dict.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: dict.enabled ? Colors.blue : Colors.grey,
              child: Text(
                dict.title[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              dict.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: dict.enabled ? null : Colors.grey,
              ),
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
                Switch(
                  value: dict.enabled,
                  onChanged: (_) => _toggleDictionary(dict),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'info') {
                      _showDictionaryInfo(dict);
                    } else if (value == 'delete') {
                      _deleteDictionary(dict);
                    }
                  },
                  itemBuilder: (context) => [
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
        );
      },
    );
  }
}