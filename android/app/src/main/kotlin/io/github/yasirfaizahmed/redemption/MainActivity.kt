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
        // A guard switched on for an alarm that's no longer ringing (the app
        // was closed mid-alarm): off again, so payments work.
        if (AlarmService.ringingAlarmIds.isEmpty()) AlarmGuardService.switchOffIfAutoOn(this)
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
                        AlarmGuardService.switchOnForRinging(this)
                        result.success(null)
                    }
                    // Solved: the journal goes back behind the lock screen.
                    "ringingEnded" -> {
                        AlarmGuardService.sumsShownAt = 0L
                        AlarmGuardService.switchOffIfAutoOn(this)
                        showOverLockScreenIfRinging()
                        result.success(null)
                    }
                    "openSetting" -> result.success(openSetting(call.argument<String>("which") ?: ""))
                    // Daily app limits: what's set, what's used, what's needed.
                    "limits" -> result.success(limits())
                    "setLimits" -> {
                        val raw = call.argument<Map<String, Int>>("quotas") ?: emptyMap()
                        result.success(AppLimits.setQuotas(this, raw))
                    }
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
            "guardAuto" to AlarmGuardService.canSwitch(this),
            // On by hand, with no alarm ringing: payment apps refuse to work.
            "guardAlwaysOn" to (
                AlarmGuardService.isEnabled(this) &&
                    !AlarmGuardService.autoOn(this) &&
                    AlarmService.ringingAlarmIds.isEmpty()
                ),
            "battery" to power?.isIgnoringBatteryOptimizations(packageName),
        )
    }

    private fun limits(): Map<String, Any?> {
        val autoTime = try {
            Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME) == 1
        } catch (e: Settings.SettingNotFoundException) {
            null
        }
        return mapOf(
            "day" to AppLimits.currentDay(this),
            "quotas" to AppLimits.quotas(this),
            "used" to AppLimits.used(this),
            "mediaAccess" to MediaWatchService.isEnabled(this),
            "usageAccess" to LimitsEngine.hasUsageAccess(this),
            "overlay" to Settings.canDrawOverlays(this),
            "autoTime" to autoTime,
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
            "mediaAccess" -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        MediaWatchService.component(this).flattenToString(),
                    )
                } else {
                    null
                },
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            )
            "dateTime" -> listOf(Intent(Settings.ACTION_DATE_SETTINGS))
            "usageAccess" -> listOf(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, pkg),
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
            )
            "overlay" -> listOf(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkg),
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
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
