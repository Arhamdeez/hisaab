package com.arham.hisaab

import android.util.Log

/**
 * Debug-only logging — release builds must not write payment alert bodies to logcat.
 */
object PrivacyLog {
    private val enabled: Boolean
        get() = BuildConfig.DEBUG

    fun d(tag: String, message: String) {
        if (enabled) Log.d(tag, message)
    }

    fun i(tag: String, message: String) {
        if (enabled) Log.i(tag, message)
    }

    fun w(tag: String, message: String, error: Throwable? = null) {
        if (!enabled) return
        if (error != null) Log.w(tag, message, error) else Log.w(tag, message)
    }

    fun e(tag: String, message: String, error: Throwable? = null) {
        if (error != null) Log.e(tag, message, error) else Log.e(tag, message)
    }

    fun captureQueued(tag: String, source: String, length: Int) {
        d(tag, "queued capture source=$source len=$length")
    }

    fun captureLive(tag: String, source: String, pkg: String?) {
        d(tag, "capture source=$source pkg=${pkg ?: "-"}")
    }
}
