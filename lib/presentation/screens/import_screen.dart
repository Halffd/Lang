import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../repositories/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);
  
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ImportService _importService = ImportService();
  ImportProgress? _currentProgress;
  bool _isImporting = false;
  
  @override
  void initState() {
    super.initState();
    _importService.progressStream.listen((progress) {
      setState(() {
        _currentProgress = progress;
      });
      
      if (progress.status == ImportStatus.complete) {
        _showSuccessDialog();
      } else if (progress.status == ImportStatus.error) {
        _showErrorDialog(progress.message);
      }
    });
  }
  
  @override
  void dispose() {
    _importService.dispose();
    super.dispose();
  }
  
  Future<void> _pickAndImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select Yomichan Dictionary',
    );
    
    if (result == null || result.files.isEmpty) return;
    
    final file = File(result.files.single.path!);
    
    setState(() {
      _isImporting = true;
      _currentProgress = null;
    });
    
    try {
      await _importService.importDictionary(file);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
  
  void _cancelImport() {
    _importService.cancel();
    setState(() {
      _isImporting = false;
      _currentProgress = null;
    });
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: const Text('Dictionary imported successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Dictionary'),
      ),
      body: Center(
        child: _isImporting
            ? _buildImportingView()
            : _buildIdleView(),
      ),
    );
  }
  
  Widget _buildIdleView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.file_upload,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Import Yomichan Dictionary',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a Yomichan dictionary ZIP file to import',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickAndImportFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select File'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImportingView() {
    final progress = _currentProgress;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress?.progress,
              strokeWidth: 6,
              backgroundColor: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 32),
          
          // Status message
          Text(
            progress?.message ?? 'Starting import...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress details
          if (progress != null && progress.itemsProcessed != null)
            Text(
              progress.totalItems != null
                  ? '${progress.itemsProcessed} / ${progress.totalItems}'
                  : '${progress.itemsProcessed} items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Percentage
          if (progress != null)
            Text(
              '${(progress.progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Linear progress bar
          if (progress != null)
            LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
            ),
          
          const SizedBox(height: 32),
          
          // Cancel button
          OutlinedButton.icon(
            onPressed: _cancelImport,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}