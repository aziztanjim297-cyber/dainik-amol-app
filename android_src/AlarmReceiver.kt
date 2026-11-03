package com.aziztanjim.dainikamol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("alarm_id", 0)
        val title = intent.getStringExtra("alarm_title") ?: "নামাজের অ্যালার্ম"
        AlarmScheduler.markTriggered(context, id)

        val serviceIntent = Intent(context, AlarmRingingService::class.java)
            .putExtra("alarm_id", id)
            .putExtra("alarm_title", title)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
