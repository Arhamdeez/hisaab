package com.example.spend_tracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class IngestPlugin(
    private val context: Context,
    flutterEngine: FlutterEngine,
) {
    companion object {
        const val METHOD_CHANNEL = "com.example.spend_tracker/ingest_control"
        const val EVENT_CHANNEL = "com.example.spend_tracker/ingest"

        private const val PREFS = "spend_tracker_ingest"
        private const val KEY_PENDING = "pending_events"
        private const val MAX_PENDING = 500

        private var eventSink: EventChannel.EventSink? = null

        // Known bank / UPI / wallet apps. The substring checks below also catch
        // most banking apps whose package id embeds an obvious keyword.
        private val monitoredPackages = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                        // PhonePe
            "net.one97.paytm",                        // Paytm
            "in.org.npci.upiapp",                     // BHIM
            "com.dreamplug.androidapp",               // CRED
            "com.csam.icici.bank.imobile",            // ICICI iMobile
            "com.sbi.lotusintouch",                   // SBI YONO
            "com.sbi.SBIFreedomPlus",                 // SBI
            "com.axis.mobile",                        // Axis
            "com.hdfcbank.android.now",               // HDFC
            "com.snapwork.hdfc",                      // HDFC
            "com.bankofbaroda.mconnect",              // BoB
            "com.fss.pnbpsp",                         // PNB
            "com.kotak.mobile",                       // Kotak
            "com.konylabs.cbplpat",                   // Kotak 811
            "com.YES.YESbank",                        // YES
            "com.idbibank.mpassbook",                 // IDBI
            "com.infrasofttech.indianbank",           // Indian Bank
            "com.amazon.mShop.android.shopping",      // Amazon (Amazon Pay)
            "com.whatsapp",                           // WhatsApp Pay
        )

        // Lower-cased substrings that strongly suggest a banking / payments app.
        private val monitoredKeywords = listOf(
            "bank", "upi", "pay", "wallet", "card", "paytm", "phonepe",
            "bhim", "gpay", "hdfc", "icici", "sbi", "axis", "kotak",
            "yesbank", "idbi", "pnb", "baroda", "canara", "rbl", "indus",
            "federal", "paisa", "razorpay", "payu", "mobikwik", "freecharge",
            "cred", "finance",
        )

        fun emit(event: Map<String, Any?>) {
            eventSink?.success(event)
        }

        /**
         * Deliver an ingest event. When the Flutter side is listening it goes
         * straight through; otherwise (app closed / engine not attached) it is
         * persisted so it can be drained on the next launch — so transactions
         * captured in the background are never lost.
         */
        fun deliver(context: Context, event: Map<String, Any?>) {
            val sink = eventSink
            if (sink != null) {
                sink.success(event)
            } else {
                persist(context, event)
            }
        }

        private fun persist(context: Context, event: Map<String, Any?>) {
            try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val arr = JSONArray(prefs.getString(KEY_PENDING, "[]"))
                val obj = JSONObject()
                for ((k, v) in event) obj.put(k, v ?: JSONObject.NULL)
                arr.put(obj)
                // Guard against unbounded growth if the app is never reopened.
                while (arr.length() > MAX_PENDING) arr.remove(0)
                prefs.edit().putString(KEY_PENDING, arr.toString()).apply()
            } catch (_: Exception) {
                // Never crash a system callback over a buffering failure.
            }
        }

        private fun drainPending(context: Context): List<Map<String, Any?>> {
            return try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val raw = prefs.getString(KEY_PENDING, "[]") ?: "[]"
                prefs.edit().remove(KEY_PENDING).apply()
                val arr = JSONArray(raw)
                val out = ArrayList<Map<String, Any?>>(arr.length())
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    out.add(
                        mapOf(
                            "source" to o.optString("source", "notification"),
                            "text" to o.optString("text", ""),
                            "package" to o.optString("package", ""),
                            "sender" to o.optString("sender", ""),
                            "timestamp" to o.optLong(
                                "timestamp",
                                System.currentTimeMillis(),
                            ),
                        ),
                    )
                }
                out
            } catch (_: Exception) {
                emptyList()
            }
        }

        fun shouldMonitor(packageName: String): Boolean {
            val pkg = packageName.lowercase()
            return monitoredPackages.any { pkg.contains(it.lowercase()) } ||
                monitoredKeywords.any { pkg.contains(it) }
        }

        // A money amount: Rs/PKR/INR/₹/₨ next to a number, in either order.
        private val amountRegex = Regex(
            "(?:rs\\.?|pkr|inr|₹|₨)\\s*[\\d,]+(?:\\.\\d+)?|" +
                "[\\d,]+(?:\\.\\d+)?\\s*(?:rs\\.?|pkr|inr|₹|₨)",
            RegexOption.IGNORE_CASE,
        )

        // A word signalling actual money movement (not a promo / price tag).
        private val movementRegex = Regex(
            "debited|credited|spent|withdrawn|deducted|transferred|received|" +
                "paid|sent|purchase|txn|transaction|debit|credit|refund|" +
                "cashback|deposited|salary",
            RegexOption.IGNORE_CASE,
        )

        /**
         * True when a notification body looks like a real transaction from any
         * app — it contains both a money amount and a movement keyword. Lets us
         * capture from payment apps that aren't in the explicit allowlist.
         */
        fun looksLikeTransaction(text: String): Boolean {
            return amountRegex.containsMatchIn(text) &&
                movementRegex.containsMatchIn(text)
        }
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessEnabled" -> {
                        result.success(isNotificationAccessEnabled())
                    }
                    "openNotificationAccessSettings" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
                        result.success(null)
                    }
                    "drainPending" -> {
                        result.success(drainPending(context))
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val component = ComponentName(context, NotificationCaptureService::class.java)
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return flat.split(":").any { it.contains(component.flattenToString()) }
    }
}

class NotificationCaptureService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return

        // Ignore our own notifications outright.
        if (pkg == applicationContext.packageName) return

        val extras = sbn.notification.extras
        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val body = extras?.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras?.getCharSequence("android.bigText")?.toString() ?: ""
        // Prefer the expanded body text when present (carries the full message).
        val content = if (bigText.isNotBlank()) bigText else body
        val text = listOf(title, content)
            .filter { it.isNotBlank() }
            .joinToString(" — ")
        if (text.isBlank()) return

        // Capture from known payment apps, OR from any app whose notification
        // clearly describes a transaction (amount + movement keyword).
        val monitored = IngestPlugin.shouldMonitor(pkg)
        if (!monitored && !IngestPlugin.looksLikeTransaction(text)) return

        IngestPlugin.deliver(
            applicationContext,
            mapOf(
                "source" to "notification",
                "text" to text,
                "package" to pkg,
                "timestamp" to sbn.postTime,
            ),
        )
    }
}
