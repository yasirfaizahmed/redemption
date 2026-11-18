package io.github.yasirfaizahmed.redemption

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Daily time limits for the apps that eat the day.
 *
 * Kept here, not in Dart, so nothing the app's UI does can loosen them: a
 * limit, once set, can only be made stricter (fewer minutes) — never raised
 * or removed. Each day's use is counted from midnight to midnight.
 */
object AppLimits {
    data class Group(val id: String, val packages: List<String>)

    /** Each group shares one quota (YouTube and its Vanced builds, …). */
    val GROUPS = listOf(
        Group(
            "chrome",
            listOf("com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary"),
        ),
        Group("instagram", listOf("com.instagram.android", "com.instagram.lite")),
        Group(
            "youtube",
            listOf(
                "com.google.android.youtube",
                "com.vanced.android.youtube",
                "app.revanced.android.youtube",
                "app.rvx.android.youtube",
            ),
        ),
        Group(
            "ytmusic",
            listOf(
                "com.google.android.apps.youtube.music",
                "com.vanced.android.apps.youtube.music",
                "app.revanced.android.apps.youtube.music",
                "app.rvx.android.apps.youtube.music",
            ),
        ),
        Group("spotify", listOf("com.spotify.music", "com.spotify.lite")),
    )

    /** The longest quota anyone could want: a whole day. */
    const val MAX_MINUTES = 24 * 60

    private const val PREFS = "redemption_app_limits"

    fun groupOf(pkg: String): Group? = GROUPS.firstOrNull { pkg in it.packages }

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Minutes a day per group id; only groups with a limit. */
    fun quotas(c: Context): Map<String, Int> {
        val p = prefs(c)
        return GROUPS.mapNotNull { g ->
            val q = p.getInt("quota.${g.id}", -1)
            if (q >= 0) g.id to q else null
        }.toMap()
    }

    /**
     * Saves [wanted]. A limit already set can only go down and can't be left
     * out. Returns null when saved, or why it wasn't.
     */
    @Synchronized
    fun setQuotas(c: Context, wanted: Map<String, Int>): String? {
        for ((id, old) in quotas(c)) {
            val n = wanted[id] ?: return "A locked limit can't be removed."
            if (n > old) return "A locked limit can't be raised."
        }
        for ((id, n) in wanted) {
            if (GROUPS.none { it.id == id }) return "Unknown app: $id"
            if (n < 0 || n > MAX_MINUTES) return "Minutes out of range: $n"
        }
        val p = prefs(c)
        val e = p.edit()
        for ((id, n) in wanted) e.putInt("quota.$id", n)
        // Midnight is the midnight of where the limits were set, so changing
        // the phone's time zone can't bring the next day sooner.
        if (!p.contains("zone")) e.putString("zone", TimeZone.getDefault().id)
        return if (e.commit()) null else "Couldn't save the limits."
    }

    /**
     * Now, and whether it's the network's word for it.
     *
     * The network's clock is trusted when Android has it (13+). Otherwise,
     * within one boot, time runs from an anchor by the phone's own uptime, so
     * changing the clock does nothing until the phone restarts.
     */
    private fun trustedNow(c: Context): Pair<Long, Boolean> {
        val p = prefs(c)
        val elapsed = SystemClock.elapsedRealtime()
        val boot = bootCount(c)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val net = SystemClock.currentNetworkTimeClock().millis()
                val sameBoot = boot != null && p.getInt("anchorBoot", -1) == boot
                val projected = p.getLong("anchorWall", 0L) + (elapsed - p.getLong("anchorElapsed", 0L))
                if (!sameBoot || kotlin.math.abs(projected - net) > 60_000L) {
                    anchor(p, boot, net, elapsed)
                }
                return net to true
            } catch (e: Exception) {
                // No network time yet.
            }
        }
        if (boot != null && p.getInt("anchorBoot", -1) == boot && p.contains("anchorWall")) {
            return p.getLong("anchorWall", 0L) + (elapsed - p.getLong("anchorElapsed", 0L)) to false
        }
        val wall = System.currentTimeMillis()
        anchor(p, boot, wall, elapsed)
        return wall to false
    }

    private fun anchor(p: android.content.SharedPreferences, boot: Int?, wall: Long, elapsed: Long) {
        p.edit()
            .putInt("anchorBoot", boot ?: -1)
            .putLong("anchorWall", wall)
            .putLong("anchorElapsed", elapsed)
            .apply()
    }

    private fun bootCount(c: Context): Int? = try {
        Settings.Global.getInt(c.contentResolver, Settings.Global.BOOT_COUNT)
    } catch (e: Exception) {
        null
    }

    private fun dayOf(c: Context, millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        prefs(c).getString("zone", null)?.let { format.timeZone = TimeZone.getTimeZone(it) }
        return format.format(Date(millis))
    }

    /**
     * The day being counted. A later day starts afresh. An earlier one keeps
     * counting against the later day — unless the network says the later day
     * was never real (a clock that had jumped ahead), so a wrong clock can't
     * freeze the limits.
     */
    @Synchronized
    fun currentDay(c: Context): String {
        val p = prefs(c)
        val (now, fromNetwork) = trustedNow(c)
        val today = dayOf(c, now)
        val stored = p.getString("day", null)
        if (stored == today) return today
        if (stored != null && today < stored) {
            if (!fromNetwork) return stored
            p.edit().putString("day", today).apply() // keep what was used
            return today
        }
        val e = p.edit().putString("day", today)
        for (g in GROUPS) e.remove("used.${g.id}")
        e.apply()
        return today
    }

    /** Milliseconds used today, per group id. */
    fun used(c: Context): Map<String, Long> {
        currentDay(c)
        val p = prefs(c)
        return GROUPS.associate { it.id to p.getLong("used.${it.id}", 0L) }
    }

    @Synchronized
    fun add(c: Context, id: String, millis: Long) {
        if (millis <= 0) return
        currentDay(c)
        val p = prefs(c)
        p.edit().putLong("used.$id", p.getLong("used.$id", 0L) + millis).apply()
    }

    /** Whether [id] has a limit and today's is used up. */
    fun isUsedUp(c: Context, id: String): Boolean {
        val q = quotas(c)[id] ?: return false
        return (used(c)[id] ?: 0L) >= q * 60_000L
    }
}
