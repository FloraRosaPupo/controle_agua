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

class HomeWidgetLargeProvider : HomeWidgetProvider() {
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
        val quickAdd = widgetData.getInt("quickAddMl", 200).coerceIn(10, 2000)
        val displayPercent = if (goal > 0) {
            ((intake * 100L) / goal).toInt().coerceIn(0, 9999)
        } else {
            0
        }
        val barProgress = minOf(100, displayPercent)
        val fmt = Regex("(\\d)(?=(\\d{3})+(?!\\d))")
        val intakeStr = intake.toString().replace(fmt) { "${it.groupValues[1]}." }
        val goalStr = goal.toString().replace(fmt) { "${it.groupValues[1]}." }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_large).apply {
                setTextViewText(R.id.widget_intake, "$intakeStr ml / $goalStr ml")
                setTextViewText(R.id.widget_percent, "$displayPercent%")
                setTextViewText(R.id.widget_quick_add_label, "+ $quickAdd ml")
                setProgressBar(R.id.widget_progress, 100, barProgress, false)

                setViewVisibility(R.id.widget_image, View.GONE)
                setViewVisibility(R.id.widget_default, View.VISIBLE)

                setOnClickPendingIntent(R.id.widget_header_row, openApp)
                setOnClickPendingIntent(R.id.widget_stats_block, openApp)
                setOnClickPendingIntent(R.id.widget_add_area, addWater)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
