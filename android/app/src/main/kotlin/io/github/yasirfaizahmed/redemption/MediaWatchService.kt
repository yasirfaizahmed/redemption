package io.github.yasirfaizahmed.redemption

import android.content.ComponentName
import android.content.Context
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

    override fun onListenerConnected() {
        super.onListenerConnected()
        engine?.stop()
        engine = LimitsEngine(this, component(this)).also { it.start() }
    }

    override fun onListenerDisconnected() {
        engine?.stop()
        engine = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        engine?.stop()
        engine = null
        super.onDestroy()
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
