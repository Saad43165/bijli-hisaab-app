package com.saad.bijli_bachao

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

/** Units this month against the slab limit. Small: units and status; bigger: plus the budget line. */
class UsageWidgetProvider : ResizableWidget() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            WidgetDraw.update(
                appWidgetManager, id,
                small = { UsageViews.small(context, widgetData) },
                medium = { UsageViews.medium(context, widgetData) },
            )
        }
    }
}

object UsageViews {
    fun small(context: Context, d: SharedPreferences) =
        RemoteViews(context.packageName, R.layout.usage_widget_small).apply { common(context, d) }

    fun medium(context: Context, d: SharedPreferences) =
        RemoteViews(context.packageName, R.layout.usage_widget).apply {
            common(context, d)
            setTextViewText(R.id.widget_meter, d.getString("meter", "Bijli Hisaab"))
            setTextViewText(R.id.widget_line, d.getString("line", "Open the app to add a reading"))
        }

    private fun RemoteViews.common(context: Context, d: SharedPreferences) {
        val status = WidgetDraw.color(d, "statusColor")
        setTextViewText(R.id.widget_units, d.getString("units", "—"))
        setTextViewText(R.id.widget_of, d.getString("of", "units"))
        setTextViewText(R.id.widget_status, d.getString("status", ""))
        setTextColor(R.id.widget_status, status)
        setProgressBar(R.id.widget_progress, 100, d.getInt("progress", 0), false)
        WidgetDraw.tint(this, R.id.widget_progress, status)
        setOnClickPendingIntent(R.id.widget_root, WidgetDraw.open(context, "bijli://home"))
    }
}
