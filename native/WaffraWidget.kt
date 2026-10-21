package com.waffra.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.TypedValue
import android.widget.RemoteViews

/** Compact 1x1 launcher widget. Explicit taps only; no SMS inbox permission. */
class WaffraWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        super.onUpdate(context, manager, ids)
        updateAll(context)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, WaffraWidget::class.java)
            val prefs = context.getSharedPreferences("waffra_widget", Context.MODE_PRIVATE)
            val balance = prefs.getString("balance", "0.00") ?: "0.00"
            val currency = prefs.getString("currency", "ريال") ?: "ريال"
            val hidden = prefs.getBoolean("hidden", false)
            val negative = prefs.getBoolean("negative", false)
            val color = if (negative && !hidden) Color.rgb(255, 134, 134)
                        else Color.rgb(187, 245, 215)
            val fontSize = when {
                balance.length >= 14 -> 9.0f
                balance.length >= 11 -> 10.5f
                balance.length >= 9 -> 12.0f
                else -> 15.0f
            }
            val intent = Intent(context, WaffraQuickActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val pending = PendingIntent.getActivity(
                context, 1340, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            for (id in manager.getAppWidgetIds(component)) {
                val view = RemoteViews(context.packageName, R.layout.waffra_widget)
                view.setTextViewText(R.id.widget_balance, balance)
                view.setTextViewText(R.id.widget_currency, currency)
                view.setTextColor(R.id.widget_balance, color)
                view.setTextViewTextSize(R.id.widget_balance, TypedValue.COMPLEX_UNIT_SP, fontSize)
                view.setOnClickPendingIntent(R.id.waffra_widget_root, pending)
                manager.updateAppWidget(id, view)
            }
        }
    }
}
