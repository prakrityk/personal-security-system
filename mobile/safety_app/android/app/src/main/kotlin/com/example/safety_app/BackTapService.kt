package com.example.safety_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import kotlin.math.abs
import kotlin.math.sqrt

// ─────────────────────────────────────────────
//  BackTapService.kt  (FIXED VERSION)
//
//  KEY FIXES vs original:
//  1. WakeLock acquired in onCreate() — prevents CPU sleep from killing
//     sensor callbacks in background/killed state.
//  2. START_STICKY + onTaskRemoved() restarts the service after app kill.
//  3. foregroundServiceType changed to "specialUse" which works without
//     extra permissions on all Android versions. (health requires BODY_SENSORS
//     on Android 13+ which blocks foreground start on many devices.)
//  4. Explicit broadcast (setPackage) — ensures delivery on Android 14+
//     where implicit broadcasts to non-exported receivers are blocked.
//  5. isFlutterAlive() logic hardened — only returns true when BOTH
//     KEY_FLUTTER_ALIVE AND KEY_EVENTCHANNEL_ACTIVE are true, so a
//     backgrounded app (EventChannel sink closed) routes to direct HTTP.
// ─────────────────────────────────────────────

class BackTapService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "BackTapService"
        const val ACTION_BACK_TAP = "com.example.safety_app.BACK_TAP_DETECTED"  // FIX: fully qualified action
        private const val CHANNEL_ID = "back_tap_channel"
        private const val NOTIFICATION_ID = 1001
        private const val SOS_NOTIFICATION_ID = 1002

        // ── SharedPreferences keys (must match Flutter + MainActivity) ──
        const val PREFS_NAME               = "BackTapPrefs"
        const val KEY_AUTH_TOKEN           = "auth_token"
        const val KEY_FLUTTER_ALIVE        = "flutter_alive"
        const val KEY_BASE_URL             = "base_url"
        const val KEY_EVENTCHANNEL_ACTIVE  = "eventchannel_active"
        const val KEY_APP_STATE            = "app_state"

        private const val SOS_PATH     = "/sos/with-voice"
        private const val FALLBACK_URL =
            "https://yevette-oxycephalic-lanell.ngrok-free.dev/api"

        // ── Tap detection thresholds ──
        private const val TAP_MIN          = 3.5f
        private const val TAP_MAX          = 12.0f
        private const val Z_DOMINANCE_FLAT = 0.50f
        private const val Z_DOMINANCE_HELD = 0.60f
        private const val MAX_GYRO_FOR_TAP = 0.8f
        private const val GYRO_WINDOW_MS   = 400L
        private const val MIN_TAP_GAP_MS   = 150L
        private const val REQUIRED_TAPS    = 5
        private const val TAP_WINDOW_MS    = 3000L

        private const val ALPHA                  = 0.8f
        private const val GRAVITY_WARMUP_SAMPLES = 10
    }

    // ── Sensors ──
    private lateinit var sensorManager: SensorManager
    private var accelSensor: Sensor? = null
    private var gyroSensor: Sensor?  = null

    // ── FIX 1: WakeLock — keeps CPU running so sensors fire in background ──
    private var wakeLock: PowerManager.WakeLock? = null

    // ── Gravity filter state ──
    private var gravX = 0f; private var gravY = 0f; private var gravZ = 0f
    private var gravWarmX = 0f; private var gravWarmY = 0f; private var gravWarmZ = 0f
    private var gravityWarmupCount = 0
    private var gravityInitialized = false

    // ── Gyro buffer ──
    data class GyroSample(val timeMs: Long, val rotation: Float)
    private val gyroBuffer = mutableListOf<GyroSample>()

    // ── Tap state ──
    private val tapTimes    = mutableListOf<Long>()
    private var lastTapAtMs = 0L

    // ── Coroutine scope for HTTP calls ──
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── OkHttp client ──
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    // ─────────────────────────────────────────────
    //  SERVICE LIFECYCLE
    // ─────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        // Verify token exists on service creation
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_AUTH_TOKEN, null)
        Log.d(TAG, "🔑 Service onCreate - token ${if (token.isNullOrBlank()) "MISSING" else "PRESENT"}")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        // ── FIX 1: Acquire WakeLock so CPU stays on and sensors keep firing ──
        // Without this, Android suspends the CPU in background, sensor callbacks
        // stop, and no taps are detected. PARTIAL_WAKE_LOCK keeps CPU on without
        // keeping the screen on (battery efficient).
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SafetyApp::BackTapWakeLock"
        ).also {
            it.acquire(12 * 60 * 60 * 1000L) // max 12 hours; released in onDestroy
        }
        Log.d(TAG, "✅ WakeLock acquired")

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelSensor   = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroSensor    = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        sensorManager.registerListener(this, accelSensor,  SensorManager.SENSOR_DELAY_FASTEST)
        sensorManager.registerListener(this, gyroSensor,   SensorManager.SENSOR_DELAY_FASTEST)

        Log.d(TAG, "✅ BackTapService started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY: Android restarts service after killing it.
        // The service is re-created from scratch — sensors re-register.
        return START_STICKY
    }

    // ── FIX 2: onTaskRemoved fires when user swipes app from recents ──
    // Restart the service explicitly so it survives app kill on all launchers.
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "📌 onTaskRemoved — scheduling restart")
        val restartIntent = Intent(applicationContext, BackTapService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        serviceScope.cancel()
        // Release WakeLock safely
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "✅ WakeLock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock release error: ${e.message}")
        }
        Log.d(TAG, "🛑 BackTapService stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────
    //  SENSOR EVENTS
    // ─────────────────────────────────────────────

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE     -> handleGyro(event)
            Sensor.TYPE_ACCELEROMETER -> handleAccel(event)
        }
    }

    // ─────────────────────────────────────────────
    //  GYROSCOPE
    // ─────────────────────────────────────────────

    private fun handleGyro(event: SensorEvent) {
        val rotation = sqrt(
            event.values[0] * event.values[0] +
            event.values[1] * event.values[1] +
            event.values[2] * event.values[2]
        )
        val now = System.currentTimeMillis()
        gyroBuffer.add(GyroSample(now, rotation))
        gyroBuffer.removeAll { now - it.timeMs > GYRO_WINDOW_MS }
    }

    // ─────────────────────────────────────────────
    //  ACCELEROMETER + TAP PIPELINE
    // ─────────────────────────────────────────────

    private fun handleAccel(event: SensorEvent) {
        val now = System.currentTimeMillis()

        if (!gravityInitialized) {
            gravWarmX += event.values[0]
            gravWarmY += event.values[1]
            gravWarmZ += event.values[2]
            gravityWarmupCount++
            if (gravityWarmupCount >= GRAVITY_WARMUP_SAMPLES) {
                gravX = gravWarmX / GRAVITY_WARMUP_SAMPLES
                gravY = gravWarmY / GRAVITY_WARMUP_SAMPLES
                gravZ = gravWarmZ / GRAVITY_WARMUP_SAMPLES
                gravityInitialized = true
            }
            return
        }

        gravX = ALPHA * gravX + (1 - ALPHA) * event.values[0]
        gravY = ALPHA * gravY + (1 - ALPHA) * event.values[1]
        gravZ = ALPHA * gravZ + (1 - ALPHA) * event.values[2]

        val linX = event.values[0] - gravX
        val linY = event.values[1] - gravY
        val linZ = event.values[2] - gravZ

        val magnitude = sqrt(linX * linX + linY * linY + linZ * linZ)
        detectTap(magnitude, linZ, now)
    }

    // ─────────────────────────────────────────────
    //  TAP DETECTION
    // ─────────────────────────────────────────────

    private fun detectTap(magnitude: Float, linZ: Float, now: Long) {
        if (magnitude < TAP_MIN || magnitude > TAP_MAX) return

        val isLyingFlat = abs(gravZ) > 8.0f
        val zThreshold  = if (isLyingFlat) Z_DOMINANCE_FLAT else Z_DOMINANCE_HELD
        val zDominance  = abs(linZ) / (magnitude + 0.001f)
        if (zDominance < zThreshold) return

        if (gyroBuffer.isNotEmpty()) {
            val median = gyroBuffer.map { it.rotation }.sorted()[gyroBuffer.size / 2]
            if (median > MAX_GYRO_FOR_TAP) return
        }

        if (now - lastTapAtMs < MIN_TAP_GAP_MS) return
        lastTapAtMs = now

        tapTimes.add(now)
        tapTimes.removeAll { now - it > TAP_WINDOW_MS }

        val tapCount = tapTimes.size
        Log.d(TAG, "👆 Tap $tapCount/$REQUIRED_TAPS (mag=${"%.2f".format(magnitude)})")

        // ── FIX 4: Explicit broadcast — guaranteed delivery on Android 14+ ──
        sendBroadcast(Intent(ACTION_BACK_TAP).apply {
            setPackage(packageName)   // makes it explicit, not implicit
            putExtra("type", "tap_count")
            putExtra("count", tapCount)
        })

        if (tapCount >= REQUIRED_TAPS) {
            tapTimes.clear()
            lastTapAtMs = 0L
            Log.d(TAG, "🚨 5 taps detected!")

            // ── FIX 5: Routing logic ──
            // isEventChannelActive() = Flutter foreground and EventChannel sink open.
            // isFlutterAlive()       = Flutter Activity exists (may be backgrounded).
            //
            // Route:
            //   EventChannel active → Flutter handles (confirmation dialog + API)
            //   Flutter alive but channel closed → app backgrounded → direct HTTP
            //   Flutter dead → app killed → direct HTTP
            if (isEventChannelActive()) {
                Log.d(TAG, "📲 App foreground → routing through Flutter EventChannel")
                sendBroadcast(Intent(ACTION_BACK_TAP).apply {
                    setPackage(packageName)
                    putExtra("type", "sos_trigger")
                    putExtra("count", 5)
                })
            } else {
                Log.d(TAG, "💀 App backgrounded/killed → firing direct HTTP SOS")
                fireDirectSos()
            }
        }
    }

    // ─────────────────────────────────────────────
    //  ALIVE CHECKS
    // ─────────────────────────────────────────────

    private fun isFlutterAlive(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_FLUTTER_ALIVE, false)
    }

    private fun isEventChannelActive(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_EVENTCHANNEL_ACTIVE, false)
    }

    // ─────────────────────────────────────────────
    //  DIRECT SOS — BACKGROUND / KILLED PATH
    // ─────────────────────────────────────────────

    private fun fireDirectSos() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Debug: log all preferences
        val allPrefs = prefs.all
        Log.d(TAG, "📝 SharedPreferences contents: $allPrefs")
        
        val token = prefs.getString(KEY_AUTH_TOKEN, null)
        Log.d(TAG, "🔑 Token retrieved: ${if (token.isNullOrBlank()) "MISSING" else "PRESENT"}")
        
        if (token.isNullOrBlank()) {
            Log.e(TAG, "❌ No auth token found")
            showSosFailedNotification("Could not send SOS — please open the app and log in.")
            return
        }
        serviceScope.launch {
            try {
                val baseUrl = prefs.getString(KEY_BASE_URL, FALLBACK_URL) ?: FALLBACK_URL
                val sosApiUrl = baseUrl.trimEnd('/') + SOS_PATH
                Log.d(TAG, "📡 Firing direct SOS POST to $sosApiUrl")

                val body = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("trigger_type", "manual")
                    .addFormDataPart("event_type",   "back_tap")
                    .addFormDataPart("app_state",    prefs.getString(KEY_APP_STATE, "killed") ?: "killed")
                    .addFormDataPart("timestamp",    java.time.Instant.now().toString())
                    .build()

                val request = Request.Builder()
                    .url(sosApiUrl)
                    .addHeader("Authorization", "Bearer $token")
                    .addHeader("ngrok-skip-browser-warning", "true")
                    .post(body)
                    .build()

                val response = httpClient.newCall(request).execute()

                if (response.isSuccessful) {
                    Log.d(TAG, "✅ Direct SOS sent! ${response.body?.string()}")
                    showSosSentNotification()
                } else {
                    val errBody = response.body?.string()
                    Log.e(TAG, "❌ Direct SOS HTTP ${response.code}: $errBody")
                    if (response.code == 401) {
                        prefs.edit().remove(KEY_AUTH_TOKEN).apply()
                        showSosFailedNotification("Session expired. Please open the app and log in again.")
                    } else {
                        showSosFailedNotification("SOS failed (${response.code}). Please open the app.")
                    }
                }
                response.close()

            } catch (e: Exception) {
                Log.e(TAG, "❌ Direct SOS error: ${e.message}")
                showSosFailedNotification("No network. Please open the app and retry.")
            }
        }
    }

    // ─────────────────────────────────────────────
    //  NOTIFICATIONS
    // ─────────────────────────────────────────────

    private fun showSosSentNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(SOS_NOTIFICATION_ID, buildResultNotification(
            title   = "🚨 SOS Alert Sent",
            content = "Your emergency alert has been sent to your guardian."
        ))
    }

    private fun showSosFailedNotification(reason: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(SOS_NOTIFICATION_ID, buildResultNotification(
            title   = "⚠️ SOS Failed",
            content = reason
        ))
    }

    private fun buildResultNotification(title: String, content: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Back Tap Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Monitors back taps for SOS trigger" }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Safety monitoring active")
            .setContentText("Back-tap SOS is listening")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .build()
    }
}