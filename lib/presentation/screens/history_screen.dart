import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../providers/analyzer_provider.dart';
import '../widgets/word_detail_sheet.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnalyzerProvider>(context);
    final history = provider.history;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.historyTitle),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                // TODO: Implement clear history
              },
            ),
        ],
      ),
      body: history.isEmpty
    ? Center(
          child: Text(
            AppLocalizations.of(context)!.noHistoryYet,
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final word = history[index];
                return ListTile(
                  title: Text(word),
                  leading: const Icon(Icons.history, size: 20, color: Colors.white54),
                  onTap: () async {
                    final result = await provider.lookupHistoryWord(word);
                    if (result != null && context.mounted) {
                      WordDetailSheet.show(context, provider, result);
                    }
                  },
                );
              },
            ),
    );
  }
}
