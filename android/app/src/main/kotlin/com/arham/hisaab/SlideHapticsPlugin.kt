package com.arham.hisaab

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Soft continuous haptics for scrub/slide gestures (splash bubble, etc.).
 * Uses Android composition primitives (LOW_TICK / TICK) — not a phone buzz.
 */
object SlideHapticsPlugin {
    private const val CHANNEL = "com.arham.hisaab/slide_haptics"

    fun register(context: Context, flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "slideTick" -> {
                    val intensity = (call.argument<Double>("intensity") ?: 0.3).toFloat()
                    slideTick(context, intensity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
    }

    private fun slideTick(context: Context, intensity: Float) {
        val vibrator = vibrator(context) ?: return
        if (!vibrator.hasVibrator()) return

        val amp = intensity.coerceIn(0.1f, 0.5f)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val primitive = preferredPrimitive(vibrator)
                vibrator.vibrate(
                    VibrationEffect.startComposition()
                        .addPrimitive(primitive, amp)
                        .compose(),
                )
                return
            } catch (_: Throwable) {
                // Fall through to one-shot.
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val strength = (amp * 72f).toInt().coerceIn(1, 72)
            vibrator.vibrate(VibrationEffect.createOneShot(7L, strength))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(7L)
        }
    }

    private fun preferredPrimitive(vibrator: Vibrator): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val low = VibrationEffect.Composition.PRIMITIVE_LOW_TICK
            if (vibrator.areAllPrimitivesSupported(low)) return low
        }
        return VibrationEffect.Composition.PRIMITIVE_TICK
    }
}
