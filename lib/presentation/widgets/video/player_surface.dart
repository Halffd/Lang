/// The video surface and its overlay controls, in the style of Flow's
/// player: controls fade away while the video plays, come back on a
/// pointer move, and the seek bar carries chapter markers.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/presentation/widgets/annotated_line.dart';
import 'package:lang/utils/chapter_parser.dart';

import 'player_time.dart';

/// One chapter marker drawn on the seek bar.
class SeekBarChapter {
  const SeekBarChapter({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

/// The video picture with its controls layered on top.
///
/// The controls hide themselves a moment after playback starts and come
/// back when the pointer moves over the surface, the way a native
/// player does. Tapping the picture toggles them.
class VideoPlayerSurface extends StatefulWidget {
  const VideoPlayerSurface({
    super.key,
    required this.controller,
    required this.appState,
    this.activeCue,
    this.subtitleScale = 1.0,
    this.chapters = const [],
    this.onTogglePlay,
    this.onSeek,
    this.onSelectChapter,
    this.trailingControls = const [],
    this.leadingControls = const [],
    this.showControls = true,
  });

  final VideoPlayerController controller;

  /// Settings that decide how the subtitle over the picture is
  /// annotated (furigana / pinyin).
  final AppState appState;

  /// The subtitle cue to draw over the picture, if any.
  final String? activeCue;

  /// Multiplier applied to the subtitle size.
  final double subtitleScale;

  /// Chapter markers drawn on the seek bar.
  final List<YouTubeChapter> chapters;

  final VoidCallback? onTogglePlay;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<YouTubeChapter>? onSelectChapter;

  /// Controls shown at the end of the control bar.
  final List<Widget> trailingControls;

  /// Controls shown at the start of the control bar.
  final List<Widget> leadingControls;

  /// Whether the controls are pinned open regardless of playback state.
  final bool showControls;

  @override
  State<VideoPlayerSurface> createState() => _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends State<VideoPlayerSurface> {
  /// How long the controls stay up after the last interaction.
  static const _hideDelay = Duration(seconds: 3);

  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _scrubbing = false;

  /// The position the user is dragging to; null while not scrubbing.
  Duration? _scrubPosition;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(VideoPlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (widget.showControls && !_controlsVisible) {
      _showControls();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  /// Hide the controls once playback starts, so the picture is clean.
  void _onControllerChanged() {
    final playing = widget.controller.value.isPlaying;
    if (playing && _controlsVisible && !_scrubbing) {
      _scheduleHide();
    } else if (!playing && !_controlsVisible) {
      _showControls();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted || _scrubbing) return;
      if (widget.controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return MouseRegion(
      onHover: (_) => _showControls(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            if (widget.activeCue != null && widget.activeCue!.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 64,
                child: _SubtitleOverlay(
                  text: widget.activeCue!,
                  scale: widget.subtitleScale,
                  appState: widget.appState,
                ),
              ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _ControlBar(
                  controller: controller,
                  chapters: widget.chapters,
                  scrubbing: _scrubbing,
                  scrubPosition: _scrubPosition,
                  onTogglePlay: widget.onTogglePlay,
                  onSeek: widget.onSeek,
                  onSelectChapter: widget.onSelectChapter,
                  leading: widget.leadingControls,
                  trailing: widget.trailingControls,
                  onScrubStart: () {
                    setState(() {
                      _scrubbing = true;
                      _scrubPosition = controller.value.position;
                    });
                    _hideTimer?.cancel();
                  },
                  onScrubUpdate: (position) {
                    setState(() => _scrubPosition = position);
                  },
                  onScrubEnd: (position) {
                    setState(() {
                      _scrubbing = false;
                      _scrubPosition = null;
                    });
                    widget.onSeek?.call(position);
                    _scheduleHide();
                  },
                ),
              ),
            ),
            if (!_controlsVisible)
              const SizedBox.shrink()
            else
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopGradient(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The subtitle text drawn over the picture.
///
/// Furigana or pinyin is drawn above the base text when the user's
/// reading style asks for it, so Japanese and Chinese subtitles read
/// the same way as in the transcript pane. The base text stays white
/// on the picture; the learning-state colouring of the reader surfaces
/// would be unreadable here.
class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({
    required this.text,
    required this.scale,
    required this.appState,
  });

  final String text;
  final double scale;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 14 * scale,
      height: 1.4,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
    final annotated = appState.readingStyle != 'off';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(6),
        ),
        child: annotated
            ? AnnotatedLine(
                text: text,
                appState: appState,
                fontSize: 14 * scale,
                weight: FontWeight.normal,
                baseStyle: baseStyle,
                textAlign: TextAlign.center,
              )
            : Text(text, textAlign: TextAlign.center, style: baseStyle),
      ),
    );
  }
}

/// A dark gradient at the top of the picture, so overlaid controls stay
/// readable over bright footage.
class _TopGradient extends StatelessWidget {
  const _TopGradient();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.black.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The control bar: play button, seek bar with chapter markers, the
/// time readout and the caller's extra controls.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.controller,
    required this.chapters,
    required this.scrubbing,
    required this.scrubPosition,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    this.onTogglePlay,
    this.onSeek,
    this.onSelectChapter,
    this.leading = const [],
    this.trailing = const [],
  });

  final VideoPlayerController controller;
  final List<YouTubeChapter> chapters;
  final bool scrubbing;
  final Duration? scrubPosition;
  final VoidCallback? onTogglePlay;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<YouTubeChapter>? onSelectChapter;
  final List<Widget> leading;
  final List<Widget> trailing;
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubUpdate;
  final ValueChanged<Duration> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final position = scrubbing && scrubPosition != null
        ? scrubPosition!
        : value.position;
    final duration = value.duration;
    final totalMs = duration.inMilliseconds;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.black.withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChapterSeekBar(
              controller: controller,
              chapters: chapters,
              totalMs: totalMs,
              scrubbing: scrubbing,
              onScrubStart: onScrubStart,
              onScrubUpdate: onScrubUpdate,
              onScrubEnd: onScrubEnd,
              onSelectChapter: onSelectChapter,
            ),
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  iconSize: 28,
                  tooltip: '',
                  icon: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: onTogglePlay,
                ),
                const SizedBox(width: 4),
                Text(
                  formatPlayerTime(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(
                  ' / ',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  formatPlayerTime(duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                ...leading,
                ...trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }

}

/// The seek bar, with the chapter boundaries drawn on it.
class _ChapterSeekBar extends StatefulWidget {
  const _ChapterSeekBar({
    required this.controller,
    required this.chapters,
    required this.totalMs,
    required this.scrubbing,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    this.onSelectChapter,
  });

  final VideoPlayerController controller;
  final List<YouTubeChapter> chapters;
  final int totalMs;
  final bool scrubbing;
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubUpdate;
  final ValueChanged<Duration> onScrubEnd;
  final ValueChanged<YouTubeChapter>? onSelectChapter;

  @override
  State<_ChapterSeekBar> createState() => _ChapterSeekBarState();
}

class _ChapterSeekBarState extends State<_ChapterSeekBar> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final totalMs = widget.totalMs;
    final positionMs = value.position.inMilliseconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final playedFraction = totalMs <= 0
            ? 0.0
            : (positionMs / totalMs).clamp(0.0, 1.0);
        final dragFraction = _dragFraction;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            widget.onScrubStart();
            _updateDrag(details.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (details) {
            _updateDrag(details.localPosition.dx, width);
          },
          onHorizontalDragEnd: (_) {
            final fraction = _dragFraction;
            _dragFraction = null;
            if (fraction != null) {
              widget.onScrubEnd(
                Duration(milliseconds: (fraction * totalMs).round()),
              );
            }
          },
          onTapDown: (details) {
            final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onScrubEnd(Duration(milliseconds: (fraction * totalMs).round()));
          },
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: dragFraction ?? playedFraction,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // chapter boundaries
                for (final chapter in widget.chapters)
                  if (totalMs > 0)
                    Positioned(
                      left: width * (chapter.start.inMilliseconds / totalMs) - 1,
                      child: GestureDetector(
                        onTap: () => widget.onSelectChapter?.call(chapter),
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                if (dragFraction != null)
                  Positioned(
                    left: width * dragFraction - 6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateDrag(double dx, double width) {
    if (width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
    widget.onScrubUpdate(
      Duration(milliseconds: (fraction * widget.totalMs).round()),
    );
  }
}
