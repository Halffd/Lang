import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Settings for where screenshots are stored: the folder the user
/// picks, and the folder currently in effect.
class ScreenshotPathSettings extends StatelessWidget {
  const ScreenshotPathSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final service = ScreenshotService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder),
          title: Text(l10n.screenshotFolder),
          subtitle: FutureBuilder<Directory>(
            future: service.currentDirectory(),
            builder: (context, snapshot) {
              final dir = snapshot.data?.path ?? l10n.screenshotFolderUnknown;
              return Text(
                dir,
                style: TextStyle(fontSize: fs(context, 11)),
              );
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 18),
                tooltip: l10n.screenshotChooseFolder,
                onPressed: () => _pickFolder(context, appState),
              ),
              if (appState.screenshotDirectory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 18),
                  tooltip: l10n.screenshotResetFolder,
                  onPressed: () => appState.setScreenshotDirectory(''),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFolder(
    BuildContext context,
    AppState appState,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.screenshotChooseFolder,
    );
    if (picked == null || picked.isEmpty) return;
    appState.setScreenshotDirectory(picked);
  }
}
