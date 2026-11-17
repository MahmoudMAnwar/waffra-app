package com.waffra.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.util.concurrent.Executors

/**
 * Receives ONLY Android's SMS_RECEIVED broadcast after the owner has explicitly
 * consented. Never sends a message, forwards raw SMS to a server, or performs a
 * finance write from a background receiver. Stages candidate messages encrypted
 * for the existing verified Waffra bank-SMS review/commit route.
 */
class WaffraAutoSmsReceiver : BroadcastReceiver() {
    // M1030: encrypted KeyStore/SharedPreferences I/O never blocks
    // BroadcastReceiver's main thread. The original SMS remains available
    // in Android's provider if the OS kills a long-running broadcast.
    companion object {
        private val smsIntakeExecutor = Executors.newSingleThreadExecutor { task ->
            Thread(task, "waffra-sms-intake")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val pending = goAsync()
        try {
            smsIntakeExecutor.execute {
                try {
                    if (!WaffraAutoSmsStore.enabled(context)) return@execute
                    val incoming = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    if (incoming.isNullOrEmpty()) return@execute
                    // M1029: only concatenate parts sharing sender, service
                    // center and SMS timestamp; unrelated SMS stay separate.
                    val bySenderAndTimestamp =
                        linkedMapOf<Triple<String, Long, String>, StringBuilder>()
                    for (sms in incoming) {
                        val sender = sms.displayOriginatingAddress ?: continue
                        val identity = Triple(
                            sender, sms.timestampMillis, sms.serviceCenterAddress ?: "")
                        bySenderAndTimestamp.getOrPut(identity) { StringBuilder() }
                            .append(sms.displayMessageBody ?: "")
                    }
                    var shouldEnqueue = false
                    for ((messageKey, parts) in bySenderAndTimestamp) {
                        val sender = messageKey.first
                        val receivedAt = messageKey.second
                        if (WaffraAutoSmsStore.offer(context, sender, parts.toString(), receivedAt)) {
                            shouldEnqueue = true
                        }
                    }
                    if (shouldEnqueue || WaffraAutoSmsStore.capacityRecoveryNeeded(context))
                        WaffraAutoSmsWorker.enqueue(context)
                } catch (_: Exception) {
                    // No raw SMS data, sender or exceptions logged.
                } finally { pending.finish() }
            }
        } catch (_: Exception) { pending.finish() }
    }
}
