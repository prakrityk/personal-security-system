package com.example.safety_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BootReceiver.kt
 *
 * Restarts BackTapService automatically after:
 *   - Device reboot (BOOT_COMPLETED)
 *   - App update / reinstall (MY_PACKAGE_REPLACED)
 *   - HTC/Huawei fast boot (QUICKBOOT_POWERON)
 *
 * Only restarts if the user was previously logged in
 * (auth token exists in SharedPreferences).
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d("BootReceiver", "📲 Received: $action")

        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON") return

        // Only restart if user is logged in (token exists).
        // Don't start the service for users who haven't logged in yet.
        val prefs = context.getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(BackTapService.KEY_AUTH_TOKEN, null)

        if (token.isNullOrBlank()) {
            Log.d("BootReceiver", "⏭️ No auth token — skipping BackTapService restart")
            return
        }

        Log.d("BootReceiver", "✅ Auth token found — starting BackTapService")

        val serviceIntent = Intent(context, BackTapService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}