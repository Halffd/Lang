import 'package:flutter/material.dart';
import '../models/translation_model.dart';
import '../services/translation_service.dart';

class SentenceTranslatorScreen extends StatefulWidget {
  const SentenceTranslatorScreen({Key? key}) : super(key: key);

  @override
  State<SentenceTranslatorScreen> createState() => _SentenceTranslatorScreenState();
}

class _SentenceTranslatorScreenState extends State<SentenceTranslatorScreen> {
  final TranslationService _translationService = TranslationService();
  final TextEditingController _sourceController = TextEditingController();
  
  String _sourceLanguage = 'de';  // German by default
  String _targetLanguage = 'en';  // English by default
  TranslationResult? _translationResult;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final sourceText = _sourceController.text.trim();
    if (sourceText.isEmpty) {
      _showError("Please enter text to translate");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _translationResult = null;
    });

    try {
      final request = TranslationRequest(
        sourceText: sourceText,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );

      final result = await _translationService.translate(request);
      
      setState(() {
        _translationResult = result;
        _isLoading = false;
      });
    } catch (e) {
      _showError("Translation error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _clear() {
    _sourceController.clear();
    setState(() {
      _translationResult = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentence Translator'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Language selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      _buildLanguageDropdown(
                        value: _sourceLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sourceLanguage = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To:',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      _buildLanguageDropdown(
                        value: _targetLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _targetLanguage = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Input text field
            TextField(
              controller: _sourceController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter text to translate...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textInputAction: TextInputAction.newline,
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _translate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Translating...'),
                            ],
                          )
                        : const Text('Translate'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isLoading ? null : _clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onError),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Results
            if (_translationResult != null) ...[
              Expanded(
                child: Row(
                  children: [
                    // Original text column
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original (${_getLanguageName(_sourceLanguage)})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _sourceController.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            // Word-by-word translation for original
                            Text(
                              'Word-by-Word',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _translationResult!.wordTranslations.map((word) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        word.source,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        word.translation,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Translation column
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Translation (${_getLanguageName(_targetLanguage)})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _translationResult!.fullTranslation,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required String value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      items: LanguageOption.all.map((option) {
        return DropdownMenuItem(
          value: option.code,
          child: Text(option.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildWordCard(WordTranslation word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[700]
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word.translation,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            word.source,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    return LanguageOption.all.firstWhere(
      (option) => option.code == languageCode,
      orElse: () => LanguageOption('unknown', 'Unknown'),
    ).name;
  }
}