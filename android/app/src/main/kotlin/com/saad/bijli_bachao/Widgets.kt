package com.saad.bijli_bachao

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Shared drawing for the home-screen widgets. The app writes the values
 * (HomeWidgetSync in Dart) after every reading, bill or rates change; the
 * widgets redraw every few hours too, and work out "days left" themselves
 * so it stays right between app opens.
 */
object WidgetDraw {
    /** Below this the widget uses its small layout. */
    private const val SMALL_W = 170
    private const val SMALL_H = 100

    fun color(d: SharedPreferences, key: String): Int =
        try {
            Color.parseColor(d.getString(key, "#F5B700") ?: "#F5B700")
        } catch (e: IllegalArgumentException) {
            Color.parseColor("#F5B700")
        }

    /** "10 days left", from the cycle end date the app saved. Empty when unknown. */
    fun daysLeft(d: SharedPreferences): String {
        val end = d.getString("cycleEnd", "") ?: ""
        if (end.isEmpty()) return ""
        val days = try {
            ChronoUnit.DAYS.between(LocalDate.now(), LocalDate.parse(end)).coerceAtLeast(0)
        } catch (e: Exception) {
            return ""
        }
        val fmt = if (days == 1L) d.getString("dayFmt", "{0} day left") else d.getString("daysFmt", "{0} days left")
        return (fmt ?: "{0} days left").replace("{0}", days.toString())
    }

    fun open(context: Context, uri: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    /** Tints a progress bar with the status colour (Android 12+). */
    fun tint(views: RemoteViews, id: Int, color: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorStateList(id, "setProgressTintList", ColorStateList.valueOf(color))
        }
    }

    /**
     * Small and medium layouts: on Android 12+ the launcher picks by size
     * as the user resizes; before that, by the size the widget has now.
     */
    fun update(
        manager: AppWidgetManager,
        id: Int,
        small: () -> RemoteViews,
        medium: () -> RemoteViews,
    ) {
        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            RemoteViews(
                mapOf(
                    SizeF(110f, 40f) to small(),
                    SizeF(SMALL_W.toFloat(), SMALL_H.toFloat()) to medium(),
                ),
            )
        } else {
            val o: Bundle = manager.getAppWidgetOptions(id)
            val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            if (w < SMALL_W || h < SMALL_H) small() else medium()
        }
        manager.updateAppWidget(id, views)
    }
}

/** Redraws when the user resizes (needed before Android 12). */
abstract class ResizableWidget : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), data)
    }
}

/** Bill this month: estimated bill, units against the slab limit, days left. */
class BillWidgetProvider : ResizableWidget() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val d = widgetData
        val status = WidgetDraw.color(d, "statusColor")
        val tap = WidgetDraw.open(context, "bijli://home")
        for (id in appWidgetIds) {
            WidgetDraw.update(
                appWidgetManager, id,
                small = {
                    RemoteViews(context.packageName, R.layout.bill_widget_small).apply {
                        setTextViewText(R.id.bill_amount, d.getString("bill", "—"))
                        setTextViewText(R.id.bill_units, d.getString("billUnitsShort", ""))
                        setOnClickPendingIntent(R.id.widget_root, tap)
                    }
                },
                medium = {
                    RemoteViews(context.packageName, R.layout.bill_widget).apply {
                        setTextViewText(R.id.bill_title, d.getString("billTitle", "Bill this month"))
                        setTextViewText(R.id.bill_amount, d.getString("bill", "—"))
                        setTextViewText(R.id.bill_units, d.getString("billUnits", ""))
                        setTextViewText(R.id.bill_status, d.getString("status", ""))
                        setTextColor(R.id.bill_status, status)
                        setProgressBar(R.id.bill_progress, 100, d.getInt("progress", 0), false)
                        WidgetDraw.tint(this, R.id.bill_progress, status)
                        val days = WidgetDraw.daysLeft(d)
                        val line = d.getString("billLine", "") ?: ""
                        setTextViewText(R.id.bill_days, listOf(days, line).filter { it.isNotEmpty() }.joinToString(" · "))
                        setOnClickPendingIntent(R.id.widget_root, tap)
                    }
                },
            )
        }
    }
}

/** Daily budget: units a day to stay under the slab, recent use, Add reading. */
class BudgetWidgetProvider : ResizableWidget() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val d = widgetData
        val color = WidgetDraw.color(d, "budgetColor")
        val tap = WidgetDraw.open(context, "bijli://home")
        val add = WidgetDraw.open(context, "bijli://add_reading")
        for (id in appWidgetIds) {
            WidgetDraw.update(
                appWidgetManager, id,
                small = {
                    RemoteViews(context.packageName, R.layout.budget_widget_small).apply {
                        setTextViewText(R.id.budget_value, d.getString("budget", "—"))
                        setTextViewText(R.id.budget_of, d.getString("budgetOf", ""))
                        setOnClickPendingIntent(R.id.widget_root, tap)
                        setOnClickPendingIntent(R.id.budget_add, add)
                    }
                },
                medium = {
                    RemoteViews(context.packageName, R.layout.budget_widget).apply {
                        setTextViewText(R.id.budget_title, d.getString("budgetTitle", "Daily budget"))
                        setTextViewText(R.id.budget_days, WidgetDraw.daysLeft(d))
                        setTextViewText(R.id.budget_value, d.getString("budget", "—"))
                        setTextViewText(R.id.budget_of, d.getString("budgetOf", ""))
                        setTextViewText(R.id.budget_line, d.getString("budgetLine", ""))
                        setTextColor(R.id.budget_line, color)
                        setProgressBar(R.id.budget_progress, 100, d.getInt("budgetProgress", 0), false)
                        WidgetDraw.tint(this, R.id.budget_progress, color)
                        setTextViewText(R.id.budget_add, d.getString("addReading", "+ Add reading"))
                        setOnClickPendingIntent(R.id.widget_root, tap)
                        setOnClickPendingIntent(R.id.budget_add, add)
                    }
                },
            )
        }
    }
}
