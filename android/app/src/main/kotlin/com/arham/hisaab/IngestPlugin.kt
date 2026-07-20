package com.arham.hisaab

import android.app.Activity
import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.content.pm.PackageManager
import android.provider.Settings
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
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
        const val METHOD_CHANNEL = "com.arham.hisaab/ingest_control"
        const val EVENT_CHANNEL = "com.arham.hisaab/ingest"

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
            // Messaging / chat — SMS uses SmsReceiver, not notification capture.
            "com.whatsapp",
            "org.telegram.",
            "org.thoughtcrime.securesms",
            "com.facebook.orca",
            "com.facebook.mlite",
            "com.facebook.lite",
            "com.viber.voip",
            "com.imo.android.",
            "com.tencent.mm",
            "jp.naver.line.",
            "com.skype.",
            "com.microsoft.teams",
            "com.Slack",
            "com.google.android.talk",
            "com.google.android.apps.dynamite",
            "com.google.android.apps.googlevoice",
            "com.instagram.barcelona",
            "com.badoo.mobile",
            "com.pinterest.",
            "com.tumblr",
            "com.amazon.mShop.android.shopping",
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
            "com.ibm.jazzcashmerchant",
            "com.finja.business",
            "com.finja.pk",
            "com.keenu.wallet",
            "com.upaisa",
            "com.paymax",
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
            "finja", "keenu", "upaisa", "paymax", "payoneer",
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
                "\\b\\d+\\s*%\\s*cashback\\b|" +
                "\\bget\\s+upto\\b|\\bupto\\s+[\\d,]+(?:\\s+cashback)?\\b|" +
                "\\bcashback\\s+on\\b|" +
                "\\bjoin\\s+karein\\b|\\bmein\\s+join\\b|" +
                "\\beligible\\s+hain\\b|" +
                "\\brewards?\\s+(?:ke\\s+liye|aap\\s+ka\\s+intezar)\\b|" +
                "\\bintezar\\s+kar\\s+rahe\\b|" +
                "\\b(?:missed\\s+call|incoming\\s+call|voice\\s+mail)\\b|" +
                "\\b(?:weather|forecast|rain\\s+alert)\\b|" +
                "\\b(?:match\\s+score|full\\s+time)\\b|" +
                "\\b(?:get\\s+a\\s+chance|chance\\s+to\\s+(?:win|earn)|for\\s+a\\s+chance|" +
                "win\\s+(?:\\d+|a\\s+|1\\s)|" +
                "(?:\\d+\\s+)?crore|(?:\\d+\\s+)?lakh|(?:\\d+\\s+)?lac)\\b|" +
                // Bank/card spend-and-win promos (English + Roman Urdu).
                "\\bwin\\s+big\\b|" +
                "\\bt\\s*&\\s*cs?\\s+apply\\b|\\bterms\\s+(?:and|&)\\s+conditions\\s+apply\\b|" +
                "\\bjeet(?:ne|ein|o)\\b|\\bmauqa\\s+hasil\\b|\\bka\\s+mauqa\\b|" +
                "\\bjeetne\\s+ka\\s+mauqa\\b|" +
                "\\b(?:spend|shopping|istemal|use)\\s+karein\\b|" +
                "\\binternational\\s+spend\\b|" +
                "\\bspend\\s+globally\\b|" +
                "\\b(?:honda|yadea).{0,48}(?:ebike|e-bike|cd\\s*70|jeet|mauqa)\\b|" +
                "\\b(?:ebike|e-bike|cd\\s*70).{0,48}(?:jeet|mauqa|honda|yadea)\\b|" +
                "\\boffer\\s+valid\\b|\\bvalid\\s+(?:till|until)\\b|" +
                "\\bmaintain\\s+(?:rs\\.?|pkr)\\b|" +
                "\\b(?:refer(?:ral)?|invite\\s+(?:friends?|and\\s+earn))\\b|" +
                "\\b\\d+\\s*(?:mb|gb|kb|tb)\\s+of\\s+\\d+\\s*(?:mb|gb|kb|tb)\\b|" +
                // Crypto / token marketing pushes that mention \$ amounts.
                "\\bbuy\\s+any\\s+amount\\b|" +
                "\\bfor\\s+a\\s+chance\\s+to\\s+earn\\b|" +
                "\\bearn\\s+\\$\\s*[\\d,]+|" +
                "\\bturn\\s+your\\b.{0,40}\\binto\\s+more\\b|" +
                // Platform payout notices — not local wallet/bank alerts.
                "\\bupwork\\b|" +
                "withdrawal\\s+of\\s+your\\s+upwork\\s+balance|" +
                "amount\\s+you\\s+should\\s+receive\\b|" +
                // Campus / university announcements — not payments.
                "international\\s+(?:education\\s+)?office\\b|" +
                "three\\s+global\\s+opportunities\\b|" +
                "semester\\s+exchange\\b|" +
                "gebze\\s+technical\\s+university\\b|" +
                "fast\\s*[—–\\-]\\s*nuc(?:es)?\\b|" +
                "(?:tuition\\s*zero|zero\\s+tuition)\\b|" +
                "\\bcgpa\\s*[≥>=]\\s*[\\d.]+\\b|" +
                // Telecom / carrier promos that mention Rs amounts.
                "\\b(?:weekly|monthly|daily)\\s+(?:freedom|x\\s+plus|package|bundle)\\b|" +
                "\\b(?:simosa|full\\s+balance\\s+offer|jazz\\s*advance|readycash|jazztune|jazz\\s*caller)\\b|" +
                "\\b(?:subscribe\\s+now|dial\\s*\\*|code\\s*\\*|bit\\.ly/|onelink\\.to/)\\b|" +
                "\\b(?:gb|mb)\\s*,\\s*\\d+\\s+(?:other\\s+)?(?:network\\s+)?min|" +
                // Bank / wallet service maintenance — not payments.
                "\\b(?:maintenance|scheduled\\s+maintenance|system\\s+maintenance|planned\\s+maintenance)\\b|" +
                "\\b(?:services?\\s+will\\s+be\\s+unavailable|temporarily\\s+unavailable)\\b|" +
                "\\b(?:service\\s+disruptions?|intermittent\\s+service)\\b|" +
                "\\b(?:downtime|service\\s+outage|planned\\s+outage)\\b|" +
                "\\bunavailable\\s+due\\s+to\\b|" +
                "\\b(?:apologize|apologise)\\s+for\\s+(?:any\\s+)?inconvenience\\b|" +
                "\\braast\\s+(?:system\\s+)?maintenance\\b|" +
                "\\bmaintenance\\s+(?:window|period|activity)\\b|" +
                "\\b(?:for\\s+any\\s+queries|please\\s+(?:immediately\\s+)?call)\\b|" +
                // Bank login / security — not money movement.
                "\\b(?:login|log[\\s-]?in)\\s+successful\\b|" +
                "\\bsuccessfully\\s+logged\\s+in\\b|" +
                "\\blogged\\s+in\\s+to\\b|" +
                "\\bdo\\s+not\\s+recogni[sz]e\\s+this\\s+login\\b|" +
                "\\bunrecogni[sz]ed\\s+login\\b|" +
                "\\bnew\\s+device\\s+(?:login|sign[\\s-]?in)\\b|" +
                "\\b(?:security|fraud)\\s+alert\\b|" +
                "\\bhelpline\\b|" +
                "\\bblock\\s+(?:the\\s+)?(?:mobile\\s+)?banking\\b|" +
                // Unpaid challan / bill notices — "generated", not paid.
                "\\b(?:traffic\\s+)?challan\\b.{0,160}\\b(?:is\\s+|has\\s+been\\s+)?generated\\b|" +
                "\\b(?:is\\s+|has\\s+been\\s+)?generated\\b.{0,160}\\b(?:traffic\\s+)?challan\\b|" +
                "\\bpsid\\s*[:=]\\s*\\d+.{0,160}\\bgenerated\\b|" +
                "\\bgenerated\\b.{0,160}\\bpsid\\b|" +
                "\\bgenerated\\b.{0,80}\\bepay\\b|" +
                "\\bepay\\b.{0,80}\\bgenerated\\b|" +
                "\\bfor\\s+payment\\s+of\\s+(?:rs\\.?|pkr).{0,80}\\bagainst\\s+vehicle\\b",
            RegexOption.IGNORE_CASE,
        )

        /** Marketing / promotional wording (English + Roman Urdu). */
        private val promoSignalRegex = Regex(
            "\\bwin\\b|\\bprizes?\\b|\\blucky\\s+draw\\b|\\bbumper\\s+(?:prize|offer|draw)\\b|" +
                "\\binaam\\b|\\bjeet(?:ne|ein|ain|o)?\\b|\\bmauqa\\b|\\bmuft\\b|" +
                "\\bdiscounts?\\b|\\bvouchers?\\b|\\bpromo\\b|\\bcoupons?\\b|" +
                "\\b(?:mega|flash|grand|big)\\s+sale\\b|\\bsale\\s+is\\s+live\\b|" +
                "\\b(?:exclusive|special|exciting|amazing)\\s+offer\\b|" +
                "\\boffer\\s+(?:valid|ends?|expires?)\\b|\\bvalid\\s+(?:till|until|upto)\\b|" +
                "\\bavail\\s+(?:now|this|the|exciting|amazing|karein)\\b|" +
                "\\bapply\\s+now\\b|\\bregister\\s+(?:now|today)\\b|\\bsign\\s+up\\b|" +
                "\\bdownload\\s+(?:now|the\\s+app)\\b|" +
                "\\bhurry\\b|\\blimited\\s+time\\b|\\bdon.?t\\s+miss\\b|\\blast\\s+chance\\b|" +
                "\\bstand\\s+a\\s+chance\\b|\\bfor\\s+a\\s+chance\\b|" +
                "\\bchance\\s+to\\s+(?:win|earn)\\b|" +
                "\\bget\\s+(?:up\\s*to|a\\s+free|your\\s+free)\\b|" +
                "\\bearn\\s+(?:up\\s*to|points|rewards|\\$)\\b|" +
                "\\bbuy\\s+any\\s+amount\\b|" +
                "\\bupgrade\\s+(?:your|to|now)\\b|\\bshop\\s+(?:now|and\\s+win|&\\s+win)\\b|" +
                "\\bfree\\s+(?:delivery|gift|voucher|coupon|tickets?|entry)\\b|" +
                "\\b(?:spend|shopping|istemal|use|recharge|load)\\s+kar(?:ein|o|iye)\\b|" +
                "\\binternational\\s+spend\\b|" +
                "\\bjeetne\\s+ka\\s+mauqa\\b|" +
                "\\b(?:honda|yadea).{0,48}(?:ebike|e-bike|cd\\s*70|jeet|mauqa)\\b|" +
                "\\bkarein\\s+aur\\b|\\bhasil\\s+kar(?:ein|o|iye)\\b|\\bkijiye\\b|" +
                "\\buthayein\\b|\\bbanayein\\b|\\bpayein\\b|" +
                "\\bt\\s*&\\s*cs?\\b|\\bterms\\s+(?:and|&)\\s+conditions\\b|" +
                "\\bfx\\s+fee\\b|\\bbachat\\b|\\bfaida\\b|\\bmoassar\\b",
            RegexOption.IGNORE_CASE,
        )

        /** Completed money-movement evidence — overrides promo wording. */
        private val completedTxnEvidenceRegex = Regex(
            "has\\s+been\\s+(?:debited|credited|deducted|withdrawn|transferred|sent|paid|received|reversed)|" +
                "(?:debited|credited|deducted|withdrawn)\\s+(?:by|with|from|for)\\b|" +
                "\\byou\\s+(?:have\\s+)?(?:sent|paid|received|transferred|spent)\\b|" +
                "\\bsent\\s+you\\s+(?:pkr|rs\\.?|inr|₹|₨)|" +
                "(?:you.?ve|you\\s+have)\\s+got\\s+money|\\bgot\\s+money\\b|" +
                "\\bsuccessfully\\s+(?:sent|received|transferred|paid|credited|debited)|" +
                "\\b(?:transaction|transfer|payment|txn)\\s+(?:successful|completed?)\\b|" +
                "\\b(?:trx|txn|trxn|transaction)\\s*(?:id|no|#)|" +
                "\\bref(?:erence)?\\s*(?:id|no|#|:)|" +
                "\\b(?:available|remaining|current|new)\\s+balance\\b|\\bbal(?:ance)?\\s*[:=]|" +
                "\\breceived\\s+from\\b|\\b(?:paid|sent|transferred)\\s+to\\b|" +
                "\\bpurchase\\s+(?:of|at)\\b|\\b(?:pos|atm)\\s+(?:purchase|withdrawal|transaction)\\b|" +
                "\\bcash\\s+(?:deposit|withdrawal|wdl|wdr)\\b|\\bdeposit(?:ed)?\\b|\\bwithdrawal\\b|" +
                "\\bvia\\s+(?:raast|ibft|pos|atm|1link)\\b|" +
                "\\b(?:is\\s+)?charged\\b.*?\\bfor\\s+(?:pkr|rs\\.?)",
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
            "debited|credited|withdrawn|withdrawal|deducted|spent|transferred|purchase|" +
                "\\bcharged\\b|\\bis\\s+charged\\b|" +
                "\\bcash\\s+(?:deposit|withdrawal|wdl|wdr)\\b|\\bdeposit(?:ed)?\\b|" +
                "(?:debited|deducted|withdrawn|credited)\\s+by\\s+(?:pkr|rs\\.?)|" +
                "fund\\s+transfer|funds?\\s+transfer|transfer\\s+to|transfer\\s+successful|" +
                "mobile\\s+wallet|wallet\\s+a/c|" +
                "money\\s+(?:received|sent)|payment\\s+(?:received|sent)|" +
                "(?:you.?ve|you\\s+have)\\s+got\\s+money|got\\s+money|" +
                "you\\s+(?:sent|paid|received|got|transferred)|" +
                "sent\\s+you\\s+(?:pkr|rs\\.?|inr|₹|₨)|" +
                "(?:paid|sent|transferred)\\s+to\\b|" +
                "(?:paid|sent|transferred)\\s+(?:pkr|rs\\.?|inr|₹|₨|\\$|€|£)|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+sent\\s+to\\b|" +
                "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+received\\s+from\\b|" +
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
                "a/c\\s*(?:\\*+|x+\\d*)|account\\s*(?:\\*+|x+\\d*)|trx\\s*id|trans(?:action)?\\s*id|" +
                "raast|ibft|1link|\\bupi\\b|\\bimps\\b|\\bneft\\b|\\brtgs\\b",
            RegexOption.IGNORE_CASE,
        )

        private val recentDeliveries = LinkedHashMap<String, Long>()

        private fun deliveryKey(pkg: String, text: String): String {
            val normalized = text.replace("\\s+".toRegex(), " ").trim().lowercase()
            return "$pkg|${normalized.hashCode()}"
        }

        fun amountKeyForQueue(pkg: String, text: String): String? = amountKey(pkg, text)

        private fun amountKey(pkg: String, text: String): String? {
            val amountMatch = amountRegex.find(text)?.value
                ?: plainAmountRegex.find(text)?.value
                ?: return null
            val normalized = amountMatch.replace("\\s".toRegex(), "").lowercase()
            return "$pkg:$normalized"
        }

        /** Live listener only — shade re-scans bypass this (see [processNotification]). */
        fun shouldDeliverNow(pkg: String, text: String): Boolean {
            val now = System.currentTimeMillis()
            val key = deliveryKey(pkg, text)
            synchronized(recentDeliveries) {
                val prev = recentDeliveries[key]
                if (prev != null && now - prev < LIVE_DEDUP_MS) {
                    PrivacyLog.d(INGEST_TAG, "  deduped identical alert for $key")
                    return false
                }
                recentDeliveries[key] = now
                while (recentDeliveries.size > 200) {
                    val oldest = recentDeliveries.keys.first()
                    recentDeliveries.remove(oldest)
                }
            }
            return true
        }

        private const val LIVE_DEDUP_MS = 30_000L

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
            if (amountRegex.containsMatchIn(text)) return true
            for (match in plainAmountRegex.findAll(text)) {
                val raw = match.groupValues.getOrNull(1) ?: continue
                val value = raw.replace(",", "").toDoubleOrNull() ?: continue
                if (value < 1.0) continue
                if (isInvalidAmountContext(text, match.range.first, match.range.last + 1)) {
                    continue
                }
                return true
            }
            return false
        }

        /** PK bank/wallet SMS senders — Raast, Easypaisa, JazzCash, card alerts, etc. */
        private val walletSmsShortCodes = setOf(
            "3737",   // Easypaisa
            "8558",   // Raast / bank transfer alerts
            "18258",  // Jazz / wallet alerts
            "80040",  // Bank / wallet alerts
            "4255",   // UBL
            "8067",   // HBL
            "9080",   // MCB
            "8484",   // Bank Alfalah
            "9878",   // Meezan
            "6969",   // Jazz (legacy)
            "8623",   // SadaPay
        )

        private val walletSmsTxnKeywords = listOf(
            "paid", "debited", "credited", "transferred", "withdrawn",
            "charged", "is charged",
            "txn id", "trx id", "tid:", "tid ", "debit card",
            "received from", "sent to", "successfully sent", "you just sent",
            "amount of rs", "amount of pkr", "has been sent", "has been debited",
            "has been credited", "via raast", "raast payment", "via ibft",
            "money transfer", "you have paid", "you have received",
            "transaction fee", "debited by", "credited by",
        )

        private fun normalizeSmsSender(sender: String): String {
            var compact = sender.filter { !it.isWhitespace() }
            if (compact.startsWith("+")) compact = compact.drop(1)
            if (compact.startsWith("92") && compact.length > 6) {
                compact = compact.removePrefix("92")
            }
            return compact
        }

        fun isKnownWalletShortCode(sender: String): Boolean {
            val norm = normalizeSmsSender(sender)
            if (walletSmsShortCodes.contains(norm)) return true
            return walletSmsShortCodes.any { norm.endsWith(it) && norm.length <= it.length + 2 }
        }

        /** True for live SMS capture and inbox rescan (3737, 8558, …). */
        fun isLikelySmsTransaction(sender: String, body: String): Boolean {
            if (isNoiseNotification(body)) return false
            if (looksLikeTransaction(body)) return true
            if (isHighConfidenceTxn(body)) return true

            val fromWalletSender =
                isKnownWalletShortCode(sender) || isNumericSmsShortCode(sender)
            if (!fromWalletSender) return false
            if (!hasFinanceAmount(body)) return false

            val bodyLower = body.lowercase()
            if (walletSmsTxnKeywords.any { bodyLower.contains(it) }) return true

            // Known wallet short codes: accept any body with amount + txn id / raast.
            if (isKnownWalletShortCode(sender)) {
                return monitoredWalletFallbackRegex.containsMatchIn(body) ||
                    raastTxnRegex.containsMatchIn(body) ||
                    strongFinanceRegex.containsMatchIn(body)
            }
            return false
        }

        /** Inbox backfill — same rules as live SMS capture. */
        fun isSmsRescanCandidate(sender: String, body: String): Boolean =
            isLikelySmsTransaction(sender, body)

        private fun isNumericSmsShortCode(sender: String): Boolean {
            val compact = normalizeSmsSender(sender)
            if (compact.length !in 4..6) return false
            return compact.all { it.isDigit() }
        }

        /**
         * Re-read recent inbox SMS when the app opens — catches alerts missed live.
         * [walletShortCodesOnly] — when true, only scans known wallet senders (fast).
         */
        fun scanRecentTransactionSms(
            context: Context,
            walletShortCodesOnly: Boolean = false,
        ) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return
            }

            val sinceMs = System.currentTimeMillis() -
                if (walletShortCodesOnly) 24L * 60 * 60 * 1000 else 2L * 24 * 60 * 60 * 1000
            val maxRows = if (walletShortCodesOnly) 20 else 40
            val cursor = context.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                ),
                "${Telephony.Sms.DATE} >= ?",
                arrayOf(sinceMs.toString()),
                "${Telephony.Sms.DATE} DESC",
            ) ?: return

            var queued = 0
            cursor.use {
                while (it.moveToNext() && queued < maxRows) {
                    val address = it.getString(1)?.trim().orEmpty()
                    val body = it.getString(2)?.trim().orEmpty()
                    if (address.isEmpty() || body.isEmpty()) continue
                    if (walletShortCodesOnly && !isKnownWalletShortCode(address)) continue
                    val date = it.getLong(3)
                    if (!isSmsRescanCandidate(address, body)) continue
                    queued++
                    PrivacyLog.d(INGEST_TAG, "sms rescan from $address len=${body.length}")
                    CapturedEventStore.enqueue(
                        context,
                        mapOf(
                            "source" to "sms",
                            "text" to body,
                            "sender" to address,
                            "timestamp" to date,
                        ),
                    )
                }
            }
            if (queued > 0) {
                PrivacyLog.i(INGEST_TAG, "sms inbox rescan queued=$queued")
            }
        }

        private val monthNamesRegex = Regex(
            "\\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|" +
                "jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\\b",
            RegexOption.IGNORE_CASE,
        )

        private fun isInvalidAmountContext(
            text: String,
            start: Int = 0,
            end: Int = text.length,
        ): Boolean {
            if (start == 0 && end == text.length) {
                if (Regex(
                        "\\b\\d+\\s*(?:mb|gb|kb|tb)\\s+of\\s+\\d+\\s*(?:mb|gb|kb|tb)\\b",
                        RegexOption.IGNORE_CASE,
                    ).containsMatchIn(text)) {
                    return true
                }
                if (Regex(
                        "\\b(?:crore|lakh|lac|million|billion)\\b",
                        RegexOption.IGNORE_CASE,
                    ).containsMatchIn(text)) {
                    return true
                }
                return false
            }
            val safeEnd = end.coerceAtMost(text.length)
            val tail = text.substring(safeEnd).trimStart()
            if (Regex("^(?:mb|gb|kb|tb|%)\\b", RegexOption.IGNORE_CASE).containsMatchIn(tail)) {
                return true
            }
            if (Regex("^:\\d{2}\\b", RegexOption.IGNORE_CASE).containsMatchIn(tail)) {
                return true
            }
            val windowEnd = (safeEnd + 24).coerceAtMost(text.length)
            val window = text.substring(start.coerceAtMost(text.length), windowEnd)
            if (Regex(
                    "\\b(?:crore|lakh|lac|million|billion)\\b",
                    RegexOption.IGNORE_CASE,
                ).containsMatchIn(window)) {
                return true
            }
            val raw = text.substring(start.coerceAtMost(text.length), safeEnd).replace(",", "")
            val value = raw.toIntOrNull()
            if (value != null && value in 2000..2099) {
                val before = text.substring(0, start.coerceAtMost(text.length))
                if (monthNamesRegex.containsMatchIn(before) ||
                    Regex(
                        "\\b(?:on|from|,|\\d{1,2}(?:st|nd|rd|th)?)\\s*$",
                        RegexOption.IGNORE_CASE,
                    ).containsMatchIn(before)) {
                    return true
                }
            }
            return false
        }

        fun sanitizeNotificationText(text: String): String {
            if (text.isBlank()) return ""
            // Em/en dash or pipe only — never ASCII "-" (breaks "Shah-bakht", dates).
            return text.split(Regex("\\s*(?:—|–|\\|)\\s*"))
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

        /** UBL debit-card SMS: "… is charged … for PKR 5,000.00 at MERCHANT" */
        private val cardChargedForRegex = Regex(
            "(?:is\\s+)?charged\\b.*?\\bfor\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?",
            RegexOption.IGNORE_CASE,
        )

        /** JazzCash Raast: "Rs 100.0 received from NAME AC …" */
        private val rsReceivedFromRegex = Regex(
            "(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+received\\s+from\\b",
            RegexOption.IGNORE_CASE,
        )

        private val txnSnippetRegex = Regex(
            "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+(?:sent\\s+to|received\\s+from|with\\b)|" +
                "you\\s+(?:have\\s+)?paid\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?(?:\\s+at\\b)?",
            RegexOption.IGNORE_CASE,
        )

        /** Full wallet txn line — includes counterparty name when extras only yield a prefix. */
        private val txnLineRegex = Regex(
            "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+(?:sent\\s+to|received\\s+from)\\s+[^.\\n—|]{3,120}",
            RegexOption.IGNORE_CASE,
        )

        /** Primary PK wallet triggers — "You sent Rs. 500" / Raqami "You just sent PKR …" */
        private val youSentRsRegex = Regex(
            "you\\s+(?:just\\s+)?sent\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+",
            RegexOption.IGNORE_CASE,
        )

        /** Raqami: "You just sent PKR 1.00 to NAME" */
        private val youJustSentToRegex = Regex(
            "you\\s+just\\s+sent\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+to\\b",
            RegexOption.IGNORE_CASE,
        )

        private val youReceivedRsRegex = Regex(
            "you\\s+(?:have\\s+)?(?:received|got)\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+",
            RegexOption.IGNORE_CASE,
        )

        /** NayaPay inbound: "ADEEL AHMAD sent you Rs. 300." */
        private val nameSentYouRsRegex = Regex(
            "[A-Za-z\\u0600-\\u06FF][A-Za-z0-9\\u0600-\\u06FF .'\\-]{0,48}?" +
                "\\s+sent\\s+you\\s+(?:pkr|rs\\.?|inr|₹|₨)\\.?\\s*[\\d,]+",
            RegexOption.IGNORE_CASE,
        )

        /** NayaPay credit title: "You've got money" (with amount elsewhere). */
        private val gotMoneyRegex = Regex(
            "(?:you.?ve|you\\s+have)\\s+got\\s+money|\\bgot\\s+money\\b",
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

        /** JazzCash: "PKR 1,000.00 has been successfully transferred to …" */
        private val successfullyTransferredRegex = Regex(
            "(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?\\s+has\\s+been\\s+successfully\\s+transferred",
            RegexOption.IGNORE_CASE,
        )

        /** JazzCash: "You have successfully sent PKR 100.00 to …" */
        private val successfullySentRegex = Regex(
            "you\\s+have\\s+successfully\\s+sent\\s+(?:pkr|rs\\.?)\\.?\\s*[\\d,]+(?:\\.\\d+)?",
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
            "a/c|account|\\*\\*\\*|trx\\s*id|trans(?:action)?\\s*id|\\bTID:\\s*\\d{5,}",
            RegexOption.IGNORE_CASE,
        )

        private val personNameTitleRegex = Regex(
            "^[A-Za-z\\u0600-\\u06FF][A-Za-z0-9\\u0600-\\u06FF .'\\-&]{1,48}$",
        )

        private val amountOnlyBodyRegex = Regex(
            "^(?:[\\s—\\-–]*(?:pkr|rs\\.?|inr)?[\\s]*)?[\\d,]+(?:\\.\\d+)?[\\s.—\\-–]*$",
            RegexOption.IGNORE_CASE,
        )

        private fun isAmountOnlyBody(text: String, title: String = ""): Boolean {
            val t = text.trim()
            if (amountOnlyBodyRegex.matches(t)) return true
            val name = title.trim()
            if (name.isEmpty()) return false
            val combined = Regex(
                "^${Regex.escape(name)}\\s*[—\\-–]\\s*" +
                    "(?:[\\s]*(?:pkr|rs\\.?|inr)?[\\s]*)?[\\d,]+(?:\\.\\d+)?[\\s.—\\-–]*$",
                RegexOption.IGNORE_CASE,
            )
            return combined.matches(t)
        }

        private fun isPersonNameTitle(title: String): Boolean {
            val t = title.trim()
            if (t.length < 3) return false
            if (isGenericAlertTitle(t)) return false
            if (amountRegex.containsMatchIn(t)) return false
            return personNameTitleRegex.matches(t)
        }

        /** Signals real money movement — aligned with Dart [TransactionParser]. */
        private val walletTxnRegex = Regex(
            "debited|credited|spent|withdrawn|withdrawal|deducted|transferred|received|" +
                "paid|sent|purchase|txn|transaction|debit|credit|refund|" +
                "(?:received|credited|you\\s+(?:have\\s+)?got).{0,50}cashback|" +
                "cashback.{0,50}(?:received|credited|in\\s+your)|" +
                "\\bcash\\s+(?:deposit|withdrawal|wdl|wdr|in|out)\\b|\\bdeposit(?:ed)?\\b|" +
                "salary|transfer|withdrawal|" +
                "payment|charged|bill|added|successful|completed|processed|" +
                "money\\s+received|money\\s+sent|payment\\s+received|payment\\s+sent|" +
                "transfer\\s*successful|successfully\\s*transferred|" +
                "you\\s+sent|you\\s+paid|you\\s+transferred|sent\\s+to|paid\\s+to|" +
                "transfer\\s+to|transfer\\s+from|received\\s+from|" +
                "amount\\s+of\\s+(?:rs|pkr)|money\\s+transfer\\s+of|successfully\\s+sent|" +
                "(?:payment|transfer|transaction|remittance|payout)\\s+of\\s+(?:rs|pkr|inr|\\$|€|£)|" +
                "outgoing|incoming|remittance|payout|top-?up|" +
                "raast|ibft|1link|\\bupi\\b|\\bimps\\b|\\bneft\\b|\\brtgs\\b|\\bp2p\\b|" +
                "transaction\\s+successful|" +
                "sent\\s*(?:rs|pkr)|received\\s*(?:rs|pkr)|" +
                "a/c|account|\\*{3,}|your\\s+account|trx\\s*id|trans(?:action)?\\s*id|t(?:xn|rxn)\\s*no|" +
                "has\\s*been\\s*(?:debited|credited|deducted|sent|paid|transferred|received)|" +
                "was\\s+(?:successfully\\s+)?(?:sent|paid|transferred|debited|credited|received|processed)",
            RegexOption.IGNORE_CASE,
        )

        fun deliver(
            context: Context,
            event: Map<String, Any?>,
            suppressLive: Boolean = false,
        ) {
            // Queue synchronously so a scan + immediate drain cannot miss the row.
            // This is the safety net: a capture is NEVER dropped at the native
            // layer — the next drain processes it and Flutter dedups.
            CapturedEventStore.enqueue(context, event)

            // Skip only the live push for a back-to-back identical alert; the
            // queued copy above still guarantees the capture is processed.
            if (suppressLive) {
                PrivacyLog.d(INGEST_TAG, "deliver -> queue only (deduped live push)")
                return
            }

            // NotificationListener callbacks are not always on the main thread;
            // EventChannel requires the UI thread or events are silently dropped.
            mainHandler.post {
                val sink = eventSink
                if (sink != null) {
                    try {
                        PrivacyLog.d(
                            INGEST_TAG,
                            "deliver -> live sink source=${event["source"]} len=${(event["text"] as? String)?.length ?: 0}",
                        )
                        sink.success(event)
                    } catch (e: Exception) {
                        PrivacyLog.w(INGEST_TAG, "live sink failed (queued copy kept)", e)
                    }
                } else {
                    PrivacyLog.d(INGEST_TAG, "deliver -> queue only (no live sink)")
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
            noiseNotificationRegex.containsMatchIn(text) || isPromotionalContent(text)

        /** Promo wording with no completed-transaction evidence — never cash. */
        private fun isPromotionalContent(text: String): Boolean =
            promoSignalRegex.containsMatchIn(text) &&
                !isHighConfidenceTxn(text) &&
                !completedTxnEvidenceRegex.containsMatchIn(text)

        fun isHighConfidenceTxn(text: String): Boolean {
            if (youSentRsRegex.containsMatchIn(text)) return true
            if (youJustSentToRegex.containsMatchIn(text)) return true
            if (youReceivedRsRegex.containsMatchIn(text)) return true
            if (nameSentYouRsRegex.containsMatchIn(text)) return true
            if (gotMoneyRegex.containsMatchIn(text) && hasFinanceAmount(text)) return true
            if (receivedInAccountRegex.containsMatchIn(text)) return true
            if (rsSentToRegex.containsMatchIn(text)) return true
            if (rsReceivedFromRegex.containsMatchIn(text)) return true
            if (walletCardPaymentRegex.containsMatchIn(text)) return true
            if (youPaidAtRegex.containsMatchIn(text)) return true
            if (cardChargedForRegex.containsMatchIn(text)) return true
            if (amountOfRsRegex.containsMatchIn(text)) return true
            if (moneyTransferOfRsRegex.containsMatchIn(text)) return true
            if (successfullyTransferredRegex.containsMatchIn(text)) return true
            if (successfullySentRegex.containsMatchIn(text)) return true
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
                "jazzcash|easypaisa|mobilink|sadapay|nayapay|ubl|hbl|mcb|meezan|" +
                "meezan bank|transaction alert|money received|money sent|payment received|" +
                "transfer successful|successful transfer|transfer|backup|" +
                "off it goes|money in|money out|cha[\\s-]?ching|payment sent|" +
                "payment received|transfer complete|transfer sent|" +
                "original message|card in action|" +
                "got money|you.?ve got money|" +
                "raast (?:incoming|outgoing) payment)\$",
            RegexOption.IGNORE_CASE,
        )

        private val institutionalTitleRegex = Regex(
            "\\b(?:bank|meezan|hbl|ubl|mcb|alfalah|faysal|askari|habib|" +
                "jazzcash|easypaisa|nayapay|sadapay|raqami|" +
                "visa|mastercard|american\\s+express|amex|" +
                "debit\\s+card|credit\\s+card|gold\\s+card|classic\\s+card|" +
                "platinum\\s+card|prepaid\\s+card)\\b",
            RegexOption.IGNORE_CASE,
        )

        private fun isGenericAlertTitle(title: String): Boolean {
            val t = title.trim()
            if (genericAlertTitleRegex.matches(t)) return true
            val lower = t.lowercase()
            if (institutionalTitleRegex.containsMatchIn(lower)) return true
            if (Regex(
                    "\\b(?:alert|notification|helpline|security)\\b",
                    RegexOption.IGNORE_CASE,
                ).containsMatchIn(lower)
            ) {
                return true
            }
            if (Regex(
                    "\\b(?:incoming|outgoing|successful)\\s+" +
                        "(?:payment|transfer|transaction|credit|debit)\\b",
                    RegexOption.IGNORE_CASE,
                ).containsMatchIn(lower)
            ) {
                return true
            }
            if (Regex(
                    "\\b(?:payment|transfer|transaction)\\s+" +
                        "(?:received|sent|successful|complete|failed|alert)\\b",
                    RegexOption.IGNORE_CASE,
                ).containsMatchIn(lower)
            ) {
                return true
            }
            if (Regex(
                    "^(?:raast|ibft|1link|upi|imps|neft)\\b",
                    RegexOption.IGNORE_CASE,
                ).containsMatchIn(lower)
            ) {
                return true
            }
            // NayaPay / wallet casual titles with trailing emoji — "Off it goes 💸"
            return lower.startsWith("off it goes") ||
                lower.startsWith("money in") ||
                lower.startsWith("money out") ||
                lower.startsWith("raast incoming payment") ||
                lower.startsWith("raast outgoing payment") ||
                lower.startsWith("transfer successful") ||
                (lower.startsWith("cha") && lower.contains("ching"))
        }

        private fun isTitleWithAmountBody(title: String, text: String): Boolean {
            val t = title.trim()
            if (t.length < 3) return false
            if (isGenericAlertTitle(t)) return false
            if (amountRegex.containsMatchIn(t)) return false
            if (!hasFinanceAmount(text)) return false
            // Require real money-movement wording — bare "$10" in marketing is not enough.
            return walletCardPaymentRegex.containsMatchIn(text) ||
                isHighConfidenceTxn(text) ||
                strongFinanceRegex.containsMatchIn(text)
        }

        fun shouldCapture(packageName: String, text: String, title: String = ""): Boolean {
            if (isExcludedPackage(packageName)) return false
            if (isNoiseNotification(text)) return false

            if (isEmailClient(packageName)) {
                if (isHighConfidenceTxn(text)) return true
                return hasCurrencyLabel(text) && strongFinanceRegex.containsMatchIn(text)
            }

            // Only bank / wallet apps — never random apps (WhatsApp, etc.).
            if (!shouldMonitor(packageName)) return false

            if (isHighConfidenceTxn(text)) return true
            if (!hasFinanceAmount(text)) {
                return false
            }
            // JazzCash / NayaPay: counterparty in title, amount-only body.
            if (isPersonNameTitle(title) && isAmountOnlyBody(text, title)) return true
            if (strongFinanceRegex.containsMatchIn(text)) return true
            if (monitoredWalletFallbackRegex.containsMatchIn(text)) return true
            if (walletTxnRegex.containsMatchIn(text)) return true
            if (isTitleWithAmountBody(title, text)) return true
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

        fun hasSmsPermission(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) ==
                PackageManager.PERMISSION_GRANTED
        }

        /** Keep the capture monitor running when either ingest path is enabled. */
        fun shouldRunCaptureMonitor(context: Context): Boolean {
            return isNotificationAccessEnabled(context) || hasSmsPermission(context)
        }

        /** Foreground service only needed for notification listener (not SMS). */
        fun shouldRunKeepAlive(context: Context): Boolean {
            return isNotificationAccessEnabled(context)
        }

        /** True when the Flutter UI isolate is listening on the ingest EventChannel. */
        fun isLiveIngestAttached(): Boolean = eventSink != null

        /**
         * Shared capture path for live posts and the active-notification scan on connect.
         *
         * [fromActiveScan] — re-reads of the notification shade skip the short native
         * dedup window so opening the app can recover alerts the live path missed.
         */
        fun processNotification(
            context: Context,
            sbn: StatusBarNotification,
            fromActiveScan: Boolean = false,
        ) {
            val pkg = sbn.packageName ?: return
            if (pkg == context.packageName) return

            val extras = sbn.notification.extras
            val title =
                extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
            val body = extractNotificationText(extras)
            var text = sanitizeNotificationText(combineNotificationText(title, body))

            if (shouldSkipPackage(pkg, text)) return

            if (text.isBlank()) {
                if (shouldMonitor(pkg)) {
                    PrivacyLog.w(INGEST_TAG, "empty text pkg=$pkg")
                }
                return
            }

            // Samsung / PK wallets sometimes post title-only first — recover txn line from extras.
            if (shouldMonitor(pkg) && !shouldCapture(pkg, text, title)) {
                val recovered = scanExtrasForTxnSnippet(extras)
                if (recovered != null) {
                    text = sanitizeNotificationText(combineNotificationText(title, recovered))
                }
            }

            if (shouldMonitor(pkg) || isEmailClient(pkg)) {
                PrivacyLog.d(INGEST_TAG, "posted pkg=$pkg len=${text.length}")
            }

            if (!shouldCapture(pkg, text, title)) {
                if (shouldMonitor(pkg) || isEmailClient(pkg)) {
                    PrivacyLog.w(
                        INGEST_TAG,
                        "skip pkg=$pkg len=${text.length}",
                    )
                }
                return
            }
            // Never drop at the native layer — always enqueue so a capture is
            // never lost. The Flutter side dedups intelligently (Trx ID +
            // fingerprint). [suppressLive] only avoids pushing the exact same
            // text to the live sink twice in a row; the queued copy remains.
            val suppressLive = !fromActiveScan && !shouldDeliverNow(pkg, text)

            PrivacyLog.captureLive(INGEST_TAG, "notification", pkg)

            deliver(
                context,
                suppressLive = suppressLive,
                event = mapOf(
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
                PrivacyLog.d(INGEST_TAG, "requested notification listener rebind")
            } catch (e: Exception) {
                PrivacyLog.w(INGEST_TAG, "rebind request failed", e)
            }
        }

        fun isIgnoringBatteryOptimizations(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }

        fun openBatteryOptimizationSettings(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
            tryStartSettingsActivity(
                context,
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            )
        }

        /**
         * Opens notification-listener access with OEM fallbacks.
         * @see NotificationAccessSettings
         */
        fun openNotificationAccessSettings(context: Context): NotificationAccessSettings.OpenResult =
            NotificationAccessSettings.open(context)

        private fun tryStartSettingsActivity(context: Context, intent: Intent): Boolean {
            return try {
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                if (context !is Activity) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                PrivacyLog.w(INGEST_TAG, "startActivity failed for ${intent.action}", e)
                false
            }
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
                if (rsReceivedFromRegex.containsMatchIn(text)) score += 15
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
                txnLineRegex.find(t)?.value?.trim()?.let { found.add(it) }
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

        /** Method channel only — safe for the headless background Flutter engine. */
        fun registerMethodChannel(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, METHOD_CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isNotificationAccessEnabled" -> {
                            result.success(isNotificationAccessEnabled(context))
                        }
                        "openNotificationAccessSettings" -> {
                            Handler(Looper.getMainLooper()).post {
                                val outcome = openNotificationAccessSettings(context)
                                result.success(outcome.toMap())
                            }
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
                            val force = call.argument<Boolean>("force") ?: false
                            NotificationCaptureService.rescanActiveNotifications(
                                context,
                                force = force,
                            )
                            result.success(null)
                        }
                        "scanRecentSms" -> {
                            val walletOnly =
                                call.argument<Boolean>("walletShortCodesOnly") ?: false
                            scanRecentTransactionSms(context, walletShortCodesOnly = walletOnly)
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
                        "openBatteryOptimizationSettings" -> {
                            openBatteryOptimizationSettings(context)
                            result.success(null)
                        }
                        "getLegacyMigrationStatus" -> {
                            val outcome = LegacyDataMigrator.lastMigrationResult()
                                ?: LegacyDataMigrator.migrateIfNeeded(context)
                            result.success(outcome.toMap())
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }

    init {
        registerMethodChannel(context, flutterEngine.dartExecutor.binaryMessenger)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PrivacyLog.d(INGEST_TAG, "Flutter event sink attached")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    PrivacyLog.d(INGEST_TAG, "Flutter event sink detached")
                    eventSink = null
                }
            })
    }
}

class NotificationCaptureService : NotificationListenerService() {
    companion object {
        @Volatile
        private var connectedInstance: NotificationCaptureService? = null

        @Volatile
        private var lastActiveScanMs = 0L

        /** Minimum gap between automatic shade re-scans (listener reconnect, etc.). */
        private const val ACTIVE_SCAN_MIN_INTERVAL_MS = 3L * 60L * 1000L

        /** Re-process alerts still visible in the notification shade. */
        fun rescanActiveNotifications(context: Context, force: Boolean = false) {
            val service = connectedInstance
            if (service != null) {
                service.scanActiveNotifications(force)
            } else {
                IngestPlugin.requestNotificationRebind(context)
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        connectedInstance = this
        PrivacyLog.d(INGEST_TAG, "NotificationListener CONNECTED")
        // Throttled — cold start / pull-to-refresh use an explicit forced scan.
        scanActiveNotifications(force = false)
    }

    override fun onListenerDisconnected() {
        connectedInstance = null
        super.onListenerDisconnected()
        PrivacyLog.d(INGEST_TAG, "NotificationListener DISCONNECTED — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, NotificationCaptureService::class.java))
        }
    }

    override fun onDestroy() {
        connectedInstance = null
        super.onDestroy()
    }

    private fun scanActiveNotifications(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastActiveScanMs < ACTIVE_SCAN_MIN_INTERVAL_MS) {
            PrivacyLog.d(INGEST_TAG, "skip shade scan — throttled")
            return
        }
        lastActiveScanMs = now
        Handler(Looper.getMainLooper()).post {
            try {
                val active = activeNotifications
                if (active.isNullOrEmpty()) return@post
                PrivacyLog.d(INGEST_TAG, "scanning ${active.size} active notification(s)")
                active.forEach { sbn ->
                    IngestPlugin.processNotification(
                        applicationContext,
                        sbn,
                        fromActiveScan = true,
                    )
                }
            } catch (e: Exception) {
                PrivacyLog.w(INGEST_TAG, "active notification scan failed", e)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        IngestPlugin.processNotification(applicationContext, sbn)
    }
}
