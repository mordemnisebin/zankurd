package com.zankurd.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Ana ekran widget'ı. Görünür metinlerin hepsi Dart'tan gelir
 * (lib/src/services/home_widget_sync.dart); burada çeviri yoktur.
 * Dokunuş uygulamayı açar.
 */
class ZanKurdWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val hasData = widgetData.contains("updatedAt")
        val streak = widgetData.getInt("streak", 0)
        val prompt = widgetData.getString("dailyPrompt", "") ?: ""
        val labelStreak = widgetData.getString("labelStreak", "") ?: ""
        val labelUnit = widgetData.getString("labelUnit", "") ?: ""
        val labelDaily = widgetData.getString("labelDaily", "") ?: ""

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.zankurd_widget).apply {
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                if (hasData) {
                    setViewVisibility(R.id.widget_content, View.VISIBLE)
                    setViewVisibility(R.id.widget_empty, View.GONE)
                    setTextViewText(R.id.widget_streak, streak.toString())
                    setTextViewText(
                        R.id.widget_streak_label,
                        if (labelUnit.isEmpty()) labelStreak else "$labelStreak · $labelUnit",
                    )
                    setTextViewText(R.id.widget_daily_label, labelDaily.uppercase())
                    setTextViewText(R.id.widget_prompt, prompt)
                    setViewVisibility(
                        R.id.widget_daily,
                        if (prompt.isEmpty()) View.GONE else View.VISIBLE,
                    )
                } else {
                    setViewVisibility(R.id.widget_content, View.GONE)
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
