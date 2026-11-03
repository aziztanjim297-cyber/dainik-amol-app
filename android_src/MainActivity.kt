package com.aziztanjim.dainikamol

import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "dainik_amol/alarm"

    override fun onResume() {
        super.onResume()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(AlarmManager::class.java)
            if (alarmManager.canScheduleExactAlarms()) {
                AlarmScheduler.restore(this)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Number>("id")?.toInt()
                    val title = call.argument<String>("title")
                    val timestamp = call.argument<Number>("timestamp")?.toLong()

                    if (id == null || title == null || timestamp == null) {
                        result.error("INVALID_ARGS", "Alarm details missing", null)
                    } else {
                        AlarmScheduler.schedule(this, id, title, timestamp)
                        result.success(null)
                    }
                }

                "cancelAlarm" -> {
                    val id = call.argument<Number>("id")?.toInt()
                    if (id != null) AlarmScheduler.cancel(this, id)
                    result.success(null)
                }

                "canScheduleExactAlarms" -> {
                    val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                        getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
                    result.success(allowed)
                }

                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }

                "startTestAlarm" -> {
                    startAlarmService("অ্যালার্ম পরীক্ষা", -1)
                    result.success(null)
                }

                "stopAlarm" -> {
                    stopService(Intent(this, AlarmRingingService::class.java))
                    result.success(null)
                }

                "isAlarmRinging" -> {
                    val active = getSharedPreferences(
                        "dainik_alarm_state",
                        MODE_PRIVATE
                    ).getBoolean("ringing", false)
                    result.success(active)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startAlarmService(title: String, id: Int) {
        val intent = Intent(this, AlarmRingingService::class.java)
            .putExtra("alarm_title", title)
            .putExtra("alarm_id", id)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
