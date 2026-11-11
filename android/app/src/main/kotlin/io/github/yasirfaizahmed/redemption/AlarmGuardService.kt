package io.github.yasirfaizahmed.redemption

import android.accessibilityservice.AccessibilityService
import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import com.gdelataillade.alarm.alarm.AlarmService

/**
 * "Alarm guard": while a wake-up alarm rings, and only then, keeps the user
 * on Redemption's sums. It closes the power menu (no switching off), the
 * uninstall dialog and Settings (no uninstalling or force-stopping), takes
 * them back from any other app, and swallows the volume keys.
 *
 * The user turns it on in Accessibility settings. It reads nothing and does
 * nothing while no alarm rings. A forced restart (holding power ~10 s) is
 * done by the hardware and can't be stopped by any app; the alarm rings
 * again when the phone is back on.
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

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !ringing) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
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
