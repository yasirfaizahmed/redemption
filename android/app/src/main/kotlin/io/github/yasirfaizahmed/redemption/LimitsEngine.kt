package io.github.yasirfaizahmed.redemption

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Keeps the daily app limits ([AppLimits]) without an accessibility service,
 * so payment apps such as Google Pay keep working. Runs inside
 * [MediaWatchService], which Android keeps connected while Redemption has
 * notification access.
 *
 * - Usage access tells which app is open; its time counts while the screen is
 *   on and unlocked.
 * - Background playback (media sessions) counts too, and is paused once the
 *   app's time is used up.
 * - A used-up app is covered by a full-screen notice (display over other
 *   apps) and the phone goes to the home screen.
 */
class LimitsEngine(private val context: Context, private val listener: ComponentName) {
    private val main = Handler(Looper.getMainLooper())
    private var lastTick = SystemClock.elapsedRealtime()

    /** The screen was just unlocked: a round now, not at the next idle one. */
    fun nudge() = start()

    /** Events are read again from a little before the last read: late ones still land. */
    private var eventsFrom = 0L

    /** The first read after starting looks a day back, to find the app in front. */
    private var firstRead = true
    private var foregroundPkg: String? = null
    private var foregroundIsCustomTab = false
    private var playingBefore = emptySet<String>()
    private var overlay: View? = null

    private val tick = object : Runnable {
        override fun run() {
            var next = TICK_IDLE_MILLIS
            try {
                next = step()
            } catch (e: Exception) {
                Log.w(TAG, "App limits", e)
            }
            main.postDelayed(this, next)
        }
    }

    /** Starts, or runs a round now (the screen was just unlocked). */
    fun start() {
        main.removeCallbacks(tick)
        main.post(tick)
    }

    fun stop() {
        main.removeCallbacksAndMessages(null)
        hideOverlay()
    }

    /** One round: who's on screen, count, enforce. Returns the delay to the next. */
    private fun step(): Long {
        val now = SystemClock.elapsedRealtime()
        val gap = (now - lastTick).coerceAtLeast(0L)
        lastTick = now
        val quotas = AppLimits.quotas(context)
        if (quotas.isEmpty()) {
            playingBefore = emptySet()
            hideOverlay()
            return TICK_IDLE_MILLIS
        }
        readForeground()
        val inUse = screenInUse()

        val shownGroup = foregroundPkg
            ?.takeIf { inUse && !foregroundIsCustomTab }
            ?.let { AppLimits.groupOf(it)?.id }
            ?.takeIf { it in quotas }
        // A video in a Chrome Custom Tab belongs to the other app: not counted.
        val playing = playingSessions().filter { (group, _) ->
            group in quotas && !(group == "chrome" && foregroundIsCustomTab)
        }
        val playingGroups = playing.map { it.first }.toSet()
        for (group in setOfNotNull(shownGroup) + playingGroups) {
            // Playing at both rounds: the whole gap was listening, however
            // late this round came (the phone dozes with the screen off).
            val cap = if (group in playingGroups && group in playingBefore) {
                MAX_PLAYING_GAP_MILLIS
            } else {
                MAX_GAP_MILLIS
            }
            AppLimits.add(context, group, gap.coerceAtMost(cap))
        }
        playingBefore = playingGroups

        val blocked = shownGroup != null && AppLimits.isUsedUp(context, shownGroup)
        if (blocked) block(shownGroup!!, playing) else hideOverlay()
        playing.forEach { (group, controller) ->
            if (AppLimits.isUsedUp(context, group)) pause(controller)
        }
        return when {
            blocked -> TICK_BLOCKED_MILLIS // lift the cover as soon as home is up
            inUse -> TICK_ACTIVE_MILLIS
            else -> TICK_IDLE_MILLIS
        }
    }

