package com.example.spend_tracker

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.util.Log

/**
 * Restarts capture monitoring after reboot or app update.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (!IngestPlugin.isNotificationAccessEnabled(context)) return
                Log.d("HisaabIngest", "Boot/update — restarting capture pipeline")
                IngestKeepAliveService.start(context)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    NotificationListenerService.requestRebind(
                        ComponentName(context, NotificationCaptureService::class.java),
                    )
                }
            }
        }
    }
}
