package com.example.spend_tracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Telephony
import androidx.core.content.ContextCompat
import java.util.concurrent.ConcurrentHashMap

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return

        // Concatenate multipart segments delivered in the same intent.
        val grouped = linkedMapOf<String, StringBuilder>()
        val timestamps = mutableMapOf<String, Long>()
        for (sms in messages) {
            val sender = sms.originatingAddress?.trim() ?: continue
            val segment = sms.messageBody ?: continue
            grouped.getOrPut(sender) { StringBuilder() }.append(segment)
            val ts = sms.timestampMillis
            val prev = timestamps[sender]
            if (prev == null || ts > prev) timestamps[sender] = ts
        }

        for ((sender, bodyBuilder) in grouped) {
            val segment = bodyBuilder.toString()
            if (segment.isBlank()) continue
            val timestamp = timestamps[sender] ?: System.currentTimeMillis()
            SmsAssemblyBuffer.append(context.applicationContext, sender, segment, timestamp)
        }
    }

    /** Buffers rapid back-to-back segments from the same short code into one SMS body. */
    private object SmsAssemblyBuffer {
        private const val ASSEMBLE_DELAY_MS = 900L
        private const val STALE_BUFFER_MS = 4000L

        private data class PendingSms(
            val parts: StringBuilder = StringBuilder(),
            var timestamp: Long = 0L,
            var lastUpdate: Long = 0L,
        )

        private val pending = ConcurrentHashMap<String, PendingSms>()
        private val flushTokens = ConcurrentHashMap<String, Runnable>()
        private val handler = Handler(Looper.getMainLooper())

        fun append(context: Context, sender: String, segment: String, timestamp: Long) {
            val now = SystemClock.elapsedRealtime()
            pending.compute(sender) { _, existing ->
                if (existing != null && now - existing.lastUpdate > STALE_BUFFER_MS) {
                    PendingSms(StringBuilder(segment), timestamp, now)
                } else {
                    (existing ?: PendingSms(timestamp = timestamp, lastUpdate = now)).apply {
                        parts.append(segment)
                        this.timestamp = timestamp
                        lastUpdate = now
                    }
                }
            }

            flushTokens.remove(sender)?.let { handler.removeCallbacks(it) }
            val runnable = Runnable {
                flushTokens.remove(sender)
                val assembled = pending.remove(sender) ?: return@Runnable
                val body = assembled.parts.toString()
                if (body.isBlank()) return@Runnable
                if (!IngestPlugin.isLikelySmsTransaction(sender, body)) return@Runnable
                android.util.Log.i(
                    "HisaabIngest",
                    "sms capture from $sender preview=${body.take(80)}",
                )
                IngestPlugin.deliver(
                    context,
                    mapOf(
                        "source" to "sms",
                        "text" to body,
                        "sender" to sender,
                        "timestamp" to assembled.timestamp,
                    ),
                )
            }
            flushTokens[sender] = runnable
            handler.postDelayed(runnable, ASSEMBLE_DELAY_MS)
        }
    }
}
