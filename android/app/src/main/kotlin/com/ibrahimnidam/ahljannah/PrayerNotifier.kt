package com.ibrahimnidam.ahljannah

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object PrayerNotifier {
    const val CHANNEL_ADHAN = "prayer_adhan_playback_v1"
    const val CHANNEL_REMINDER = "prayer_reminder_native_v1"
    const val NOTIFICATION_ADHAN = 9001

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val alarmAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        val adhan = NotificationChannel(
            CHANNEL_ADHAN,
            "Adhan",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Prayer time Adhan playback"
            setSound(null, alarmAttrs)
            enableVibration(true)
            setBypassDnd(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        val reminder = NotificationChannel(
            CHANNEL_REMINDER,
            "Prayer reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Upcoming prayer and Adhkar reminders"
            enableVibration(true)
        }

        manager.createNotificationChannel(adhan)
        manager.createNotificationChannel(reminder)
    }

    fun showReminder(context: Context, alarm: PrayerAlarm) {
        ensureChannels(context)
        val tap = PendingIntent.getActivity(
            context,
            alarm.id,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_REMINDER)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(alarm.title)
            .setContentText(alarm.body)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        NotificationManagerCompat.from(context).notify(alarm.id, notification)
    }

    fun adhanBuilder(context: Context, title: String, body: String, prayerKey: String): NotificationCompat.Builder {
        ensureChannels(context)
        val tap = PendingIntent.getActivity(
            context,
            NOTIFICATION_ADHAN,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = PrayerAlarmScheduler.ACTION_STOP_ADHAN
            putExtra(PrayerAlarmScheduler.EXTRA_PRAYER_KEY, prayerKey)
        }
        val stop = PendingIntent.getBroadcast(
            context,
            9002,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, CHANNEL_ADHAN)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(tap)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(0, "Stop Adhan", stop)
    }
}
