package io.github.yasirfaizahmed.redemption

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Wake-up times: hands an alarm to the phone's Clock app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "redemption/alarm")
            .setMethodCallHandler { call, result ->
                if (call.method != "setAlarm") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val hour = call.argument<Int>("hour")
                val minute = call.argument<Int>("minute")
                if (hour == null || minute == null) {
                    result.error("bad_args", "hour and minute are required", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                    putExtra(AlarmClock.EXTRA_HOUR, hour)
                    putExtra(AlarmClock.EXTRA_MINUTES, minute)
                    putExtra(AlarmClock.EXTRA_MESSAGE, call.argument<String>("message") ?: "Wake up")
                    putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                }
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                } catch (e: SecurityException) {
                    result.success(false)
                }
            }
    }
}
