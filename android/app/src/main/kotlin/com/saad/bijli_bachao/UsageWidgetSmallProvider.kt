package com.saad.bijli_bachao

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Small 2x1 widget: units so far and the status. Same data as UsageWidgetProvider. */
class UsageWidgetSmallProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.usage_widget_small).apply {
                setTextViewText(R.id.widget_units, widgetData.getString("units", "—"))
                setTextViewText(R.id.widget_of, widgetData.getString("of", "units"))
                setTextViewText(R.id.widget_status, widgetData.getString("status", ""))
                val color = widgetData.getString("statusColor", "#F5B700") ?: "#F5B700"
                setTextColor(R.id.widget_status, Color.parseColor(color))
                setProgressBar(R.id.widget_progress, 100, widgetData.getInt("progress", 0), false)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
