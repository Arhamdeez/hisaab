package com.arham.hisaab

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Keeps the app process alive so the notification listener stays connected on
 * aggressive OEM builds (Samsung, Xiaomi, Oppo, etc.).
 */
class IngestKeepAliveService : Service() {
    private val periodicHandler = Handler(Looper.getMainLooper())
    private val periodicProcess: Runnable = object : Runnable {
        override fun run() {
            // Light battery check — only wake Flutter when something is actually queued.
            if (IngestPlugin.hasPendingCaptures(applicationContext)) {
                BackgroundIngestRunner.runNow(applicationContext, rescan = false)
            }
            periodicHandler.postDelayed(this, PERIODIC_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification(this))
        periodicHandler.removeCallbacks(periodicProcess)
        // First safety pass after 20 min, then every 2 hours — queue-only, no heavy rescan.
        periodicHandler.postDelayed(periodicProcess, FIRST_PERIODIC_MS)
        return START_STICKY
    }

    override fun onDestroy() {
        periodicHandler.removeCallbacks(periodicProcess)
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.arham.hisaab.STOP_KEEPALIVE"
        private const val NOTIFICATION_ID = 7001
        private const val CHANNEL_ID = "hisaab_capture_monitor"
        /** First background queue check — not immediate, to save boot battery. */
        private const val FIRST_PERIODIC_MS = 20L * 60L * 1000L
        /** Repeat queue check interval while the monitor service is alive. */
        private const val PERIODIC_MS = 2L * 60L * 60L * 1000L

        fun start(context: Context) {
            if (!IngestPlugin.shouldRunKeepAlive(context)) return
            val intent = Intent(context, IngestKeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, IngestKeepAliveService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(NotificationManager::class.java) ?: return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Payment monitoring",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Keeps HISAAB listening for bank and wallet alerts"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context): Notification {
            ensureChannel(context)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("HISAAB is monitoring payments")
                .setContentText("Capturing bank & wallet alerts in the background")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setContentIntent(pending)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        }
    }
}
