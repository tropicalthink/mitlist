package me.mitlist.widgets

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * RFC 3339 timestamps as Go writes them ("2026-10-02T09:00:00Z",
 * "2026-10-02T09:00:00.123456789+02:00"). java.time needs API 26 or core
 * library desugaring, and the app's minSdk is 24, so this parses by hand.
 */
object Rfc3339 {
    private val pattern = Regex(
        """^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(\.\d+)?([Zz]|[+-]\d{2}:\d{2})$""",
    )

    fun parseMillis(value: String): Long? {
        val m = pattern.matchEntire(value.trim()) ?: return null
        val g = m.groupValues
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"), Locale.US)
        cal.clear()
        cal.set(g[1].toInt(), g[2].toInt() - 1, g[3].toInt(), g[4].toInt(), g[5].toInt(), g[6].toInt())
        var millis = cal.timeInMillis
        val fraction = g[7]
        if (fraction.isNotEmpty()) {
            millis += (fraction.substring(1).padEnd(3, '0').take(3)).toLong()
        }
        val zone = g[8]
        if (zone != "Z" && zone != "z") {
            val sign = if (zone[0] == '-') -1 else 1
            val offsetMinutes = zone.substring(1, 3).toInt() * 60 + zone.substring(4, 6).toInt()
            millis -= sign * offsetMinutes * 60_000L
        }
        return millis
    }

    /** UTC, second precision: "2026-10-02T09:00:00Z". */
    fun format(millis: Long): String {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"), Locale.US)
        cal.timeInMillis = millis
        return String.format(
            Locale.US,
            "%04d-%02d-%02dT%02d:%02d:%02dZ",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE),
            cal.get(Calendar.SECOND),
        )
    }
}
