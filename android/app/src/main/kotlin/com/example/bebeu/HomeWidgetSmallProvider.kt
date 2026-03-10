package com.example.bebeu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetSmallProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                val views = RemoteViews(context.packageName, R.layout.home_widget_small).apply {
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                    val imagePath = widgetData.getString("filename_small", null)
                    val bitmap = imagePath?.let { BitmapFactory.decodeFile(it) }
                    if (bitmap != null) {
                        setImageViewBitmap(R.id.widget_image, bitmap)
                        setViewVisibility(R.id.widget_image, View.VISIBLE)
                        setViewVisibility(R.id.widget_default, View.GONE)
                    } else {
                        setViewVisibility(R.id.widget_image, View.GONE)
                        setViewVisibility(R.id.widget_default, View.VISIBLE)
                        val progress = widgetData.getInt("progressPercent", 0).coerceIn(0, 100)
                        setTextViewText(R.id.widget_percent, "$progress%")
                    }
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                val views = RemoteViews(context.packageName, R.layout.home_widget_small).apply {
                    setOnClickPendingIntent(R.id.widget_container,
                        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
