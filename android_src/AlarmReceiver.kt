package com.aziztanjim.dainikamol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("alarm_id", 0)
        val title = intent.getStringExtra("alarm_title") ?: "নামাজের অ্যালার্ম"

        android.util.Log.i(
            "DainikAmolAlarm",
            "ALARM_RECEIVER_TRIGGERED id=$id title=$title"
        )

        AlarmScheduler.markTriggered(context, id)

        val serviceIntent = Intent(context, AlarmRingingService::class.java)
            .putExtra("alarm_id", id)
            .putExtra("alarm_title", title)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            android.util.Log.i(
                "DainikAmolAlarm",
                "ALARM_SERVICE_START_REQUESTED id=$id"
            )
        } catch (e: Exception) {
            android.util.Log.e(
                "DainikAmolAlarm",
                "ALARM_SERVICE_START_FAILED id=$id",
                e
            )
        }
    }
}
