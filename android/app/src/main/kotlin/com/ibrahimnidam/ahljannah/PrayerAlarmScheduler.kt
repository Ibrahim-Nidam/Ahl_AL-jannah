package com.ibrahimnidam.ahljannah

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.io.File

object PrayerAlarmScheduler {
    const val ACTION_FIRE = "com.ibrahimnidam.ahljannah.PRAYER_ALARM_FIRE"
    const val ACTION_RESCHEDULE = "com.ibrahimnidam.ahljannah.RESCHEDULE_PRAYER_ALARMS"
    const val ACTION_STOP_ADHAN = "com.ibrahimnidam.ahljannah.STOP_ADHAN"

    const val EXTRA_ID = "id"
    const val EXTRA_TRIGGER = "triggerAtMillis"
    const val EXTRA_PRAYER_KEY = "prayerKey"
    const val EXTRA_KIND = "kind"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_SOUND = "sound"

    private const val TAG = "PrayerAlarmScheduler"
    private const val PREFS = "prayer_native_alarms"
    private const val KEY_SCHEDULED_IDS = "scheduled_ids"
    private const val UPCOMING_COUNT = 3

    fun alarmsFile(context: Context): File = File(context.filesDir, "prayer_alarms.json")

    fun applyFromDisk(context: Context) {
        val alarms = PrayerAlarm.readAll(alarmsFile(context))
        scheduleUpcoming(context, alarms)
        Log.i(TAG, "Applied ${alarms.size} stored alarms")
    }

    fun scheduleUpcoming(context: Context, all: List<PrayerAlarm>? = null) {
        val alarms = all ?: PrayerAlarm.readAll(alarmsFile(context))
        val now = System.currentTimeMillis()
        val upcoming = alarms
            .filter { it.triggerAtMillis > now + 1_500 }
            .sortedBy { it.triggerAtMillis }
            .take(UPCOMING_COUNT)

        cancelTracked(context)

        val ids = ArrayList<Int>(upcoming.size)
        for (alarm in upcoming) {
            setClockAlarm(context, alarm)
            ids.add(alarm.id)
        }
        saveTrackedIds(context, ids)
        Log.i(
            TAG,
            "Scheduled ${upcoming.size} clock alarms: " +
                upcoming.joinToString { "${it.kind}:${it.prayerKey}@${it.triggerAtMillis}" },
        )
    }

    fun cancelAll(context: Context) {
        cancelTracked(context)
        val file = alarmsFile(context)
        if (file.exists()) file.writeText("[]")
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun setClockAlarm(context: Context, alarm: PrayerAlarm) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = firePendingIntent(context, alarm)
        val triggerAt = alarm.triggerAtMillis

        try {
            val show = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                },
                pendingFlags(),
            )
            val info = AlarmManager.AlarmClockInfo(triggerAt, show)
            alarmManager.setAlarmClock(info, pending)
            return
        } catch (e: SecurityException) {
            Log.w(TAG, "setAlarmClock denied, falling back", e)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "exact alarm denied, using inexact allow-while-idle", e)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        }
    }

    private fun firePendingIntent(context: Context, alarm: PrayerAlarm): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_ID, alarm.id)
            putExtra(EXTRA_TRIGGER, alarm.triggerAtMillis)
            putExtra(EXTRA_PRAYER_KEY, alarm.prayerKey)
            putExtra(EXTRA_KIND, alarm.kind)
            putExtra(EXTRA_TITLE, alarm.title)
            putExtra(EXTRA_BODY, alarm.body)
            putExtra(EXTRA_SOUND, alarm.sound)
        }
        return PendingIntent.getBroadcast(context, alarm.id, intent, pendingFlags())
    }

    private fun cancelTracked(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in trackedIds(context)) {
            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply { action = ACTION_FIRE }
            val pending = PendingIntent.getBroadcast(context, id, intent, pendingFlags())
            alarmManager.cancel(pending)
            pending.cancel()
        }
        saveTrackedIds(context, emptyList())
    }

    private fun trackedIds(context: Context): List<Int> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SCHEDULED_IDS, "") ?: ""
        if (raw.isBlank()) return emptyList()
        return raw.split(',').mapNotNull { it.toIntOrNull() }
    }

    private fun saveTrackedIds(context: Context, ids: List<Int>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SCHEDULED_IDS, ids.joinToString(","))
            .apply()
    }

    private fun pendingFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }
}
