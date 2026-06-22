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
        if (IngestPlugin.isHighConfidenceTxn(body)) return true

        val senderLower = sender.lowercase()
        val bodyLower = body.lowercase()
        val txnHints = listOf(
            "rs", "inr", "pkr", "usd", "eur", "gbp", "debited", "credited",
            "received", "spent", "paid", "upi", "transferred", "withdrawn",
            "deducted", "added", "\$", "€", "£", "txn id", "debit card",
        )
        val bankHints = listOf(
            "hdfc", "icici", "sbi", "axis", "kotak", "yes", "paytm", "phonepe",
            "gpay", "upi", "bank", "vm-", "jd-", "ax-", "bp-",
            "ubl", "hbl", "mcb", "alfalah", "jazz", "telenor", "easypaisa",
            "jazzcash", "sadapay", "nayapay", "meezan", "faysal", "brd",
            "chase", "wellsfargo", "citi", "paypal", "venmo", "wallet",
            "3737", "8623", "9080",
        )
        val senderMatch = bankHints.any { senderLower.contains(it) } ||
            isNumericShortCode(sender)
        val bodyMatch = txnHints.any { bodyLower.contains(it) }
        return senderMatch && bodyMatch
    }

    private fun isNumericShortCode(sender: String): Boolean {
        val compact = sender.filter { !it.isWhitespace() }
        if (compact.length !in 4..6) return false
        return compact.all { it.isDigit() }
    }
}
