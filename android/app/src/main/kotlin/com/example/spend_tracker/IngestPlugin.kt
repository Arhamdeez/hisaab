package com.example.spend_tracker

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

private const val INGEST_TAG = "HisaabIngest"

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
        private val mainHandler = Handler(Looper.getMainLooper())

        private val excludedPackagePrefixes = listOf(
            "com.android.systemui",
            "com.android.settings",
            "com.android.vending",
            "com.google.android.apps.messaging",
            "com.google.android.gm",
            "com.google.android.youtube",
            "com.samsung.android.messaging",
            "com.facebook.",
            "com.instagram.",
            "com.twitter.",
            "com.zhiliaoapp.musically",
        )

        private val monitoredPackages = setOf(
            // Google Pay / Wallet
            "com.google.android.apps.nbu.paisa.user",
            "com.google.android.apps.nbu.paisa",
            "com.google.android.apps.walletnfcrel",
            "com.google.commerce.tapandpay",
            // India UPI & wallets
            "com.phonepe.app",
            "net.one97.paytm",
            "in.org.npci.upiapp",
            "com.dreamplug.androidapp",
            "com.whatsapp",
            "com.amazon.mShop.android.shopping",
            // India banks
            "com.csam.icici.bank.imobile",
            "com.sbi.lotusintouch",
            "com.sbi.SBIFreedomPlus",
            "com.axis.mobile",
            "com.hdfcbank.android.now",
            "com.snapwork.hdfc",
            "com.bankofbaroda.mconnect",
            "com.fss.pnbpsp",
            "com.kotak.mobile",
            "com.konylabs.cbplpat",
            "com.YES.YESbank",
            "com.idbibank.mpassbook",
            "com.infrasofttech.indianbank",
            "com.canarabank.mobility",
            "com.rblbank.mobbanking",
            "com.indusind.mobilebanking",
            "com.federalbank.mobile",
            "com.unionbankofindia.mobilebanking",
            "com.centralbank.mobile",
            // Global wallets
            "com.paypal.android.p2pmobile",
            "com.squareup.cash",
            "com.venmo",
            "com.revolut.revolut",
            "com.transferwise.android",
            "com.wise.android",
            "com.samsung.android.spay",
            "com.samsung.android.spaylite",
            "com.chase.sig.android",
            "com.wf.wellsfargomobile",
            "com.bankofamerica.cashpromobile",
            "com.citi.citimobile",
            "com.usabank.mobilebanking",
            "com.capitalone.mobile",
            "com.starlingbank.android",
            "com.monzo",
            "com.n26",
            // Pakistan banks & wallets
            "app.com.brd",
            "com.ubluk.dc",
            "com.techlogix.mobilinkcustomer",
            "pk.com.telenor.phoenix",
            "com.sadaPay.sadaPay",
            "com.sadapay.app",
            "com.nayapay.app",
            "com.hbl.android.hblmobilebanking",
            "com.mcb.mobile",
            "com.mcb.mobilebanking",
            "com.bankalfalah",
            "com.alfalah.mobile",
            "com.meezanbank.mobile",
            "com.faysalbank.mobile",
            "com.sc.mobilebanking.pk",
            "com.askari.mobile",
            "com.standardchartered.mobile",
            "com.bop.mobilebanking",
        )

        private val monitoredKeywords = listOf(
            "bank", "banking", "wallet", "walletnfcrel", "upi", "finance",
            "financial", "mobilebank", "passbook", "paisa", "gpay", "tapandpay",
            "nfc", "paytm", "phonepe", "bhim", "hdfc", "icici", "sbi", "axis",
            "kotak", "yesbank", "idbi", "pnb", "baroda", "canara", "rbl",
            "indus", "federal", "razorpay", "payu", "mobikwik", "freecharge",
            "cred", "paypal", "venmo", "cashapp", "squareup", "revolut",
            "transferwise", "stripe", "remit", "remittance", "spay", "ubl",
            "brd", "jazzcash", "mobilink", "easypaisa", "sadapay", "nayapay",
            "alfalah", "hbl", "mcb", "meezan", "faysal", "chase", "wellsfargo",
            "citibank", "citi", "monzo", "starling",
        )

        private val recentAmountAlerts = LinkedHashMap<String, Pair<Long, String>>()

        private fun amountKey(pkg: String, text: String): String? {
            val amountMatch = amountRegex.find(text)?.value ?: return null
            val normalized = amountMatch.replace("\\s".toRegex(), "").lowercase()
            return "$pkg:$normalized"
        }

        fun shouldDeliverNow(pkg: String, text: String): Boolean {
            val now = System.currentTimeMillis()
            val aKey = amountKey(pkg, text) ?: return true
            val normalized = text.replace("\\s+".toRegex(), " ").trim().lowercase()
            synchronized(recentAmountAlerts) {
                val prev = recentAmountAlerts[aKey]
                if (prev != null && now - prev.first < DEDUP_MS) {
                    val prevNorm =
                        prev.second.replace("\\s+".toRegex(), " ").trim().lowercase()
                    when {
                        normalized == prevNorm -> {
                            Log.d(INGEST_TAG, "  deduped identical alert for $aKey")
                            return false
                        }
                        normalized.length < prevNorm.length &&
                            prevNorm.contains(normalized) -> {
                            Log.d(
                                INGEST_TAG,
                                "  deduped shorter subset alert for $aKey",
                            )
                            return false
                        }
                    }
                    // Richer or materially different text for the same amount — deliver.
                }
                recentAmountAlerts[aKey] = now to text
                while (recentAmountAlerts.size > 200) {
                    val oldest = recentAmountAlerts.keys.first()
                    recentAmountAlerts.remove(oldest)
                }
            }
            return true
        }

        private const val DEDUP_MS = 15000L

        private val amountRegex = Regex(
            "(?:rs\\.?|pkr|inr|₹|₨|usd|eur|gbp|aed|sar|cad|aud|\\$|€|£)\\s*[\\d,]+(?:\\.\\d+)?|" +
                "[\\d,]+(?:\\.\\d+)?\\s*(?:rs\\.?|pkr|inr|₹|₨|usd|eur|gbp|aed|sar|cad|aud)",
            RegexOption.IGNORE_CASE,
        )

        /** Samsung / PK wallets sometimes post amount + trx id only — match Dart parser. */
        private val monitoredWalletFallbackRegex = Regex(
            "a/c|account|\\*\\*\\*|trx\\s*id|trans(?:action)?\\s*id",
            RegexOption.IGNORE_CASE,
        )

        /** Signals real money movement — aligned with Dart [TransactionParser]. */
        private val walletTxnRegex = Regex(
            "debited|credited|spent|withdrawn|deducted|transferred|received|" +
                "paid|sent|purchase|txn|transaction|debit|credit|refund|" +
                "cashback|deposited|salary|transfer|withdrawal|" +
                "payment|charged|bill|added|" +
                "money\\s+received|money\\s+sent|payment\\s+received|" +
                "transfer\\s*successful|successfully\\s*transferred|" +
                "sent\\s*(?:rs|pkr)|received\\s*(?:rs|pkr)|" +
                "a/c\\s*\\*+|account\\s*\\*+|trx\\s*id|trans(?:action)?\\s*id|" +
                "has\\s*been\\s*(?:debited|credited|deducted)",
            RegexOption.IGNORE_CASE,
        )

        fun deliver(context: Context, event: Map<String, Any?>) {
            // NotificationListener callbacks are not always on the main thread;
            // EventChannel requires the UI thread or events are silently dropped.
            mainHandler.post {
                val sink = eventSink
                if (sink != null) {
                    try {
                        Log.d(
                            INGEST_TAG,
                            "deliver -> live sink: ${(event["text"] as? String)?.take(80)}",
                        )
                        sink.success(event)
                    } catch (e: Exception) {
                        Log.w(INGEST_TAG, "live sink failed, queueing", e)
                        CapturedEventStore.enqueue(context, event)
                    }
                } else {
                    Log.d(INGEST_TAG, "deliver -> durable queue (app not running)")
                    CapturedEventStore.enqueue(context, event)
                }
            }
        }

        /** Migrate legacy SharedPreferences buffer into the drain result once. */
        private fun drainLegacyPending(context: Context): List<Map<String, Any?>> {
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

        private fun dedupeEvents(events: List<Map<String, Any?>>): List<Map<String, Any?>> {
            val seen = LinkedHashSet<String>()
            val out = ArrayList<Map<String, Any?>>(events.size)
            for (event in events) {
                val text = event["text"] as? String ?: ""
                val source = event["source"] as? String ?: "notification"
                val ts = (event["timestamp"] as? Number)?.toLong() ?: 0L
                val key = "$source|$ts|${text.hashCode()}"
                if (seen.add(key)) out.add(event)
            }
            return out
        }

        fun isExcludedPackage(packageName: String): Boolean {
            val pkg = packageName.lowercase()
            return excludedPackagePrefixes.any { prefix ->
                pkg == prefix || pkg.startsWith(prefix)
            }
        }

        fun shouldMonitor(packageName: String): Boolean {
            if (isExcludedPackage(packageName)) return false
            val pkg = packageName.lowercase()
            return monitoredPackages.any { pkg.contains(it.lowercase()) } ||
                monitoredKeywords.any { pkg.contains(it) }
        }

        fun looksLikeTransaction(text: String): Boolean {
            if (!amountRegex.containsMatchIn(text)) return false
            if (walletTxnRegex.containsMatchIn(text)) return true
            return monitoredWalletFallbackRegex.containsMatchIn(text)
        }

        fun shouldCapture(packageName: String, text: String): Boolean {
            if (isExcludedPackage(packageName)) return false
            // Any app: capture when the text clearly looks like money movement.
            if (looksLikeTransaction(text)) return true
            // Bank / wallet / payment apps: amount-only bodies are common.
            if (shouldMonitor(packageName) && amountRegex.containsMatchIn(text)) {
                return true
            }
            // Title-only credit/debit alerts ("Money Received") before amount loads.
            if (shouldMonitor(packageName) && walletTxnRegex.containsMatchIn(text)) {
                return true
            }
            return false
        }

        /** True when native SQLite / legacy queues hold unprocessed captures. */
        fun hasPendingCaptures(context: Context): Boolean {
            return CapturedEventStore.pendingCount(context) > 0 ||
                legacyPendingCount(context) > 0
        }

        private fun legacyPendingCount(context: Context): Int {
            return try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val raw = prefs.getString(KEY_PENDING, "[]") ?: "[]"
                JSONArray(raw).length()
            } catch (_: Exception) {
                0
            }
        }

        fun isNotificationAccessEnabled(context: Context): Boolean {
            val component = ComponentName(context, NotificationCaptureService::class.java)
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            return flat.split(":").any { entry ->
                val enabled = ComponentName.unflattenFromString(entry.trim())
                enabled != null &&
                    enabled.packageName == component.packageName &&
                    enabled.className == component.className
            }
        }

        /**
         * Shared capture path for live posts and the active-notification scan on connect.
         */
        fun processNotification(context: Context, sbn: StatusBarNotification) {
            val pkg = sbn.packageName ?: return
            if (pkg == context.packageName) return
            if (isExcludedPackage(pkg)) return

            val extras = sbn.notification.extras
            val text = extractNotificationText(extras)
            val title =
                extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""

            if (text.isBlank()) {
                if (shouldMonitor(pkg)) {
                    Log.d(INGEST_TAG, "empty text pkg=$pkg")
                }
                return
            }
            if (!shouldCapture(pkg, text)) {
                if (shouldMonitor(pkg)) {
                    Log.d(
                        INGEST_TAG,
                        "skip pkg=$pkg len=${text.length} preview=${text.take(100)}",
                    )
                }
                return
            }
            if (!shouldDeliverNow(pkg, text)) return

            Log.d(INGEST_TAG, "capture pkg=$pkg preview=${text.take(100)}")

            deliver(
                context,
                mapOf(
                    "source" to "notification",
                    "text" to text,
                    "package" to pkg,
                    "sender" to title,
                    "timestamp" to sbn.postTime,
                ),
            )
        }

        fun requestNotificationRebind(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
            try {
                NotificationListenerService.requestRebind(
                    ComponentName(context, NotificationCaptureService::class.java),
                )
                Log.d(INGEST_TAG, "requested notification listener rebind")
            } catch (e: Exception) {
                Log.w(INGEST_TAG, "rebind request failed", e)
            }
        }

        fun isIgnoringBatteryOptimizations(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }

        fun requestIgnoreBatteryOptimizations(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
            if (isIgnoringBatteryOptimizations(context)) return
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        /**
         * Pulls every human-readable line from a notification. Samsung and wallet
         * apps often stash the transaction body in non-standard extra keys.
         */
        fun extractNotificationText(extras: Bundle?): String {
            if (extras == null) return ""
            val parts = LinkedHashSet<String>()

            fun add(cs: CharSequence?) {
                val t = cs?.toString()?.trim()
                if (!t.isNullOrBlank()) parts.add(t)
            }

            add(extras.getCharSequence(Notification.EXTRA_TITLE))
            add(extras.getCharSequence(Notification.EXTRA_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_INFO_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))

            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach { add(it) }

            @Suppress("DEPRECATION")
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null) {
                for (parcelable in messages) {
                    if (parcelable is Bundle) {
                        add(parcelable.getCharSequence("text"))
                    }
                }
            }

            // Wallet apps often stash the body under custom or extra android.* keys.
            val skipKeys = setOf(
                "android.icon",
                "android.largeIcon",
                "android.picture",
                "android.progress",
                "android.progressMax",
                "android.progressIndeterminate",
                "android.appInfo",
                "android.colorized",
                "android.showWhen",
                "android.showChronometer",
                "android.chronometerCountDown",
                "android.reduced.images",
            )
            for (key in extras.keySet()) {
                if (key in skipKeys) continue
                when (val value = extras.get(key)) {
                    is CharSequence -> add(value)
                    is Array<*> -> {
                        for (item in value) {
                            when (item) {
                                is CharSequence -> add(item)
                                is Bundle -> {
                                    add(item.getCharSequence("text"))
                                    add(item.getCharSequence(Notification.EXTRA_TEXT))
                                    add(item.getCharSequence(Notification.EXTRA_BIG_TEXT))
                                }
                            }
                        }
                    }
                    is Bundle -> {
                        add(value.getCharSequence("text"))
                        add(value.getCharSequence(Notification.EXTRA_TEXT))
                        add(value.getCharSequence(Notification.EXTRA_BIG_TEXT))
                        add(value.getCharSequence(Notification.EXTRA_TITLE))
                    }
                }
            }

            return parts.joinToString(" — ")
        }
    }

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessEnabled" -> {
                        result.success(isNotificationAccessEnabled(context))
                    }
                    "openNotificationAccessSettings" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                        result.success(null)
                    }
                    "drainPending" -> {
                        val legacy = drainLegacyPending(context)
                        val queued = CapturedEventStore.drain(context)
                        result.success(dedupeEvents(legacy + queued))
                    }
                    "hasPendingCaptures" -> {
                        result.success(hasPendingCaptures(context))
                    }
                    "requestNotificationRebind" -> {
                        requestNotificationRebind(context)
                        result.success(null)
                    }
                    "startKeepAlive" -> {
                        IngestKeepAliveService.start(context)
                        result.success(null)
                    }
                    "stopKeepAlive" -> {
                        IngestKeepAliveService.stop(context)
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations(context))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(INGEST_TAG, "Flutter event sink attached")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(INGEST_TAG, "Flutter event sink detached")
                    eventSink = null
                }
            })
    }
}

class NotificationCaptureService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(INGEST_TAG, "NotificationListener CONNECTED")
        // Catch wallet alerts already sitting in the shade when the listener binds.
        Handler(Looper.getMainLooper()).post {
            try {
                activeNotifications?.forEach { sbn ->
                    IngestPlugin.processNotification(applicationContext, sbn)
                }
            } catch (e: Exception) {
                Log.w(INGEST_TAG, "active notification scan failed", e)
            }
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(INGEST_TAG, "NotificationListener DISCONNECTED — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, NotificationCaptureService::class.java))
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        IngestPlugin.processNotification(applicationContext, sbn)
    }
}
