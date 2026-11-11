package io.github.yasirfaizahmed.redemption

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.AlarmClock
import android.provider.Settings
import com.gdelataillade.alarm.alarm.AlarmService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreenIfRinging()
    }

    override fun onResume() {
        super.onResume()
        showOverLockScreenIfRinging()
    }

    /** The alarm brings back an app already open behind the lock screen. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreenIfRinging()
    }

    /** A ringing wake-up alarm shows its sums over the lock screen. */
    private fun showOverLockScreenIfRinging() =
        showOverLockScreen(AlarmService.ringingAlarmIds.isNotEmpty())

    private fun showOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) return
        setShowWhenLocked(show)
        setTurnScreenOn(show)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "redemption/alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Wake-up times: hands an alarm to the phone's Clock app.
                    "setAlarm" -> {
                        val hour = call.argument<Int>("hour")
                        val minute = call.argument<Int>("minute")
                        if (hour == null || minute == null) {
                            result.error("bad_args", "hour and minute are required", null)
                        } else {
                            result.success(setClockAlarm(hour, minute, call.argument<String>("message")))
                        }
                    }
                    // What the phone lets Redemption's own alarm do.
                    "checks" -> result.success(checks())
                    // The sums are on screen: the alarm guard may act.
                    "sumsShown" -> {
                        AlarmGuardService.sumsShownAt = System.currentTimeMillis()
                        result.success(null)
                    }
                    // Solved: the journal goes back behind the lock screen.
                    "ringingEnded" -> {
                        AlarmGuardService.sumsShownAt = 0L
                        showOverLockScreenIfRinging()
                        result.success(null)
                    }
                    "openSetting" -> result.success(openSetting(call.argument<String>("which") ?: ""))
                    else -> result.notImplemented()
                }
            }
    }

    private fun setClockAlarm(hour: Int, minute: Int, message: String?): Boolean {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_MESSAGE, message ?: "Wake up")
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    private fun checks(): Map<String, Boolean?> {
        val fullScreen: Boolean? = if (Build.VERSION.SDK_INT >= 34) {
            getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent()
        } else {
            true
        }
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val notifications = getSystemService(NotificationManager::class.java)
        return mapOf(
            "notifications" to notifications?.areNotificationsEnabled(),
            "fullScreen" to fullScreen,
            "guard" to AlarmGuardService.isEnabled(this),
            "battery" to power?.isIgnoringBatteryOptimizations(packageName),
        )
    }

    private fun openSetting(which: String): Boolean {
        val pkg = Uri.parse("package:$packageName")
        val intents = when (which) {
            "accessibility" -> listOf(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            "appInfo" -> listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
            "notifications" -> listOf(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg),
            )
            "fullScreen" -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= 34) {
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
                } else {
                    null
                },
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg),
            )
            "battery" -> listOf(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg),
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            )
            else -> emptyList()
        }
        for (intent in intents) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Try the next, more general screen.
            } catch (e: SecurityException) {
                // Try the next, more general screen.
            }
        }
        return false
    }
}
