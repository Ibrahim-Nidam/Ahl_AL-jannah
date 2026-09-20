package com.ibrahimnidam.ahljannah

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            PrayerAlarmScheduler.ACTION_STOP_ADHAN -> {
                AdhanPlaybackService.stop(context)
            }
            PrayerAlarmScheduler.ACTION_RESCHEDULE -> {
                PrayerAlarmScheduler.applyFromDisk(context)
            }
            PrayerAlarmScheduler.ACTION_FIRE, null -> {
                handleFire(context, intent)
            }
            else -> {
                if (intent.hasExtra(PrayerAlarmScheduler.EXTRA_TRIGGER)) {
                    handleFire(context, intent)
                }
            }
        }
    }

    private fun handleFire(context: Context, intent: Intent) {
        val pending = goAsync()
        try {
            val triggerAt = intent.getLongExtra(PrayerAlarmScheduler.EXTRA_TRIGGER, 0L)
            val kind = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_KIND) ?: "adhan"
            val title = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_TITLE) ?: "Prayer"
            val body = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_BODY) ?: ""
            val prayerKey = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_PRAYER_KEY) ?: ""
            val sound = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_SOUND) ?: "none"
            val id = intent.getIntExtra(PrayerAlarmScheduler.EXTRA_ID, 0)

            PrayerAlarmScheduler.scheduleUpcoming(context)

            val lateness = System.currentTimeMillis() - triggerAt
            val maxLate = if (kind == "adhan") MAX_ADHAN_LATE_MS else MAX_REMINDER_LATE_MS
            if (triggerAt > 0 && lateness > maxLate) {
                Log.w(TAG, "Skipping stale $kind for $prayerKey (late ${lateness}ms)")
                return
            }

            if (kind == "adhan" && sound != "none") {
                val service = Intent(context, AdhanPlaybackService::class.java).apply {
                    putExtra(PrayerAlarmScheduler.EXTRA_TITLE, title)
                    putExtra(PrayerAlarmScheduler.EXTRA_BODY, body)
                    putExtra(PrayerAlarmScheduler.EXTRA_PRAYER_KEY, prayerKey)
                    putExtra(PrayerAlarmScheduler.EXTRA_SOUND, sound)
                }
                ContextCompat.startForegroundService(context, service)
            } else {
                PrayerNotifier.showReminder(
                    context,
                    PrayerAlarm(
                        id = id,
                        triggerAtMillis = triggerAt,
                        prayerKey = prayerKey,
                        kind = kind,
                        title = title,
                        body = body,
                        sound = sound,
                        group = "prayer",
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle prayer alarm", e)
        } finally {
            pending.finish()
        }
    }

    companion object {
        private const val TAG = "PrayerAlarmReceiver"
        private const val MAX_ADHAN_LATE_MS = 4 * 60 * 1000L
        private const val MAX_REMINDER_LATE_MS = 12 * 60 * 1000L
    }
}

class PrayerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            PrayerAlarmScheduler.applyFromDisk(context)
        }
    }
}

class PrayerAlarmRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        PrayerAlarmScheduler.applyFromDisk(context)
    }
}
