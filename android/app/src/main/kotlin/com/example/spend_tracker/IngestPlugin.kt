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
            "com.android.chrome",
            "com.google.android.apps.messaging",
            "com.google.android.youtube",
            "com.google.android.dialer",
            "com.google.android.apps.maps",
            "com.google.android.calendar",
            "com.samsung.android.messaging",
            "com.samsung.android.app.health",
            "com.facebook.",
            "com.instagram.",
            "com.twitter.",
            "com.zhiliaoapp.musically",
            "com.spotify.",
            "com.netflix.",
            "com.discord",
            "com.snapchat.",
            "com.reddit.",
            "com.linkedin.",
            "com.careem.",
            "in.swiggy.",
            "com.application.zomato",
            "com.foodpanda.",
            "com.flipkart.",
            "com.miui.home",
        )

        private val emailClientPrefixes = listOf(
            "com.google.android.gm",
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
            "com.raqamidigital.cbt",
            "com.bopdigital.bop",
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
            "citibank", "citi", "monzo", "starling", "raqami", "raqamidigital",
            "telenor", "phoenix", ".pk",
            "fintech", "ewallet", "zelle", "wise", "mpesa", "momo",
        )

        /** Non-finance alerts that often contain numbers. */
        private val noiseNotificationRegex = Regex(
            "\\b(?:otp|one[\\s-]?time\\s+(?:password|pin|code)|verification\\s+code|" +
                "confirm(?:ation)?\\s+code|security\\s+code|passcode)\\b|" +
                "\\b(?:followers?|following|subscribers?|views?|likes?)\\b|" +
                "\\b(?:steps|calories|heart\\s+rate|km\\s+walked|workout)\\b|" +
                "\\b(?:battery|charging|charge\\s+complete)\\b|" +
                "\\b(?:update\\s+available|new\\s+version|downloading|install(?:ing|ed)|updating|" +
                "update\\s+(?:in\\s+progress|complete|failed|ready)|finishing\\s+update)\\b|" +
                "\\b(?:whatsapp\\s+update|backup(?:ping)?|backup\\s+in\\s+progress|restoring\\s+messages|" +
                "chat\\s+backup|uploading\\s*:|download(?:ing)?\\s*:)\\b|" +
                "\\b(?:out\\s+for\\s+delivery|order\\s+confirmed|your\\s+order\\s+#|" +
                "track(?:ing)?\\s+(?:your|order))\\b|" +
                "\\b(?:flash\\s+sale|limited\\s+offer|promo\\s+code|coupon|\\d+\\s*%\\s*off)\\b|" +
                "\\b(?:missed\\s+call|incoming\\s+call|voice\\s+mail)\\b|" +
                "\\b(?:weather|forecast|rain\\s+alert)\\b|" +
                "\\b(?:match\\s+score|full\\s+time)\\b|" +
                "\\b(?:get\\s+a\\s+chance|chance\\s+to\\s+win|win\\s+(?:\\d+|a\\s+|1\\s)|" +
                "(?:\\d+\\s+)?crore|(?:\\d+\\s+)?lakh|(?:\\d+\\s+)?lac)\\b|" +
                "\\bmaintain\\s+(?:rs\\.?|pkr)\\b|" +
                "\\b(?:refer(?:ral)?|invite\\s+(?:friends?|and\\s+earn))\\b|" +
                "\\b\\d+\\s*(?:mb|gb|kb|tb)\\s+of\\s+\\d+\\s*(?:mb|gb|kb|tb)\\b",
            RegexOption.IGNORE_CASE,
        )

        private val metadataSegmentRegex = Regex(
            "(?:android\\.(?:app|x)\\.|androidx\\.|Notification\\\$|NotificationCompat|" +
                "FCM-Notification|BigTextStyle|MessagingStyle|InboxStyle|" +
                "^com\\.[a-z0-9_.]+\\s*\$)",
            RegexOption.IGNORE_CASE,
        )

        /** Strong money-movement wording — required for unknown apps (with currency). */
        private val strongFinanceRegex = Regex(
            "debited|credited|withdrawn|deducted|spent|transferred|purchase|" +
                "(?:debited|deducted|withdrawn|credited)\\s+by\\s+(?:pkr|rs\\.?)|" +
                "fund\\s+transfer|funds?\\s+transfer|transfer\\s+to|transfer\\s+successful|" +
                "mobile\\s+wallet|wallet\\s+a/c|" +
                "money\\s+(?:received|sent)|payment\\s+(?:received|sent)|" +
                "you\\s+(?:sent|paid|received|transferred)|" +
                "(?:paid|sent|transferred)\\s+to\\b|" +
                "(?:paid|sent|transferred)\\s+(?:pkr|rs\\.?|inr|₹|₨|\\$|€|£)|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+sent\\s+to\\b|" +
                "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+with\\b|" +
                "you\\s+(?:have\\s+)?paid\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+at\\b|" +
                "(?:payment|transfer|transaction|remittance|payout)\\s+of\\s+" +
                "(?:pkr|rs\\.?|inr|₹|₨|\\$|€|£)|" +
                "amount\\s+of\\s+(?:pkr|rs\\.?)|money\\s+transfer\\s+of|" +
                "has\\s+been\\s+(?:debited|credited|sent|paid|transferred|received)|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+(?:has\\s+been|was)\\s+" +
                "(?:debited|credited|sent|paid|transferred|received)|" +
                "successfully\\s+sent\\s+to|transfer\\s*successful|successfully\\s*transferred|" +
                "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+with\\b|" +
                "you\\s+(?:have\\s+)?paid\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+at\\b|" +
                "(?:outgoing|incoming)\\s+(?:payment|transfer|transaction|money)|" +
                "a/c\\s*\\*+|account\\s*\\*+|trx\\s*id|trans(?:action)?\\s*id|" +
                "raast|ibft|1link|\\bupi\\b|\\bimps\\b|\\bneft\\b|\\brtgs\\b",
            RegexOption.IGNORE_CASE,
        )

        private val recentAmountAlerts = LinkedHashMap<String, Pair<Long, String>>()

        private fun amountKey(pkg: String, text: String): String? {
            val amountMatch = amountRegex.find(text)?.value
                ?: plainAmountRegex.find(text)?.value
                ?: return null
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
            "(?:rs\\.?|pkr|inr|₹|₨|rupees?|usd|eur|gbp|aed|sar|cad|aud|\\$|€|£)" +
                "\\s*[\\d,]+(?:\\.\\d+)?(?![kmb](?:\\b|/))\\s*/?-?|" +
                "[\\d,]+(?:\\.\\d+)?(?![kmb](?:\\b|/))\\s*/?-?\\s*(?:rs\\.?|pkr|inr|₹|₨|rupees?|usd|eur|gbp|aed|sar|cad|aud)",
            RegexOption.IGNORE_CASE,
        )

        /** PK wallets (NayaPay, JazzCash, …) often omit the currency label. */
        private val plainAmountRegex = Regex(
            "\\b([1-9]\\d{0,2}(?:,\\d{3})+(?:\\.\\d{1,2})?|[1-9]\\d{2,7}(?:\\.\\d{1,2})?)\\b",
        )

        fun hasFinanceAmount(text: String): Boolean {
            if (isInvalidAmountContext(text)) return false
            if (amountRegex.containsMatchIn(text)) return true
            val match = plainAmountRegex.find(text)?.groupValues?.getOrNull(1) ?: return false
            val value = match.replace(",", "").toDoubleOrNull() ?: return false
            return value >= 1.0
        }

        private fun isInvalidAmountContext(text: String): Boolean {
            if (Regex("\\b\\d+\\s*(?:mb|gb|kb|tb)\\s+of\\s+\\d+\\s*(?:mb|gb|kb|tb)\\b", RegexOption.IGNORE_CASE)
                    .containsMatchIn(text)) {
                return true
            }
            if (Regex("\\b(?:crore|lakh|lac|million|billion)\\b", RegexOption.IGNORE_CASE)
                    .containsMatchIn(text)) {
                return true
            }
            return false
        }

        fun sanitizeNotificationText(text: String): String {
            if (text.isBlank()) return ""
            return text.split(Regex("\\s*[—\\-|]\\s*"))
                .map { it.trim() }
                .filter { segment ->
                    segment.isNotEmpty() && !metadataSegmentRegex.containsMatchIn(segment)
                }
                .joinToString(" — ")
        }

        /** NayaPay casual alerts: "Rs. 500 sent to Inayat Hussain." */
        private val rsSentToRegex = Regex(
            "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+sent\\s+to\\b",
            RegexOption.IGNORE_CASE,
        )

        /** Google Wallet / tap-to-pay: "PKR330.00 with EP Digital Card …" */
        private val walletCardPaymentRegex = Regex(
            "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+with\\b",
            RegexOption.IGNORE_CASE,
        )

        /** EasyPaisa card SMS: "You have paid Rs. 330.00 at MERCHANT" */
        private val youPaidAtRegex = Regex(
            "you\\s+(?:have\\s+)?paid\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+at\\b",
            RegexOption.IGNORE_CASE,
        )

        private val txnSnippetRegex = Regex(
            "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+(?:sent\\s+to|with\\b)|" +
                "you\\s+(?:have\\s+)?paid\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?(?:\\s+at\\b)?",
            RegexOption.IGNORE_CASE,
        )

        /** Primary PK wallet triggers — "You sent Rs. 500" / "You received Rs. …" */
        private val youSentRsRegex = Regex(
            "you\\s+sent\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+",
            RegexOption.IGNORE_CASE,
        )

        private val youReceivedRsRegex = Regex(
            "you\\s+(?:have\\s+)?(?:received|got)\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+",
            RegexOption.IGNORE_CASE,
        )

        /** Easypaisa: "You have received Rs.1 in your Easypaisa account…" */
        private val receivedInAccountRegex = Regex(
            "you\\s+(?:have\\s+)?received\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+in\\s+your",
            RegexOption.IGNORE_CASE,
        )

        /** Easypaisa / Raast: "An amount of Rs. 1000.0 has been successfully sent…" */
        private val amountOfRsRegex = Regex(
            "(?:an\\s+)?amount\\s+of\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?",
            RegexOption.IGNORE_CASE,
        )

        /** Gmail e-statement: "Money Transfer of Rs. 1000.0 … was successful" */
        private val moneyTransferOfRsRegex = Regex(
            "money\\s+transfer\\s+of\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?",
            RegexOption.IGNORE_CASE,
        )

        /** High-confidence payment phrasing — capture from any app (incl. Gmail). */
        private val universalTxnRegex = Regex(
            "(?:payment|transfer|transaction|remittance|payout)\\s+of\\s+" +
                "(?:pkr|rs\\.?|inr|₹|₨|\\$|€|£|usd|eur|gbp)\\.?\\s*[\\d,]+(?:\\.\\d+)?|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+has\\s+been\\s+" +
                "(?:sent|debited|credited|deducted|withdrawn|paid|transferred|received)|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+was\\s+" +
                "(?:successfully\\s+)?(?:sent|paid|transferred|debited|credited|received|processed)|" +
                "you\\s+(?:have\\s+)?(?:paid|transferred|spent|withdrew)\\s+" +
                "(?:pkr|rs\\.?|inr|₹|₨|\\$|€|£)|" +
                "(?:outgoing|incoming)\\s+(?:payment|transfer|transaction|money)",
            RegexOption.IGNORE_CASE,
        )

        private val railsTxnRegex = Regex(
            "\\b(?:upi|imps|neft|rtgs|ibft|1link|raast|p2p|swift|ach)\\b",
            RegexOption.IGNORE_CASE,
        )

        private val raastTxnRegex = Regex(
            "raast|successfully\\s+sent\\s+to|transaction\\s+successful|" +
                "money\\s+transfer\\s+via|ibft|1link",
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
                "payment|charged|bill|added|successful|completed|processed|" +
                "money\\s+received|money\\s+sent|payment\\s+received|payment\\s+sent|" +
                "transfer\\s*successful|successfully\\s*transferred|" +
                "you\\s+sent|you\\s+paid|you\\s+transferred|sent\\s+to|paid\\s+to|" +
                "transfer\\s+to|transfer\\s+from|received\\s+from|" +
                "amount\\s+of\\s+(?:rs|pkr)|money\\s+transfer\\s+of|successfully\\s+sent|" +
                "(?:payment|transfer|transaction|remittance|payout)\\s+of\\s+(?:rs|pkr|inr|\\$|€|£)|" +
                "outgoing|incoming|remittance|payout|top-?up|cash\\s+(?:in|out)|" +
                "raast|ibft|1link|\\bupi\\b|\\bimps\\b|\\bneft\\b|\\brtgs\\b|\\bp2p\\b|" +
                "transaction\\s+successful|" +
                "sent\\s*(?:rs|pkr)|received\\s*(?:rs|pkr)|" +
                "a/c\\s*\\*+|account\\s*\\*+|your\\s+account|trx\\s*id|trans(?:action)?\\s*id|t(?:xn|rxn)\\s*no|" +
                "has\\s*been\\s*(?:debited|credited|deducted|sent|paid|transferred|received)|" +
                "was\\s+(?:successfully\\s+)?(?:sent|paid|transferred|debited|credited|received|processed)",
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

        fun isEmailClient(packageName: String): Boolean {
            val pkg = packageName.lowercase()
            return emailClientPrefixes.any { prefix ->
                pkg == prefix || pkg.startsWith(prefix)
            }
        }

        /** Hard-blocked apps always skip; email clients skip unless txn-shaped. */
        fun shouldSkipPackage(packageName: String, text: String): Boolean {
            if (isExcludedPackage(packageName)) return true
            if (isEmailClient(packageName)) {
                return !looksLikeTransaction(text)
            }
            return false
        }

        fun shouldMonitor(packageName: String): Boolean {
            if (isExcludedPackage(packageName)) return false
            val pkg = packageName.lowercase()
            return monitoredPackages.any { pkg.contains(it.lowercase()) } ||
                monitoredKeywords.any { pkg.contains(it) }
        }

        fun hasCurrencyLabel(text: String): Boolean = amountRegex.containsMatchIn(text)

        fun isNoiseNotification(text: String): Boolean =
            noiseNotificationRegex.containsMatchIn(text)

        fun isHighConfidenceTxn(text: String): Boolean {
            if (youSentRsRegex.containsMatchIn(text)) return true
            if (youReceivedRsRegex.containsMatchIn(text)) return true
            if (receivedInAccountRegex.containsMatchIn(text)) return true
            if (rsSentToRegex.containsMatchIn(text)) return true
            if (walletCardPaymentRegex.containsMatchIn(text)) return true
            if (youPaidAtRegex.containsMatchIn(text)) return true
            if (amountOfRsRegex.containsMatchIn(text)) return true
            if (moneyTransferOfRsRegex.containsMatchIn(text)) return true
            if (debitedByRegex.containsMatchIn(text)) return true
            return universalTxnRegex.containsMatchIn(text)
        }

        private val debitedByRegex = Regex(
            "(?:debited|deducted|withdrawn|credited)\\s+by\\s+" +
                "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?",
            RegexOption.IGNORE_CASE,
        )

        /** Title + body — UBL often puts PKR amount in the title only. */
        fun combineNotificationText(title: String, body: String): String {
            val t = title.trim()
            val b = body.trim()
            if (t.isEmpty()) return b
            if (b.isEmpty()) return t
            if (b.contains(t, ignoreCase = true)) return b
            return "$t — $b"
        }

        fun looksLikeTransaction(text: String): Boolean {
            if (isNoiseNotification(text)) return false
            if (isHighConfidenceTxn(text)) return true
            if (!hasFinanceAmount(text)) return false
            return hasCurrencyLabel(text) && strongFinanceRegex.containsMatchIn(text)
        }

        private val genericAlertTitleRegex = Regex(
            "^(?:unknown|dear customer|customer|wallet|account|payment|money|" +
                "jazzcash|easypaisa|mobilink|sadapay|nayapay|ubl|hbl|mcb|" +
                "transaction alert|money received|money sent|payment received|" +
                "transfer successful|successful transfer|transfer|backup|" +
                "off it goes|money in|money out|cha[\\s-]?ching|payment sent|" +
                "payment received|transfer complete|transfer sent)\$",
            RegexOption.IGNORE_CASE,
        )

        private fun isTitleWithAmountBody(title: String, text: String): Boolean {
            val t = title.trim()
            if (t.length < 3) return false
            if (genericAlertTitleRegex.matches(t)) return false
            if (amountRegex.containsMatchIn(t)) return false
            if (!hasFinanceAmount(text)) return false
            return walletCardPaymentRegex.containsMatchIn(text) ||
                walletTxnRegex.containsMatchIn(text) ||
                strongFinanceRegex.containsMatchIn(text) ||
                hasCurrencyLabel(text)
        }

        fun shouldCapture(packageName: String, text: String, title: String = ""): Boolean {
            if (isExcludedPackage(packageName)) return false
            if (isNoiseNotification(text)) return false

            // Tier 1 — explicit payment phrasing from any app (incl. Gmail).
            if (isHighConfidenceTxn(text)) return true

            if (isEmailClient(packageName)) {
                return hasCurrencyLabel(text) && strongFinanceRegex.containsMatchIn(text)
            }

            if (shouldMonitor(packageName)) {
                if (isHighConfidenceTxn(text)) return true
                if (!hasFinanceAmount(text)) {
                    return false
                }
                if (strongFinanceRegex.containsMatchIn(text)) return true
                if (monitoredWalletFallbackRegex.containsMatchIn(text)) return true
                if (walletTxnRegex.containsMatchIn(text)) return true
                if (isTitleWithAmountBody(title, text)) return true
                return false
            }

            // Unknown apps: currency + strong finance wording only.
            return hasCurrencyLabel(text) && strongFinanceRegex.containsMatchIn(text)
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

            val extras = sbn.notification.extras
            val title =
                extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
            val body = extractNotificationText(extras)
            val text = sanitizeNotificationText(combineNotificationText(title, body))

            if (shouldSkipPackage(pkg, text)) return

            if (text.isBlank()) {
                if (shouldMonitor(pkg)) {
                    Log.w(INGEST_TAG, "empty text pkg=$pkg title=${title.take(60)}")
                }
                return
            }

            if (shouldMonitor(pkg) || isEmailClient(pkg)) {
                Log.d(INGEST_TAG, "posted pkg=$pkg preview=${text.take(120)}")
            }

            if (!shouldCapture(pkg, text, title)) {
                if (shouldMonitor(pkg) || isEmailClient(pkg)) {
                    Log.w(
                        INGEST_TAG,
                        "skip pkg=$pkg len=${text.length} preview=${text.take(120)}",
                    )
                }
                return
            }
            if (!shouldDeliverNow(pkg, text)) return

            Log.i(INGEST_TAG, "capture pkg=$pkg preview=${text.take(100)}")

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
         * Title is handled separately in [processNotification].
         */
        fun extractNotificationText(extras: Bundle?): String {
            if (extras == null) return ""
            val title =
                extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
            val parts = LinkedHashSet<String>()

            fun add(cs: CharSequence?) {
                val t = cs?.toString()?.trim()
                if (t.isNullOrBlank()) return
                if (metadataSegmentRegex.containsMatchIn(t)) return
                if (title.isNotEmpty() && t.equals(title, ignoreCase = true)) return
                parts.add(t)
            }

            // Prefer expanded body — wallet apps often put the txn in BIG_TEXT only.
            add(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_INFO_TEXT))
            add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))

            for (key in listOf(
                    "message", "body", "content", "description", "alert",
                    "text", "subtext", "android.bigText", "android.infoText",
                )) {
                add(extras.getCharSequence(key))
                extras.getString(key)?.let { add(it) }
            }

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
                "android.title",
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
                    }
                }
            }

            if (parts.isEmpty()) {
                scanExtrasForTxnSnippet(extras)?.let { return it }
                return ""
            }

            fun financeScore(text: String): Int {
                var score = 0
                if (amountRegex.containsMatchIn(text)) score += 20
                if (walletTxnRegex.containsMatchIn(text)) score += 10
                if (rsSentToRegex.containsMatchIn(text)) score += 15
                if (walletCardPaymentRegex.containsMatchIn(text)) score += 15
                if (youPaidAtRegex.containsMatchIn(text)) score += 15
                return score + text.length / 40
            }

            val best = parts.maxByOrNull { financeScore(it) }
            if (best != null && financeScore(best) >= 20) return best

            scanExtrasForTxnSnippet(extras)?.let { return it }
            return parts.joinToString(" — ")
        }

        private fun scanExtrasForTxnSnippet(extras: Bundle?): String? {
            if (extras == null) return null
            val found = LinkedHashSet<String>()

            fun scan(value: CharSequence?) {
                val t = value?.toString()?.trim() ?: return
                txnSnippetRegex.find(t)?.value?.trim()?.let { found.add(it) }
            }

            for (key in extras.keySet()) {
                when (val value = extras.get(key)) {
                    is CharSequence -> scan(value)
                    is Array<*> -> value.filterIsInstance<CharSequence>().forEach { scan(it) }
                    is Bundle -> {
                        scan(value.getCharSequence(Notification.EXTRA_TEXT))
                        scan(value.getCharSequence(Notification.EXTRA_BIG_TEXT))
                        scan(value.getCharSequence("text"))
                    }
                }
            }

            return found.maxByOrNull { it.length }
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
                    "scanActiveNotifications" -> {
                        NotificationCaptureService.rescanActiveNotifications(context)
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
    companion object {
        @Volatile
        private var connectedInstance: NotificationCaptureService? = null

        /** Re-process alerts still visible in the notification shade. */
        fun rescanActiveNotifications(context: Context) {
            val service = connectedInstance
            if (service != null) {
                service.scanActiveNotifications()
            } else {
                IngestPlugin.requestNotificationRebind(context)
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        connectedInstance = this
        Log.d(INGEST_TAG, "NotificationListener CONNECTED")
        scanActiveNotifications()
    }

    override fun onListenerDisconnected() {
        connectedInstance = null
        super.onListenerDisconnected()
        Log.d(INGEST_TAG, "NotificationListener DISCONNECTED — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, NotificationCaptureService::class.java))
        }
    }

    override fun onDestroy() {
        connectedInstance = null
        super.onDestroy()
    }

    private fun scanActiveNotifications() {
        Handler(Looper.getMainLooper()).post {
            try {
                val active = activeNotifications
                if (active.isNullOrEmpty()) return@post
                Log.d(INGEST_TAG, "scanning ${active.size} active notification(s)")
                active.forEach { sbn ->
                    IngestPlugin.processNotification(applicationContext, sbn)
                }
            } catch (e: Exception) {
                Log.w(INGEST_TAG, "active notification scan failed", e)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        IngestPlugin.processNotification(applicationContext, sbn)
    }
}
