package com.example.spend_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (sms in messages) {
            val sender = sms.originatingAddress ?: continue
            val body = sms.messageBody ?: continue
            if (!isLikelyTransaction(sender, body)) continue

            IngestPlugin.deliver(
                context.applicationContext,
                mapOf(
                    "source" to "sms",
                    "text" to body,
                    "sender" to sender,
                    "timestamp" to sms.timestampMillis,
                ),
            )
        }
    }

    private fun isLikelyTransaction(sender: String, body: String): Boolean {
        if (IngestPlugin.looksLikeTransaction(body)) return true

        val senderLower = sender.lowercase()
        val bodyLower = body.lowercase()
        val bankHints = listOf(
            "hdfc", "icici", "sbi", "axis", "kotak", "yes", "paytm", "phonepe",
            "gpay", "upi", "bank", "vm-", "jd-", "ax-", "bp-",
            "ubl", "hbl", "mcb", "alfalah", "jazz", "telenor", "easypaisa",
            "jazzcash", "sadapay", "nayapay", "meezan", "faysal", "brd",
        )
        val txnHints = listOf(
            "rs", "inr", "pkr", "debited", "credited", "spent", "paid", "upi",
            "transferred", "withdrawn", "deducted",
        )
        val senderMatch = bankHints.any { senderLower.contains(it) }
        val bodyMatch = txnHints.any { bodyLower.contains(it) }
        return senderMatch && bodyMatch
    }
}
