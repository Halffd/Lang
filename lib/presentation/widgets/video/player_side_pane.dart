/// The side pane that sits next to the player on wide screens, and in a
/// drawer on narrow ones.
///
/// Follows Flow's layout: the tabs are Description, Chapters, Transcript
/// and Settings, and the current chapter's progress is shown in the
/// chapter list.
library;

import 'package:flutter/material.dart';

import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/chapter_parser.dart';
import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/popup_scan_blocker.dart';

import 'player_time.dart';

/// Which tab of the side pane is open.
enum PlayerPaneTab {
  description,
  chapters,
  transcript,
  settings;

  /// The label shown on the tab.
  String label(AppLocalizations? l10n) => switch (this) {
    PlayerPaneTab.description => l10n?.videoDescription ?? 'Description',
    PlayerPaneTab.chapters => l10n?.videoChapters ?? 'Chapters',
    PlayerPaneTab.transcript => l10n?.videoShowTranscript ?? 'Transcript',
    PlayerPaneTab.settings => l10n?.videoSettings ?? 'Settings',
  };

  /// The icon shown on the tab.
  IconData get icon => switch (this) {
    PlayerPaneTab.description => Icons.description_outlined,
    PlayerPaneTab.chapters => Icons.list_alt_outlined,
    PlayerPaneTab.transcript => Icons.closed_caption_outlined,
    PlayerPaneTab.settings => Icons.tune,
  };
}

/// The contents of the side pane.
///
/// The pane owns no state of its own beyond the selected tab; the tab
/// contents are supplied by the caller so the player screen stays the
/// single owner of playback state.
class PlayerSidePane extends StatefulWidget {
  const PlayerSidePane({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.description,
    required this.chapters,
    required this.currentPosition,
    required this.transcript,
    required this.settings,
    this.author,
    this.title,
    this.onSelectChapter,
    this.onSelectLine,
    this.onLookupLine,
    this.transcriptBuilder,
    this.activeTranscriptIndex = -1,
    this.showAuthor = true,
  });

  final PlayerPaneTab tab;
  final ValueChanged<PlayerPaneTab> onTabChanged;

  /// The video description, shown as selectable text.
  final String description;

  final List<YouTubeChapter> chapters;

  /// The playhead, used to mark the current chapter.
  final Duration currentPosition;

  /// The transcript lines; each entry is a cue plus its text.
  final List<({String text, Duration start})> transcript;

  /// The settings tab contents.
  final List<Widget> settings;

  final String? title;
  final String? author;

  final ValueChanged<YouTubeChapter>? onSelectChapter;

  /// Called with the index of the transcript line the user tapped.
  final ValueChanged<int>? onSelectLine;

  /// Called with the index of the transcript line the user long-pressed.
  final ValueChanged<int>? onLookupLine;

  /// Builds the text of one transcript line. The default renders plain
  /// text; the player overrides it to add reading annotations.
  final Widget Function(BuildContext context, String text, bool active)?
  transcriptBuilder;

  /// Index of the transcript line that matches the playhead.
  final int activeTranscriptIndex;

  final bool showAuthor;

  @override
  State<PlayerSidePane> createState() => _PlayerSidePaneState();
}

class _PlayerSidePaneState extends State<PlayerSidePane> {
  /// Scrolls the transcript to keep the playing line in view.
  final _transcriptScroll = ScrollController();

