package io.github.yasirfaizahmed.redemption

import android.content.Context
import android.os.Build
import android.os.SystemClock
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

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
        val e = prefs(c).edit()
        for ((id, n) in wanted) e.putInt("quota.$id", n)
        return if (e.commit()) null else "Couldn't save the limits."
    }

    /**
     * Now, from the network's clock when the phone knows it (Android 13+), so
     * moving the phone's clock forward doesn't start a new day early.
     */
    private fun trustedNow(): Long {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                return SystemClock.currentNetworkTimeClock().millis()
            } catch (e: Exception) {
                // No network time yet: the phone's clock it is.
            }
        }
        return System.currentTimeMillis()
    }

    private fun dayOf(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

    /**
     * The day being counted. A later day starts afresh; an earlier one (the
     * clock moved back) keeps counting against the later day.
     */
    @Synchronized
    fun currentDay(c: Context): String {
        val p = prefs(c)
        val today = dayOf(trustedNow())
        val stored = p.getString("day", null)
        if (stored != null && today <= stored) return stored
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
