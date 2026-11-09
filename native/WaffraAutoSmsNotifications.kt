package com.waffra.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * M620–M621: short, monochrome, privacy-preserving system notices. A proposed
 * SMS is never described as booked. Only the verified SQLCipher writer can
 * request a "saved" notice, after proving the exact ledger record exists.
 */
object WaffraAutoSmsNotifications {
    const val OPEN_ACTION = "com.waffra.app.OPEN_FINANCE_NOTIFICATION"
    const val EXTRA_DESTINATION = "waffra.finance.destination"
    const val EXTRA_SMS_ID = "waffra.finance.sms_id"
    const val EXTRA_ENTRY_ID = "waffra.finance.entry_id"

    private const val channel = "waffra_sms_finance_v1"
    private val validFingerprint = Regex("^[a-f0-9]{64}$")

    fun canNotify(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(context).createNotificationChannel(NotificationChannel(
                channel, "وفرة — العمليات البنكية",
                NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "إشعارات المراجعة وعمليات الحفظ المؤكدة"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
    }

    /**
     * Each notification owns its own immutable explicit activity intent.
     * Fingerprint and persisted entry ID are opaque, not message/bank details.
     * Distinct action URI prevents PendingIntent reuse between SMS candidates.
     */
    private fun openPending(
        context: Context, fingerprint: String, destination: String,
        entryId: String? = null
    ): PendingIntent {
        val open = Intent(context, MainActivity::class.java).apply {
            action = OPEN_ACTION
            data = Uri.parse("waffra-finance://$destination/$fingerprint")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_DESTINATION, destination)
            putExtra(EXTRA_SMS_ID, fingerprint)
            if (entryId != null) putExtra(EXTRA_ENTRY_ID, entryId)
        }
        return PendingIntent.getActivity(context,
            fingerprint.take(8).toLong(16).toInt(), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun notifySaved(context: Context, fingerprint: String, income: Boolean,
                    amount: String, linkedBudget: Boolean, entryId: String): Boolean {
        if (!canNotify(context) || !validFingerprint.matches(fingerprint) ||
            entryId.isBlank() || entryId.length > 200 ||
            entryId.any { it.isISOControl() }) return false
        ensureChannel(context)
        val title = if (income) "وفرة — تم تسجيل دخل" else "وفرة — تم تسجيل مصروف"
        val message = if (amount.isNotEmpty())
            "$amount ر.س • " + if (linkedBudget) "مربوط بميزانية" else "بدون ميزانية"
            else "تم تسجيل عملية مالية"
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.waffra_notification_wallet)
            .setContentTitle(title)
            .setContentText(message)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(NotificationCompat.Builder(context, channel)
                .setSmallIcon(R.drawable.waffra_notification_wallet)
                .setContentTitle("وفرة — تم تسجيل عملية مالية")
                .setContentText("افتح وفرة للاطلاع على التفاصيل")
                .build())
            .setAutoCancel(true)
            .setContentIntent(openPending(context, fingerprint, "saved", entryId))
            .build()
        manager(context).notify(fingerprint.take(8).toLong(16).toInt(), notification)
        return true
    }

    fun notifyReview(context: Context, fingerprint: String,
                     suggestedKind: String = "uncertain"): Boolean {
        if (!canNotify(context) || !validFingerprint.matches(fingerprint))
            return false
        if (!WaffraAutoSmsStore.claimReviewNotification(context, fingerprint))
            return false
        ensureChannel(context)
        // Built-in, locally understood kind is still only a proposal.
        // Transfers always require the user's two verified accounts.
        val title = when (suggestedKind) {
            "income" -> "وفرة — دخل مقترح للمراجعة"
            "expense" -> "وفرة — مصروف مقترح للمراجعة"
            "transfer" -> "وفرة — تحويل مقترح للمراجعة"
            else -> "وفرة — عملية تحتاج مراجعة"
        }
        manager(context).notify(fingerprint.take(8).toLong(16).toInt(),
            NotificationCompat.Builder(context, channel)
                .setSmallIcon(R.drawable.waffra_notification_wallet)
                .setContentTitle(title)
                .setContentText("افتح وفرة لمراجعة العملية وتأكيدها أو استبعادها")
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setContentIntent(openPending(context, fingerprint, "review"))
                .build())
        return true
    }
}
