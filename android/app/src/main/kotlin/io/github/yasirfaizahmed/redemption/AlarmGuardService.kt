package io.github.yasirfaizahmed.redemption

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Toast
import com.gdelataillade.alarm.alarm.AlarmService

/**
 * "Alarm guard": while a wake-up alarm rings, and only then, keeps the user
 * on Redemption's sums. It closes the power menu (no switching off), the
 * uninstall dialog and Settings (no uninstalling or force-stopping), takes
 * them back from any other app, and swallows the volume keys.
 *
 * The user turns it on in Accessibility settings. A forced restart (holding
 * power ~10 s) is done by the hardware and can't be stopped by any app; the
 * alarm rings again when the phone is back on.
 *
 * It also keeps the daily app limits ([AppLimits]): it counts the time a
 * limited app is on screen (and, with [MediaWatchService], playing in the
 * background), sends you home from it once today's time is used up, pauses
 * its playback, and — while any limit is set — won't let itself be turned
 * off or Redemption be uninstalled.
 */
class AlarmGuardService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())

    /**
     * Ringing, or about to: a re-armed alarm (after a restart, or one never
     * solved) is silent for a few seconds first, and that gap mustn't be a
     * way out.
     *
     * Only while the sums are actually on offer ([sumsShownAt]), so a broken
     * app can never lock the phone, and never for more than [MAX_GUARD_MILLIS].
     */
    private val ringing: Boolean
        get() {
            val now = System.currentTimeMillis()
            val active = AlarmService.ringingAlarmIds.isNotEmpty() || ringsVerySoon()
            if (!active) {
                // Nothing rings: the next alarm must show its sums again first.
                sumsShownAt = 0L
                guardingSince = 0L
                return false
            }
            if (sumsShownAt == 0L) {
                guardingSince = 0L
                return false
            }
            if (guardingSince == 0L) guardingSince = now
            return now - guardingSince < MAX_GUARD_MILLIS
        }

    private var guardingSince = 0L

    private fun ringsVerySoon(): Boolean {
        val alarms = getSystemService(AlarmManager::class.java) ?: return false
        val next = alarms.nextAlarmClock ?: return false
        if (next.showIntent?.creatorPackage != packageName) return false
        return next.triggerTime - System.currentTimeMillis() <= SOON_MILLIS
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        lastTick = SystemClock.elapsedRealtime()
        main.removeCallbacks(tick)
        main.postDelayed(tick, TICK_MILLIS)
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        try {
            onWindowForLimits(pkg, event)
        } catch (e: Exception) {
            Log.w(TAG, "App limits", e)
        }
        if (!ringing) return
        if (pkg == packageName) return

        val cls = event.className?.toString() ?: ""
        // Calls and emergency help always get through.
        if (isCallOrEmergency(pkg, cls)) return
        if (pkg == "com.android.systemui" || pkg.endsWith(".systemui")) {
            // The power menu (and on some phones the shade) is SystemUI.
            if (isPowerMenu(cls, event)) {
                Log.i(TAG, "Power menu while ringing: closing it")
                performGlobalAction(GLOBAL_ACTION_BACK)
                closeShade()
                bringBack()
            }
            return
        }
        // Settings, the uninstall dialog, the launcher, another app: back to
        // the sums.
        Log.i(TAG, "Left the alarm for $pkg while ringing: bringing it back")
        if (pkg.contains("packageinstaller") || pkg.contains("settings")) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
        bringBack()
    }

    private fun isCallOrEmergency(pkg: String, cls: String): Boolean {
        if (cls.contains("Emergency", ignoreCase = true)) return true
        if (CALL_PACKAGES.any { pkg == it || pkg.startsWith("$it.") }) return true
        if (pkg.contains("dialer") || pkg.contains("incallui") ||
            pkg.contains("emergency") || pkg.contains("safetyhub") ||
            pkg.contains("telecom")
        ) {
            return true
        }
        val telecom = getSystemService(TelecomManager::class.java)
        return try {
            telecom?.defaultDialerPackage == pkg
        } catch (e: SecurityException) {
            false
        }
    }

    private fun isPowerMenu(cls: String, event: AccessibilityEvent): Boolean {
        if (cls.contains("GlobalActions", ignoreCase = true)) return true
        if (cls.contains("PowerMenu", ignoreCase = true)) return true
        val text = event.text.joinToString(" ").lowercase()
        return POWER_WORDS.any { text.contains(it) }
    }

    private fun closeShade() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
        }
    }

    private fun bringBack() {
        // Twice: once now, once after the closing window has gone.
        launchApp()
        main.postDelayed({ if (ringing) launchApp() }, 400)
    }

    private fun launchApp() {
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

    // ---- Daily app limits ------------------------------------------------

    private var lastTick = 0L
    private var lastNotice = 0L

    /** Limited apps that were playing in the background at the last tick. */
    private var playingBefore = emptySet<String>()

    /** Chrome's last window was a Custom Tab inside another app (a sign-in, a payment check). */
    private var chromeIsCustomTab = false

    /** The last app sent home, and when: if it's still there, home didn't work. */
    private var lastBlocked: String? = null
    private var lastBlockedAt = 0L

    private val tick = object : Runnable {
        override fun run() {
            try {
                countAndEnforce()
            } catch (e: Exception) {
                Log.w(TAG, "App limits", e)
            }
            main.postDelayed(this, TICK_MILLIS)
        }
    }

    private fun onWindowForLimits(pkg: String, event: AccessibilityEvent) {
        val quotas = AppLimits.quotas(this)
        if (quotas.isEmpty()) return
        val cls = event.className?.toString() ?: ""
        val group = AppLimits.groupOf(pkg)?.id
        if (group == "chrome") chromeIsCustomTab = cls.contains("customtabs", ignoreCase = true)
        if (group != null && group in quotas && !exempt(group) && AppLimits.isUsedUp(this, group)) {
            block(group)
        }
        protectLimits(pkg, cls, event)
    }

    /** Custom Tabs are other apps' sign-ins and payment checks: never blocked. */
    private fun exempt(group: String) = group == "chrome" && chromeIsCustomTab

    /** Limited apps with a window on screen now — split screen and picture-in-picture too. */
    private fun onScreen(): Set<String> {
        if (!screenInUse()) return emptySet()
        return try {
            windows
                .filter { it.type == AccessibilityWindowInfo.TYPE_APPLICATION }
                .mapNotNull { w ->
                    val pkg = w.root?.packageName?.toString() ?: return@mapNotNull null
                    AppLimits.groupOf(pkg)?.id
                }
                .filterNot { exempt(it) }
                .toSet()
        } catch (e: Exception) {
            emptySet()
        }
    }

    /** Adds the time since the last tick to whatever is in use, then blocks. */
    private fun countAndEnforce() {
        val now = SystemClock.elapsedRealtime()
        val gap = (now - lastTick).coerceAtLeast(0L)
        lastTick = now
        val quotas = AppLimits.quotas(this)
        if (quotas.isEmpty()) {
            playingBefore = emptySet()
            return
        }

        val shown = onScreen().filter { it in quotas }.toSet()
        val playing = playingSessions().filter { it.first in quotas }
        val playingGroups = playing.map { it.first }.toSet()
        for (group in shown + playingGroups) {
            // Playing at both ticks: the whole gap was listening, however
            // late this tick came (the phone dozes with the screen off).
            val cap = if (group in playingGroups && group in playingBefore) {
                MAX_PLAYING_GAP_MILLIS
            } else {
                MAX_TICK_GAP_MILLIS
            }
            AppLimits.add(this, group, gap.coerceAtMost(cap))
        }
        playingBefore = playingGroups

        shown.firstOrNull { AppLimits.isUsedUp(this, it) }?.let { block(it) }
        playing.forEach { (group, controller) ->
            if (AppLimits.isUsedUp(this, group)) pause(controller)
        }
        checkAppInfo()
    }

    private fun screenInUse(): Boolean {
        val power = getSystemService(PowerManager::class.java)
        val keyguard = getSystemService(KeyguardManager::class.java)
        return power?.isInteractive == true && keyguard?.isKeyguardLocked != true
    }

    /** Limited apps playing in the background (needs notification access). */
    private fun playingSessions(): List<Pair<String, MediaController>> {
        if (!MediaWatchService.isEnabled(this)) return emptyList()
        val sessions = getSystemService(MediaSessionManager::class.java) ?: return emptyList()
        return try {
            sessions.getActiveSessions(MediaWatchService.component(this)).mapNotNull { c ->
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

    /**
     * Today's time is used up: home, with its playback paused. If home
     * doesn't work (the app is pinned, or it's still there moments later),
     * the screen locks instead.
     */
    private fun block(group: String) {
        Log.i(TAG, "$group: today's time is used up")
        val now = SystemClock.elapsedRealtime()
        val activities = getSystemService(ActivityManager::class.java)
        val pinned = activities != null &&
            activities.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        val stillThere = lastBlocked == group && now - lastBlockedAt < STUCK_MILLIS
        if ((pinned || stillThere) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        } else {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
        lastBlocked = group
        lastBlockedAt = now
        playingSessions().forEach { (g, c) -> if (g == group) pause(c) }
        notice("Today’s time for this app is used up. It opens again after midnight.")
    }

    private fun notice(text: String) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastNotice < NOTICE_GAP_MILLIS) return
        lastNotice = now
        Toast.makeText(this, text, Toast.LENGTH_LONG).show()
    }

    /**
     * While limits are set the guard stays on and Redemption stays
     * installed: back out of the guard's and the background-listening
     * switches, Redemption's uninstall dialog, and its App info page (force
     * stop and clear storage would turn the limits off).
     */
    private fun protectLimits(pkg: String, cls: String, event: AccessibilityEvent) {
        val inSettings = pkg.contains("settings")
        val inInstaller = pkg.contains("packageinstaller")
        if (!inSettings && !inInstaller) return
        val texts = event.text.mapNotNull { it?.toString()?.trim() }
        val appName = appName()
        if (inInstaller) {
            val uninstalling = cls.contains("Uninstall", ignoreCase = true) ||
                texts.any { it.contains("uninstall", ignoreCase = true) }
            if (uninstalling && (texts.any { it.contains(appName, ignoreCase = true) } || activeWindowMentions(appName))) {
                closeProtected()
            }
            return
        }
        val ours = listOf(getString(R.string.alarm_guard_label), getString(R.string.media_watch_label))
        if (texts.any { t -> ours.any { t.equals(it, ignoreCase = true) } }) {
            closeProtected()
            return
        }
        // App info fills in a moment after it opens.
        main.postDelayed({ checkAppInfo() }, 350)
        main.postDelayed({ checkAppInfo() }, 900)
    }

    /** Redemption's App info or Storage page (its name in the header, with action buttons). */
    private fun checkAppInfo() {
        if (AppLimits.quotas(this).isEmpty()) return
        val root = try {
            rootInActiveWindow
        } catch (e: Exception) {
            null
        } ?: return
        if (root.packageName?.toString()?.contains("settings") != true) return
        val appName = appName()
        val header = HEADER_IDS.flatMap { root.findAccessibilityNodeInfosByViewId(it) }
        if (header.none { it.text?.toString()?.trim().equals(appName, ignoreCase = true) }) return
        val actions = ACTION_BUTTON_IDS.flatMap { root.findAccessibilityNodeInfosByViewId(it) }
        if (actions.isNotEmpty()) closeProtected()
    }

    private fun activeWindowMentions(text: String): Boolean = try {
        rootInActiveWindow?.findAccessibilityNodeInfosByText(text)?.isNotEmpty() == true
    } catch (e: Exception) {
        false
    }

    private fun appName() = applicationInfo.loadLabel(packageManager).toString()

    private fun closeProtected() {
        Log.i(TAG, "App limits are locked: closing a protected screen")
        performGlobalAction(GLOBAL_ACTION_BACK)
        notice("Your app limits are locked — the guard stays on.")
    }

    /** Volume keys do nothing while the alarm rings. */
    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null || !ringing) return false
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_MUTE -> true
            else -> false
        }
    }

    override fun onInterrupt() = Unit

    companion object {
        private const val TAG = "AlarmGuard"

        /** How close a Redemption alarm counts as already ringing. */
        private const val SOON_MILLIS = 45_000L

        private val POWER_WORDS = listOf("power off", "restart", "reboot", "switch off")

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

        /** How often limited apps' time is counted. */
        private const val TICK_MILLIS = 10_000L

        /** A late tick (the phone dozed) counts at most this much… */
        private const val MAX_TICK_GAP_MILLIS = 30_000L

        /** …unless the same app was playing all along. */
        private const val MAX_PLAYING_GAP_MILLIS = 15 * 60_000L

        /** Blocked again this soon: home didn't work. */
        private const val STUCK_MILLIS = 15_000L

        /** The app header on Settings' App info and Storage pages. */
        private val HEADER_IDS = listOf(
            "com.android.settings:id/entity_header_title",
            "com.android.settings:id/app_name",
        )

        /** Open / Uninstall / Force stop, or Clear storage / Clear cache. */
        private val ACTION_BUTTON_IDS = listOf(
            "com.android.settings:id/button1",
            "com.android.settings:id/button2",
            "com.android.settings:id/button3",
            "com.android.settings:id/button4",
            "com.android.settings:id/right_button",
            "com.android.settings:id/left_button",
        )

        private const val NOTICE_GAP_MILLIS = 4_000L

        /** Never guard longer than this, whatever goes wrong. */
        private const val MAX_GUARD_MILLIS = 60L * 60 * 1000

        /**
         * When the app last confirmed the sums are on screen (0: not yet, or
         * the app's process restarted). Set from [MainActivity].
         */
        @Volatile
        var sumsShownAt = 0L

        /** Whether the user has turned the guard on in Accessibility. */
        fun isEnabled(context: Context): Boolean {
            val me = ComponentName(context, AlarmGuardService::class.java)
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any {
                ComponentName.unflattenFromString(it) == me
            }
        }
    }
}
