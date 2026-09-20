package com.ibrahimnidam.ahljannah

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "applySchedule" -> {
                        PrayerAlarmScheduler.applyFromDisk(applicationContext)
                        result.success(true)
                    }
                    "cancelAll" -> {
                        PrayerAlarmScheduler.cancelAll(applicationContext)
                        result.success(true)
                    }
                    "stopAdhan" -> {
                        AdhanPlaybackService.stop(applicationContext)
                        result.success(true)
                    }
                    "isAdhanPlaying" -> {
                        result.success(AdhanPlaybackService.isPlaying)
                    }
                    "playingPrayerKey" -> {
                        result.success(AdhanPlaybackService.currentPrayerKey)
                    }
                    "canScheduleExactAlarms" -> {
                        result.success(PrayerAlarmScheduler.canScheduleExactAlarms(applicationContext))
                    }
                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
            }
        }
    }

    companion object {
        const val CHANNEL = "com.ibrahimnidam.ahljannah/prayer_alarms"
    }
}