  @override
  void didUpdateWidget(PlayerSidePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTranscriptIndex != oldWidget.activeTranscriptIndex) {
      _scrollToActiveLine();
    }
  }

  @override
  void dispose() {
    _transcriptScroll.dispose();
    super.dispose();
  }

  /// Bring the playing line into view. The rows are fixed-height list
  /// tiles, so an estimated extent keeps this independent of text length.
  void _scrollToActiveLine() {
    final index = widget.activeTranscriptIndex;
    if (index < 0 || !_transcriptScroll.hasClients) return;
    final target = (index * 56.0).clamp(
      0.0,
      _transcriptScroll.position.maxScrollExtent,
    );
    _transcriptScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null && widget.title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              widget.title!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fs(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.showAuthor &&
            widget.author != null &&
            widget.author!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fs(context, 12),
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        _TabStrip(
          tab: widget.tab,
          onChanged: widget.onTabChanged,
          l10n: l10n,
        ),
        const Divider(height: 1),
        Expanded(child: _buildTabBody(context, theme, l10n)),
      ],
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    switch (widget.tab) {
      case PlayerPaneTab.description:
        return _buildDescription(context, theme, l10n);
      case PlayerPaneTab.chapters:
        return _buildChapters(context, theme, l10n);
      case PlayerPaneTab.transcript:
        return _buildTranscript(context, theme, l10n);
      case PlayerPaneTab.settings:
        return _buildSettings(context, theme, l10n);
    }
  }

  Widget _buildDescription(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    if (widget.description.trim().isEmpty) {
      return _EmptyPane(
        message: l10n?.videoNoDescription ?? 'No description available.',
      );
    }
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(
            widget.description.trim(),
            style: TextStyle(
              fontSize: fs(context, 12),
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapters(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    if (widget.chapters.isEmpty) {
      return _EmptyPane(
        message: l10n?.videoNoChapters ?? 'No chapters in this video.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.chapters.length,
      itemBuilder: (context, i) {
        final chapter = widget.chapters[i];
        final active = chapter.contains(widget.currentPosition);
        // how far the current chapter has played, for the progress hint
        final chapterMs = chapter.end.inMilliseconds -
            chapter.start.inMilliseconds;
        final playedMs = widget.currentPosition.inMilliseconds -
            chapter.start.inMilliseconds;
        final fraction = chapterMs <= 0
            ? 0.0
            : (playedMs / chapterMs).clamp(0.0, 1.0);

        return ListTile(
          dense: true,
          selected: active,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.25,
          ),
          leading: SizedBox(
            width: 46,
            // the timestamp is chrome, not study text: never scan it
            child: PopupScanBlocker(
              child: Text(
                formatPlayerTime(chapter.start),
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          title: Text(
            chapter.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fs(context, 12),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: active && fraction > 0
              ? LinearProgressIndicator(
                  value: fraction,
                  minHeight: 2,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                )
              : null,
          onTap: () => widget.onSelectChapter?.call(chapter),
        );
      },
    );
  }

  Widget _buildTranscript(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    if (widget.transcript.isEmpty) {
      return _EmptyPane(
        message: l10n?.videoNoSubs ?? 'No subtitle track loaded.',
      );
    }
    return ListView.builder(
      controller: _transcriptScroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.transcript.length,
      itemBuilder: (context, i) {
        final line = widget.transcript[i];
        final active = i == widget.activeTranscriptIndex;
        final builder = widget.transcriptBuilder;
        final title = builder != null
            ? builder(context, line.text, active)
            : Text(
                line.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fs(context, 12),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              );
        return ListTile(
          dense: true,
          selected: active,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.25,
          ),
          leading: SizedBox(
            width: 46,
            // the timestamp is chrome, not study text: never scan it
            child: PopupScanBlocker(
              child: Text(
                formatPlayerTime(line.start),
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          title: title,
          onTap: () => widget.onSelectLine?.call(i),
          onLongPress: () => widget.onLookupLine?.call(i),
        );
      },
    );
  }

  Widget _buildSettings(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    if (widget.settings.isEmpty) {
      return _EmptyPane(
        message: l10n?.videoNoSettings ?? 'No settings available.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: widget.settings,
    );
  }

}

/// The row of tabs at the top of the pane.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tab,
    required this.onChanged,
    required this.l10n,
  });

  final PlayerPaneTab tab;
  final ValueChanged<PlayerPaneTab> onChanged;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final entry in PlayerPaneTab.values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChanged(entry),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: entry == tab
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        entry.icon,
                        size: 18,
                        color: entry == tab
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fs(context, 10),
                          color: entry == tab
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          fontWeight: entry == tab
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The placeholder shown when a tab has nothing to display.
class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(context, 12),
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
