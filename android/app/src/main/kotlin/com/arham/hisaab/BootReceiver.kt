package com.arham.hisaab

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService

/**
 * Restarts capture monitoring after reboot or app update.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (!IngestPlugin.shouldRunCaptureMonitor(context)) return
                PrivacyLog.d("HisaabIngest", "Boot/update — restarting capture pipeline")
                if (IngestPlugin.shouldRunKeepAlive(context)) {
                    IngestKeepAliveService.start(context)
                }
                // Drain any queued captures; full inbox/shade rescan stays an app-open failsafe.
                BackgroundIngestRunner.schedule(context, rescan = false)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                    IngestPlugin.isNotificationAccessEnabled(context)
                ) {
                    NotificationListenerService.requestRebind(
                        ComponentName(context, NotificationCaptureService::class.java),
                    )
                }
            }
        }
    }
}
