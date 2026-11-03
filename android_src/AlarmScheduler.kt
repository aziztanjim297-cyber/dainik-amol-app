package com.aziztanjim.dainikamol

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AlarmScheduler {
    private const val PREFS = "dainik_alarm_schedule"
    private const val IDS = "scheduled_ids"

    fun schedule(context: Context, id: Int, title: String, time: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toMutableSet() ?: mutableSetOf()
        ids.add(id.toString())
        prefs.edit()
            .putStringSet(IDS, ids)
            .putLong("time_$id", time)
            .putString("title_$id", title)
            .apply()
        schedulePendingIntent(context, id, title, time)
    }

    fun cancel(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toMutableSet() ?: mutableSetOf()
        ids.remove(id.toString())
        prefs.edit()
            .putStringSet(IDS, ids)
            .remove("time_$id")
            .remove("title_$id")
            .apply()

        val pending = pendingIntent(context, id, "", 0L)
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    fun markTriggered(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toMutableSet() ?: mutableSetOf()
        ids.remove(id.toString())
        prefs.edit()
            .putStringSet(IDS, ids)
            .remove("time_$id")
            .remove("title_$id")
            .apply()
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toList() ?: emptyList()
        val now = System.currentTimeMillis()
        for (value in ids) {
            val id = value.toIntOrNull() ?: continue
            val time = prefs.getLong("time_$id", 0L)
            val title = prefs.getString("title_$id", "নামাজের অ্যালার্ম") ?: "নামাজের অ্যালার্ম"
            if (time > now) {
                schedulePendingIntent(context, id, title, time)
            } else {
                markTriggered(context, id)
            }
        }
    }

    private fun schedulePendingIntent(context: Context, id: Int, title: String, time: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(context, id, title, time)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            return
        }

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            time,
            pending
        )
    }

    private fun pendingIntent(context: Context, id: Int, title: String, time: Long): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java)
            .putExtra("alarm_id", id)
            .putExtra("alarm_title", title)
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
