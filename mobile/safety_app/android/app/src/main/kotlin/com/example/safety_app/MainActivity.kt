package com.example.safety_app

import android.content.BroadcastReceiver
import android.util.Log
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// ─────────────────────────────────────────────
//  MainActivity.kt  (FIXED VERSION)
//
//  KEY FIXES vs original:
//  1. IntentFilter uses BackTapService.ACTION_BACK_TAP constant (fully qualified)
//     instead of plain "BACK_TAP_DETECTED" — must match what BackTapService sends.
//  2. onStop() does NOT set alive=false (correctly kept in onDestroy only).
//  3. setEventChannelActive(false) called in onCancel() — correct, this is what
//     routes backgrounded SOS to direct HTTP path.
// ─────────────────────────────────────────────

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.example.safety_app/backtap"
        private const val EVENT_CHANNEL  = "com.example.safety_app/backtap/events"
    }

    private var eventSink: EventChannel.EventSink? = null

    private val tapReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val type  = intent?.getStringExtra("type")  ?: return
            val count = intent.getIntExtra("count", 0)
            eventSink?.success(mapOf("type" to type, "count" to count))
        }
    }

    // ─────────────────────────────────────────────
    //  FLUTTER ENGINE SETUP
    // ─────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "startService" -> {
                    startBackTapService()
                    result.success(null)
                }

                "stopService" -> {
                    stopBackTapService()
                    result.success(null)
                }

                "saveToken" -> {
                    val token = call.argument<String>("token")
                    if (token != null) {
                        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .putString(BackTapService.KEY_AUTH_TOKEN, token)
                            .apply()
                            // Force immediate write to disk
                        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .commit() // Use commit() instead of apply() for immediate write
                        Log.d("MainActivity", "✅ Token saved and committed: $token")
                        result.success(null)
                    } else {
                        result.error("INVALID_TOKEN", "Token is null", null)
                    }
                }
                // Add this to the MethodChannel in MainActivity.kt:

                "hasToken" -> {
                    val token = getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                        .getString(BackTapService.KEY_AUTH_TOKEN, null)
                    result.success(token != null && token.isNotBlank())
                }

                "clearToken" -> {
                    getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .remove(BackTapService.KEY_AUTH_TOKEN)
                        .apply()
                    result.success(null)
                }

                "saveBaseUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .putString(BackTapService.KEY_BASE_URL, url)
                            .apply()
                        result.success(null)
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }

                "saveAppState" -> {
                    val state = call.argument<String>("state")
                    if (state != null) {
                        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .putString(BackTapService.KEY_APP_STATE, state)
                            .apply()
                        result.success(null)
                    } else {
                        result.error("INVALID_STATE", "State is null", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                setEventChannelActive(true)

                // FIX: Use BackTapService.ACTION_BACK_TAP constant (fully qualified)
                // instead of a hardcoded string — ensures filter matches what the service sends.
                val filter = IntentFilter(BackTapService.ACTION_BACK_TAP)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(tapReceiver, filter, RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(tapReceiver, filter)
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                // ✅ Correct: setting inactive here routes background taps to direct HTTP.
                // BackTapService checks isEventChannelActive() before deciding to broadcast
                // vs. call fireDirectSos() directly.
                setEventChannelActive(false)
                try { unregisterReceiver(tapReceiver) } catch (_: Exception) {}
            }
        })
    }

    // ─────────────────────────────────────────────
    //  ALIVE FLAG
    // ─────────────────────────────────────────────

    override fun onStart() {
        super.onStart()
        setFlutterAlive(true)
    }

    // ⚠️ Do NOT set alive=false in onStop().
    // onStop() fires on every screen lock or app switch — the Flutter process
    // is still alive. Only onDestroy() means the Activity is truly gone.
    override fun onDestroy() {
        setFlutterAlive(false)
        setEventChannelActive(false)
        try { unregisterReceiver(tapReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun setFlutterAlive(alive: Boolean) {
        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(BackTapService.KEY_FLUTTER_ALIVE, alive)
            .apply()
    }

    private fun setEventChannelActive(active: Boolean) {
        getSharedPreferences(BackTapService.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(BackTapService.KEY_EVENTCHANNEL_ACTIVE, active)
            .apply()
    }

    // ─────────────────────────────────────────────
    //  SERVICE START / STOP
    // ─────────────────────────────────────────────

    private fun startBackTapService() {
        val intent = Intent(this, BackTapService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackTapService() {
        stopService(Intent(this, BackTapService::class.java))
    }
}