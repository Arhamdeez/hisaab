package com.arham.hisaab

import android.view.HapticFeedbackConstants
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Soft scrub/slide ticks for splash bubble, etc.
 *
 * Uses [View.performHapticFeedback] (same path as Flutter's [HapticFeedback])
 * instead of [android.os.Vibrator] compositions — those can starve or mute
 * subsequent touch haptics on Samsung / Android 16.
 */
object SlideHapticsPlugin {
    private const val CHANNEL = "com.arham.hisaab/slide_haptics"

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "slideTick" -> {
                    val intensity = (call.argument<Double>("intensity") ?: 0.3)
                    slideTick(intensity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun slideTick(intensity: Double) {
        val view: View = ForegroundActivity.activity?.window?.decorView ?: return
        // CLOCK_TICK is the light continuous scrub primitive Flutter uses for
        // selectionClick. CONTEXT_CLICK is a hair stronger for mid-slide.
        val feedback = if (intensity >= 0.32) {
            HapticFeedbackConstants.CONTEXT_CLICK
        } else {
            HapticFeedbackConstants.CLOCK_TICK
        }
        view.performHapticFeedback(feedback)
    }
}