    /** The app in front, from Usage access (resumed / paused activities). */
    @Suppress("DEPRECATION")
    private fun readForeground() {
        if (!hasUsageAccess(context)) {
            foregroundPkg = null
            return
        }
        val usage = context.getSystemService(UsageStatsManager::class.java) ?: return
        val now = System.currentTimeMillis()
        // Never more than a day (first read) or an hour back: a long pause in
        // reading must not mean a huge read.
        val from = if (firstRead) {
            now - 24 * 60 * 60_000L
        } else {
            maxOf(eventsFrom, now - 60 * 60_000L)
        }
        firstRead = false
        val events = usage.queryEvents(from, now) ?: return
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when (e.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    foregroundPkg = e.packageName
                    foregroundIsCustomTab =
                        e.className?.contains("customtabs", ignoreCase = true) == true
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND ->
                    if (e.packageName == foregroundPkg) foregroundPkg = null
            }
        }
        // Replaying the last few seconds again is harmless: the latest event wins.
        eventsFrom = now - EVENT_OVERLAP_MILLIS
    }

    private fun screenInUse(): Boolean {
        val power = context.getSystemService(PowerManager::class.java)
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        return power?.isInteractive == true && keyguard?.isKeyguardLocked != true
    }

    /** Limited apps playing in the background. */
    private fun playingSessions(): List<Pair<String, MediaController>> {
        val sessions = context.getSystemService(MediaSessionManager::class.java)
            ?: return emptyList()
        return try {
            sessions.getActiveSessions(listener).mapNotNull { c ->
                val group = AppLimits.groupOf(c.packageName)?.id
                if (group != null && c.playbackState?.state == PlaybackState.STATE_PLAYING) {
                    group to c
                } else {
                    null
                }
            }
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    private fun pause(controller: MediaController) {
        Log.i(TAG, "${controller.packageName}: today's time is used up, pausing")
        controller.transportControls.pause()
    }

    /** Covers the app, pauses its playback and goes home. */
    private fun block(group: String, playing: List<Pair<String, MediaController>>) {
        if (overlay == null) Log.i(TAG, "$group: today's time is used up")
        playing.forEach { (g, c) -> if (g == group) pause(c) }
        showOverlay()
        goHome()
    }

    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(home)
        } catch (e: Exception) {
            Log.w(TAG, "Could not go home", e)
        }
    }

    private fun showOverlay() {
        if (overlay != null || !Settings.canDrawOverlays(context)) return
        val windows = context.getSystemService(WindowManager::class.java) ?: return
        fun dp(v: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            v.toFloat(),
            context.resources.displayMetrics,
        ).toInt()
        val view = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(18, 18, 20))
            setPadding(dp(32), dp(32), dp(32), dp(32))
            addView(
                TextView(context).apply {
                    text = "Today’s time is used up"
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
                    gravity = Gravity.CENTER
                },
            )
            addView(
                TextView(context).apply {
                    text = "This app opens again after midnight.\nGuard your time — it is your life."
                    setTextColor(Color.rgb(200, 200, 205))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    gravity = Gravity.CENTER
                    setPadding(0, dp(12), 0, dp(24))
                },
            )
            addView(
                Button(context).apply {
                    text = "Go home"
                    setOnClickListener {
                        goHome()
                        hideOverlay()
                    }
                },
            )
        }
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.OPAQUE,
        )
        try {
            windows.addView(view, params)
            overlay = view
        } catch (e: Exception) {
            Log.w(TAG, "Could not cover the app", e)
        }
    }

    private fun hideOverlay() {
        val view = overlay ?: return
        overlay = null
        try {
            context.getSystemService(WindowManager::class.java)?.removeView(view)
        } catch (e: Exception) {
            Log.w(TAG, "Could not remove the cover", e)
        }
    }

    companion object {
        private const val TAG = "AppLimits"

        /** Rounds while the screen is in use, and while it's off. */
        private const val TICK_ACTIVE_MILLIS = 2_000L
        private const val TICK_IDLE_MILLIS = 15_000L
        private const val TICK_BLOCKED_MILLIS = 500L

        /** A late round counts at most this much… */
        private const val MAX_GAP_MILLIS = 30_000L

        /** …unless the same app was playing all along. */
        private const val MAX_PLAYING_GAP_MILLIS = 15 * 60_000L

        private const val EVENT_OVERLAP_MILLIS = 5_000L

        /** Usage access ("Apps with usage access") is granted. */
        fun hasUsageAccess(context: Context): Boolean {
            val ops = context.getSystemService(AppOpsManager::class.java) ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ops.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                ops.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }
    }
}
