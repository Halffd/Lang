import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks a subtree as UI chrome that the popup dictionary must not scan.
///
/// The global popup dictionary hit-tests the render tree for text under
/// the pointer; without this, hovering the app's own localized labels
/// ("分析", "検索", button captions) triggers lookups. Wrap chrome
/// (app bars, navigation, control rows) in this widget: its render
/// object inserts itself into the hit-test path, which
/// [CjkTextExtractor] treats as a stop sign.
class PopupScanBlocker extends SingleChildRenderObjectWidget {
  const PopupScanBlocker({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPopupScanBlocker();
}

/// Render object that records its presence in the hit-test path.
class RenderPopupScanBlocker extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final hit = hitTestChildren(result, position: position);
    if (hit) {
      // children come first in the path; adding self here places the
      // blocker between the text and the root, where the extractor
      // walks for stop signs
      result.add(BoxHitTestEntry(this, position));
    }
    return hit;
  }
}
