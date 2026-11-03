package com.waffra.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat

/** Never say "saved" until the authenticated finance writer confirms it. */
object WaffraAutoSmsNotifications {
    private const val channel = "waffra_sms_finance_v1"
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
                description = "إشعارات تسجيل العمليات البنكية تلقائيًا"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
    }

    fun notifySaved(context: Context, fingerprint: String, income: Boolean,
                    amount: String, linkedBudget: Boolean): Boolean {
        if (!canNotify(context) || !Regex("^[a-f0-9]{64}$").matches(fingerprint))
            return false
        ensureChannel(context)
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(context, 710,
            open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        // Sensitive amount and merchant are suppressed on locked devices.
        val title = if (income) "وفرة — تم تسجيل دخل" else "وفرة — تم تسجيل مصروف"
        val message = if (amount.isNotEmpty())
            "$amount ر.س • " + if (linkedBudget) "مربوط بميزانية" else "بدون ميزانية"
            else "تم تسجيل عملية مالية"
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(NotificationCompat.Builder(context, channel)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("وفرة — تم تسجيل عملية مالية")
                .setContentText("افتح وفرة للاطلاع على التفاصيل")
                .build())
            .setAutoCancel(true).setContentIntent(pending).build()
        manager(context).notify(fingerprint.take(8).toLong(16).toInt(), notification)
        return true
    }

    fun notifyReview(context: Context, fingerprint: String): Boolean {
        if (!canNotify(context) || !Regex("^[a-f0-9]{64}$").matches(fingerprint))
            return false
        if (!WaffraAutoSmsStore.claimReviewNotification(context, fingerprint))
            return false
        ensureChannel(context)
        val pending = PendingIntent.getActivity(context, 711,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager(context).notify(fingerprint.take(8).toLong(16).toInt(),
            NotificationCompat.Builder(context, channel)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("وفرة — عملية تحتاج مراجعة")
                .setContentText("افتح التطبيق لمراجعة رسالة مالية جديدة")
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setAutoCancel(true).setContentIntent(pending).build())
        return true
    }
}
