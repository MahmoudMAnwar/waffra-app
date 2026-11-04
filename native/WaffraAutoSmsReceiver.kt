package com.waffra.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives ONLY Android's SMS_RECEIVED broadcast after the owner has explicitly
 * consented. Never sends a message, forwards raw SMS to a server, or performs a
 * finance write from a background receiver. Stages candidate messages encrypted
 * for the existing verified Waffra bank-SMS review/commit route.
 */
class WaffraAutoSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!WaffraAutoSmsStore.enabled(context)) return
        try {
            val incoming = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (incoming.isNullOrEmpty()) return
            val bySender = linkedMapOf<String, StringBuilder>()
            val receivedDates = mutableMapOf<String, Long>()
            for (sms in incoming) {
                val sender = sms.displayOriginatingAddress ?: continue
                bySender.getOrPut(sender) { StringBuilder() }
                    .append(sms.displayMessageBody ?: "")
                receivedDates[sender] = minOf(
                    receivedDates[sender] ?: sms.timestampMillis,
                    sms.timestampMillis
                )
            }
            for ((sender, parts) in bySender) {
                if (WaffraAutoSmsStore.offer(context, sender, parts.toString(),
                        receivedDates[sender] ?: System.currentTimeMillis())) {
                    WaffraAutoSmsWorker.enqueue(context)
                }
            }
        } catch (_: Exception) {
            // Fail closed: neither text, sender, nor exception is logged.
        }
    }
}
