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
            // M1029: one sender can emit independent financial messages
            // within the same broadcast. Group only PDUs sharing sender,
            // service-center timestamp and SMSC, preserving PDU order.
            // 3GPP/3GPP2 multipart UDH on real devices remains an acceptance
            // scenario; no cross-timestamp text is silently concatenated.
            val bySenderAndTimestamp = linkedMapOf<Triple<String, Long, String>, StringBuilder>()
            for (sms in incoming) {
                val sender = sms.displayOriginatingAddress ?: continue
                val identity = Triple(sender, sms.timestampMillis, sms.serviceCenterAddress ?: "")
                bySenderAndTimestamp.getOrPut(identity) { StringBuilder() }
                    .append(sms.displayMessageBody ?: "")
            }
            // M1018 / #735: first persist every accepted SMS, then request
            // one successor for this broadcast. Multiple senders must not
            // create multiple expensive FlutterEngine jobs.
            var shouldEnqueue = false
            for ((messageKey, parts) in bySenderAndTimestamp) {
                val sender = messageKey.first
                val receivedAt = messageKey.second
                if (WaffraAutoSmsStore.offer(context, sender, parts.toString(), receivedAt)) {
                    shouldEnqueue = true
                }
            }
            // M1019: full queue preserves the native inbox history marker.
            // Wake worker to drain verified entries and attempt bounded replay.
            if (shouldEnqueue || WaffraAutoSmsStore.capacityRecoveryNeeded(context))
                WaffraAutoSmsWorker.enqueue(context)
        } catch (_: Exception) {
            // Fail closed: neither text, sender, nor exception is logged.
        }
    }
}
