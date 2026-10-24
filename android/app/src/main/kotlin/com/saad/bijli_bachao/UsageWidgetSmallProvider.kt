package com.saad.bijli_bachao

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences

/** Small 2x1 widget: units so far and the status. Same data as UsageWidgetProvider. */
class UsageWidgetSmallProvider : es.antonborri.home_widget.HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, UsageViews.small(context, widgetData))
        }
    }
}
