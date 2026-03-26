package com.example.bebeu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetSmallProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val openApp = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
        )
        val addWater = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("homeWidget://addwater"),
        )

        val intake = widgetData.getInt("currentIntake", 0)
        val goal = widgetData.getInt("goal", 2000)
        val progress = widgetData.getInt("progressPercent", 0).coerceIn(0, 100)
        val fmt = Regex("(\\d)(?=(\\d{3})+(?!\\d))")
        val intakeStr = intake.toString().replace(fmt) { "${it.groupValues[1]}." }
        val goalStr = goal.toString().replace(fmt) { "${it.groupValues[1]}." }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_small).apply {
                setTextViewText(R.id.widget_percent, "$progress%")
                setTextViewText(R.id.widget_intake_line, "$intakeStr / $goalStr ml")

                setViewVisibility(R.id.widget_image, View.GONE)
                setViewVisibility(R.id.widget_default, View.VISIBLE)

                setOnClickPendingIntent(R.id.widget_open_block, openApp)
                setOnClickPendingIntent(R.id.widget_add_area, addWater)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
