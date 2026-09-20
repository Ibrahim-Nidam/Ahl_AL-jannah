package com.ibrahimnidam.ahljannah

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat

class AdhanPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopAdhan()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(PrayerAlarmScheduler.EXTRA_TITLE) ?: "Adhan"
        val body = intent?.getStringExtra(PrayerAlarmScheduler.EXTRA_BODY) ?: ""
        val prayerKey = intent?.getStringExtra(PrayerAlarmScheduler.EXTRA_PRAYER_KEY) ?: ""
        val sound = intent?.getStringExtra(PrayerAlarmScheduler.EXTRA_SOUND) ?: "adhan"

        acquireWakeLock()
        val notification = PrayerNotifier.adhanBuilder(this, title, body, prayerKey).build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                PrayerNotifier.NOTIFICATION_ADHAN,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(PrayerNotifier.NOTIFICATION_ADHAN, notification)
        }

        isPlaying = true
        currentPrayerKey = prayerKey

        if (sound == "none") {
            return START_NOT_STICKY
        }

        play(sound)
        return START_NOT_STICKY
    }

    private fun play(sound: String) {
        stopPlayer()
        val mediaPlayer = MediaPlayer()
        player = mediaPlayer
        try {
            mediaPlayer.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setLegacyStreamType(AudioManager.STREAM_ALARM)
                    .build(),
            )
            if (!setDataSource(mediaPlayer, sound)) {
                Log.w(TAG, "Adhan asset missing ($sound), using default alarm ringtone")
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                mediaPlayer.setDataSource(this, uri)
            }
            mediaPlayer.setOnCompletionListener { stopAdhan() }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                stopAdhan()
                true
            }
            mediaPlayer.prepare()
            mediaPlayer.start()
            Log.i(TAG, "Adhan playback started ($sound)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play adhan", e)
            stopAdhan()
        }
    }

    private fun setDataSource(mediaPlayer: MediaPlayer, sound: String): Boolean {
        val rawName = sound.removeSuffix(".mp3")
        val rawId = resources.getIdentifier(rawName, "raw", packageName)
        if (rawId != 0) {
            val afd = resources.openRawResourceFd(rawId)
            mediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            return true
        }
        val candidates = listOf(
            "flutter_assets/assets/$rawName.mp3",
            "assets/$rawName.mp3",
        )
        for (path in candidates) {
            var afd: AssetFileDescriptor? = null
            try {
                afd = assets.openFd(path)
                mediaPlayer.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                return true
            } catch (_: Exception) {
                try {
                    afd?.close()
                } catch (_: Exception) {
                }
            }
        }
        return false
    }

    private fun stopAdhan() {
        isPlaying = false
        currentPrayerKey = null
        stopPlayer()
        releaseWakeLock()
        NotificationManagerCompat.from(this).cancel(PrayerNotifier.NOTIFICATION_ADHAN)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopPlayer() {
        try {
            player?.setOnCompletionListener(null)
            player?.setOnErrorListener(null)
            if (player?.isPlaying == true) player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ahljannah:adhan").apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    override fun onDestroy() {
        stopPlayer()
        releaseWakeLock()
        isPlaying = false
        currentPrayerKey = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AdhanPlaybackService"
        const val ACTION_STOP = "com.ibrahimnidam.ahljannah.STOP_ADHAN_SERVICE"

        @Volatile
        var isPlaying: Boolean = false
            private set

        @Volatile
        var currentPrayerKey: String? = null
            private set

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, AdhanPlaybackService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "stopService failed", e)
            }
        }
    }
}
