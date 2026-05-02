import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/screen_size.dart';
import '../providers/ai_provider.dart';
import '../../domain/entities/ai_message.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AiProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aiAssistant),
        actions: [
          DropdownButton<String>(
            value: provider.selectedProvider,
        items: [
          DropdownMenuItem(value: 'Gemini', child: Text('Gemini')),
          DropdownMenuItem(value: 'ChatGPT', child: Text(AppLocalizations.of(context)!.chatGptMock)),
            ],
            onChanged: (val) => provider.setProvider(val!),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => provider.clearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
        // Templates
        SizedBox(
          height: ScreenSize.isCompact(context) ? 40 : 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ...provider.allPrompts.map((t) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text(t['name']!),
                      onPressed: () {
                        _controller.text = t['prompt']!;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.translate, size: 16),
                    label: Text(AppLocalizations.of(context)!.translate),
                    onPressed: () => provider.runTranslate(_controller.text, 'English'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.summarize, size: 16),
                    label: Text(AppLocalizations.of(context)!.summarize),
                    onPressed: () => provider.runSummarize(_controller.text),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.reorder, size: 16),
                    label: Text(AppLocalizations.of(context)!.breakdown),
                    onPressed: () => provider.runBreakdown(_controller.text),
                  ),
                ),
              ],
            ),
          ),
          // Breakdown Results
          if (provider.lastBreakdown.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.aiBreakdown, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => provider.updateSettings(), // This will just refresh UI
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.lastBreakdown.map((item) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item['term']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(item['meaning']!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final msg = provider.messages[index];
                final isUser = msg.sender == AiSender.user;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                maxWidth: ScreenSize.isCompact(context)
                    ? MediaQuery.of(context).size.width * 0.9
                    : MediaQuery.of(context).size.width * 0.8,
              ),
                    decoration: BoxDecoration(
                      color: isUser 
                        ? theme.colorScheme.primaryContainer 
                        : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : null,
                        bottomLeft: !isUser ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(base64Decode(msg.imageUrl!)),
                            ),
                          ),
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isUser 
                              ? theme.colorScheme.onPrimaryContainer 
                              : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
        // Input Area
        Padding(
          padding: ScreenSize.adaptivePadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.askAnything,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton.filled(
                      onPressed: provider.isLoading 
                        ? null 
                        : () {
                            provider.sendMessage(_controller.text);
                            _controller.clear();
                            _scrollToBottom();
                          },
                      icon: const Icon(Icons.send),
                    ),
                    IconButton(
                      onPressed: provider.isLoading 
                        ? null 
                        : () {
                            provider.generateImage(_controller.text);
                            _controller.clear();
                            _scrollToBottom();
                          },
                      icon: const Icon(Icons.image),
                      tooltip: AppLocalizations.of(context)!.generateImage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
