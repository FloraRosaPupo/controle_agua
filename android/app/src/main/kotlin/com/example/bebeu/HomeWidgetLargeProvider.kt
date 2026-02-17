package com.example.bebeu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetLargeProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            val views = RemoteViews(context.packageName, R.layout.home_widget_large).apply {
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                val imagePath = widgetData.getString("filename", null)
                val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_image, bitmap)
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.widget_default, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.widget_default, View.VISIBLE)
                    // Atualiza com dados salvos, se houver
                    val intake = widgetData.getInt("currentIntake", 0)
                    val goal = widgetData.getInt("goal", 2000)
                    val progress = widgetData.getInt("progressPercent", 0)
                    val fmt = Regex("(\\d)(?=(\\d{3})+(?!\\d))")
                    val intakeStr = intake.toString().replace(fmt) { it.groupValues[1] + "." }
                    val goalStr = goal.toString().replace(fmt) { it.groupValues[1] + "." }
                    setTextViewText(R.id.widget_intake, "$intakeStr ml / $goalStr ml")
                    setTextViewText(R.id.widget_percent, "$progress%")
                    setProgressBar(R.id.widget_progress, 100, progress, false)
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
