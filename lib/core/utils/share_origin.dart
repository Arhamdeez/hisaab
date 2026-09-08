import 'package:flutter/material.dart';

/// Anchor rect for iOS/iPad share popovers. Returns null if the widget
/// has not been laid out yet.
Rect? shareOriginFrom(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  var rect = origin & box.size;
  if (rect.width < 1 || rect.height < 1) {
    rect = Rect.fromLTWH(origin.dx, origin.dy, 1, 1);
  }
  return rect;
}
