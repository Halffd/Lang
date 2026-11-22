/// Time formatting shared by the player's controls and side pane.
///
/// The format matches what YouTube and Flow show: `m:ss` for a short
/// video, `h:mm:ss` once it passes an hour, and the minutes are not
/// zero-padded so a chapter at the start reads `0:00` rather than
/// `00:00`.
library;

/// Format [d] as a playback time: `m:ss`, or `h:mm:ss` past an hour.
String formatPlayerTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
