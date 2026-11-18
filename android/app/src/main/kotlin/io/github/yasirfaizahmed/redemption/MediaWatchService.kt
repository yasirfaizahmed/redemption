package io.github.yasirfaizahmed.redemption

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService

/**
 * Turned on as "Notification access", this lets the alarm guard see which
 * app is playing music or video in the background, so listening counts
 * towards the app's daily limit and stops when it is used up. It reads no
 * notifications.
 */
class MediaWatchService : NotificationListenerService() {
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
