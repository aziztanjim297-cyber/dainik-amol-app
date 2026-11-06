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

    fun updateLanguage(context: Context, language: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(IDS, emptySet())?.toList() ?: emptyList()
        val now = System.currentTimeMillis()

        for (value in ids) {
            val id = value.toIntOrNull() ?: continue
            val time = prefs.getLong("time_$id", 0L)
            if (time <= now) continue

            val slot = id % 10
            val title = when (slot) {
                0 -> if (language == "ar") "منبه التهجد (قبل الفجر)" else if (language == "en") "Tahajjud Alarm (Before Fajr)" else "তাহাজ্জুদ অ্যালার্ম (ফজরের পূর্বে)"
                1 -> if (language == "ar") "منبه صلاة الفجر" else if (language == "en") "Fajr Prayer Alarm" else "ফজরের নামাজ অ্যালার্ম"
                3 -> if (language == "ar") "منبه صلاة الظهر" else if (language == "en") "Dhuhr Prayer Alarm" else "যোহরের নামাজ অ্যালার্ম"
                4 -> if (language == "ar") "منبه صلاة العصر" else if (language == "en") "Asr Prayer Alarm" else "আসরের নামাজ অ্যালার্ম"
                5 -> if (language == "ar") "منبه صلاة المغرب" else if (language == "en") "Maghrib Prayer Alarm" else "মাগরিবের নামাজ অ্যালার্ম"
                6 -> if (language == "ar") "منبه صلاة العشاء" else if (language == "en") "Isha Prayer Alarm" else "ইশার নামাজ অ্যালার্ম"
                else -> continue
            }

            prefs.edit().putString("title_$id", title).apply()
            schedulePendingIntent(context, id, title, time)
        }
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
