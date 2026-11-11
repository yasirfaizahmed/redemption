package io.github.yasirfaizahmed.redemption

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
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

    private val ringing: Boolean
        get() = AlarmService.ringingAlarmIds.isNotEmpty()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !ringing) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        val cls = event.className?.toString() ?: ""
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

        private val POWER_WORDS = listOf(
            "power off", "restart", "reboot", "emergency mode", "switch off",
        )

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
