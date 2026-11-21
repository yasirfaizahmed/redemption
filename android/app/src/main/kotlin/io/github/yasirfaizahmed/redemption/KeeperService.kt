package io.github.yasirfaizahmed.redemption

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import com.gdelataillade.alarm.alarm.AlarmService

/**
 * Redemption's keeper, a foreground service with no accessibility service
 * and no notification access (Play Protect blocks sideloaded apps that
 * declare either, and Google Pay refuses to pay beside an accessibility
 * service). It
 *
 * - keeps the daily app limits ([LimitsEngine]), and
 * - while a wake-up alarm rings, brings the sums back whenever you leave
 *   them for another app, Settings or the uninstall screen — calls and
 *   emergency help always get through, and it lets go after an hour.
 *
 * It runs while limits are set or an alarm rings, and stops itself otherwise.
 */
class KeeperService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var engine: LimitsEngine? = null
    private var ringingSince = 0L

    private val round = object : Runnable {
        override fun run() {
            var next = IDLE_MILLIS
            try {
                next = step()
            } catch (e: Exception) {
                Log.w(TAG, "Keeper", e)
            }
            if (next > 0) main.postDelayed(this, next) else stopSelf()
        }
    }

    /** Unlocking the phone runs a round at once. */
    private val unlocked = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = runNow()
    }
    private var listening = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        engine = LimitsEngine(this)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(unlocked, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(unlocked, filter)
        }
        listening = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        runNow()
        return START_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        engine?.stop()
        engine = null
        if (listening) {
            try {
                unregisterReceiver(unlocked)
            } catch (e: IllegalArgumentException) {
                // Already gone.
            }
            listening = false
        }
        super.onDestroy()
    }

    private fun runNow() {
        main.removeCallbacks(round)
        main.post(round)
    }

    /** One round; the delay to the next, or 0 to stop (nothing to keep). */
    private fun step(): Long {
        val engine = engine ?: return 0
        val limitsSet = AppLimits.quotas(this).isNotEmpty()
        val ringing = AlarmService.ringingAlarmIds.isNotEmpty()
        if (!limitsSet && !ringing) return 0
        var next = if (limitsSet) engine.step() else IDLE_MILLIS
        if (ringing) {
            keepSumsOnScreen(engine)
            next = minOf(next, RINGING_MILLIS)
        } else {
            ringingSince = 0L
        }
        return next
    }

    /** While ringing: back to the sums if you've left them. */
    private fun keepSumsOnScreen(engine: LimitsEngine) {
        val now = SystemClock.elapsedRealtime()
        if (sumsShownAt == 0L) return // the app hasn't shown its sums yet
        if (ringingSince == 0L) ringingSince = now
        if (now - ringingSince > MAX_KEEP_MILLIS) return // never longer than this
        if (MainActivity.resumed) return
        val power = getSystemService(PowerManager::class.java)
        if (power?.isInteractive != true) return
        if (inCall()) return
        if (!LimitsEngine.hasUsageAccess(this) || !Settings.canDrawOverlays(this)) return
        engine.readForeground()
        // Only when we know where you went — never over the emergency dialer.
        val pkg = engine.foregroundPkg ?: return
        if (pkg == packageName || isCallOrEmergency(pkg)) return
        Log.i(TAG, "Left the alarm for $pkg while ringing: bringing it back")
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Could not bring the alarm back", e)
        }
    }

    private fun inCall(): Boolean {
        val mode = getSystemService(AudioManager::class.java)?.mode ?: return false
        return mode == AudioManager.MODE_IN_CALL ||
            mode == AudioManager.MODE_IN_COMMUNICATION ||
            mode == AudioManager.MODE_RINGTONE
    }

    private fun isCallOrEmergency(pkg: String): Boolean {
        if (CALL_PACKAGES.any { pkg == it || pkg.startsWith("$it.") }) return true
        if (pkg.contains("dialer") || pkg.contains("incallui") ||
            pkg.contains("emergency") || pkg.contains("safetyhub") ||
            pkg.contains("telecom")
        ) {
            return true
        }
        return try {
            getSystemService(TelecomManager::class.java)?.defaultDialerPackage == pkg
        } catch (e: SecurityException) {
            false
        }
    }

    private fun startInForeground() {
        val notifications = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "App limits and alarm keeper",
                    NotificationManager.IMPORTANCE_MIN,
                ).apply {
                    description = "Shown while Redemption keeps your app limits"
                    setShowBadge(false)
                },
            )
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_redemption)
            .setContentTitle("Keeping your limits")
            .setContentText("Guard your time — it is your life.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val TAG = "Keeper"
        private const val CHANNEL = "redemption_keeper"
        private const val NOTIFICATION_ID = 4107

        private const val IDLE_MILLIS = 15_000L
        private const val RINGING_MILLIS = 700L

        /** Never keep anyone on the sums longer than this, whatever goes wrong. */
        private const val MAX_KEEP_MILLIS = 60L * 60 * 1000

        private val CALL_PACKAGES = listOf(
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.emergency",
            "com.google.android.apps.safetyhub",
            "com.google.android.dialer",
            "com.samsung.android.dialer",
            "com.samsung.android.incallui",
            "com.android.dialer",
            "com.android.incallui",
        )

        /**
         * When the app last confirmed the sums are on screen (0: not yet, or
         * solved). Set from [MainActivity].
         */
        @Volatile
        var sumsShownAt = 0L

        /** Starts the keeper (or runs a round now) if there's anything to keep. */
        fun start(context: Context) {
            val needed = AppLimits.quotas(context).isNotEmpty() ||
                AlarmService.ringingAlarmIds.isNotEmpty()
            if (!needed) return
            val intent = Intent(context, KeeperService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // Not allowed from the background just now; the next app start
                // or boot tries again.
                Log.w(TAG, "Could not start the keeper", e)
            }
        }
    }
}

/** After a restart or an update, the limits carry on. */
class KeeperBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) = KeeperService.start(context)
}
