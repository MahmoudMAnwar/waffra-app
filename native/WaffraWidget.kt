package com.waffra.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Read-only, privacy-respecting balance widget. No SMS or bank permissions. */
class WaffraWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context, manager: AppWidgetManager, ids: IntArray
    ) {
        super.onUpdate(context, manager, ids)
        updateAll(context)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, WaffraWidget::class.java)
            val prefs = context.getSharedPreferences("waffra_widget", Context.MODE_PRIVATE)
            for (id in manager.getAppWidgetIds(component)) {
                val views = RemoteViews(context.packageName, R.layout.waffra_widget)
                views.setTextViewText(R.id.widget_balance, prefs.getString("balance", "—"))
                views.setTextViewText(R.id.widget_month_expense, prefs.getString("expenses", "—"))
                val openIntent = Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val openPending = PendingIntent.getActivity(
                    context, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val quickAddIntent = Intent(context, MainActivity::class.java)
                    .setAction("waffra.ADD_TRANSACTION")
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val addPending = PendingIntent.getActivity(
                    context, 1, quickAddIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.waffra_widget_root, openPending)
                views.setOnClickPendingIntent(R.id.waffra_widget_add, addPending)
                manager.updateAppWidget(id, views)
            }
        }
    }
}
