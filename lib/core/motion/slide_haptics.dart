import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Soft scrub/slide haptics — dense low ticks that feel like dragging, not a buzz.
class SlideHaptics {
  SlideHaptics._();

  static const _channel = MethodChannel('com.arham.hisaab/slide_haptics');

  /// [intensity] 0–1; keep low (≈0.15–0.4) for a subtle slide.
  static Future<void> slideTick({double intensity = 0.28}) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('slideTick', {
          'intensity': intensity.clamp(0.0, 1.0),
        });
        return;
      } catch (_) {
        // Fall through to Flutter haptic.
      }
    }
    await HapticFeedback.selectionClick();
  }
}
