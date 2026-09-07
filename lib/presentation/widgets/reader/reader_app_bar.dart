import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Text Reader Mode'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          // This will be handled by the parent widget
          Navigator.of(context).maybePop();
        },
      ),
      actions: const [
        _AutoTranslateToggle(),
        SizedBox(width: 8),
        _WiktionaryToggle(),
        SizedBox(width: 8),
        _HelpButton(),
      ],
    );
  }
}

class _AutoTranslateToggle extends StatelessWidget {
  const _AutoTranslateToggle();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Auto:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Switch(
              value: appState.autoTranslate,
              onChanged: appState.setAutoTranslate,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        );
      },
    );
  }
}

class _WiktionaryToggle extends StatelessWidget {
  const _WiktionaryToggle();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wik:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Switch(
              value: appState.showWiktionary,
              onChanged: appState.setShowWiktionary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        );
      },
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Shortcuts'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arrows: Navigate words'),
                Text('PgUp/PgDn: Navigate sentences'),
                Text('Home/End: Start/End of sentence'),
                Text('Space: Show definition'),
                Text('Enter: Toggle Anki'),
                Text('B: Toggle Favorites'),
                Text('Delete: Delete word'),
                Text('M: Toggle Auto-paste'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      },
    );
  }
}