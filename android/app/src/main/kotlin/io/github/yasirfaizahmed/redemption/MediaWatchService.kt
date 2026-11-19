package io.github.yasirfaizahmed.redemption

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService

/**
 * "Redemption app limits": turned on as Notification access, Android keeps
 * it connected, and it runs the daily app limits ([LimitsEngine]) — seeing
 * which limited app plays in the background as well. It reads no
 * notifications.
 */
class MediaWatchService : NotificationListenerService() {
    private var engine: LimitsEngine? = null

    /** Unlocking a used-up app is caught at once, not at the next idle round. */
    private val unlocked = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            engine?.nudge()
        }
    }
    private var listening = false

    override fun onListenerConnected() {
        super.onListenerConnected()
        engine?.stop()
        engine = LimitsEngine(this, component(this)).also { it.start() }
        if (!listening) {
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
    }

    override fun onListenerDisconnected() {
        shutDown()
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        shutDown()
        super.onDestroy()
    }

    private fun shutDown() {
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
    }

    companion object {
        fun component(context: Context) = ComponentName(context, MediaWatchService::class.java)

        fun isEnabled(context: Context): Boolean {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val me = component(context)
            return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
        }
    }
}
