import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:lang/core/services/app_storage.dart';

/// Renders a screenshot image from a storage ref — file path or SQLite
/// blob — via [AppStorage.readMedia]. Decode size is capped so grids do
/// not blow up RAM.
class ScreenshotRefImage extends StatefulWidget {
  final String ref;
  final BoxFit fit;
  final int? cacheWidth;

  /// The size of the rendered image. Null means the widget takes the
  /// size its parent offers.
  final double? size;

  const ScreenshotRefImage({
    super.key,
    required this.ref,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.size,
  });

  @override
  State<ScreenshotRefImage> createState() => _ScreenshotRefImageState();
}

class _ScreenshotRefImageState extends State<ScreenshotRefImage> {
  /// The bytes of the current ref. Reading it again on every build
  /// would restart the read on each frame and never settle.
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = AppStorage.readMedia(widget.ref);
  }

  @override
  void didUpdateWidget(ScreenshotRefImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref) {
      _bytes = AppStorage.readMedia(widget.ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget box(Widget child) {
      if (widget.size == null) return child;
      return SizedBox(width: widget.size, height: widget.size, child: child);
    }

    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return box(
            const ColoredBox(
              color: Colors.black12,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return box(
            const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image)),
            ),
          );
        }
        return box(
          Image.memory(
            bytes,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image)),
            ),
          ),
        );
      },
    );
  }
}
