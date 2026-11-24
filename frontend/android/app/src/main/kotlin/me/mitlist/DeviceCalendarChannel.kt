package me.mitlist

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Read-only access to the phone's calendars for shared household calendars
 * (lib/services/device_calendar/device_calendar_source.dart).
 *
 * Native rather than a plugin so the app asks for READ_CALENDAR alone (the
 * plugins in use need WRITE_CALENDAR too) and can read each event's access
 * level: private and confidential events must reach the household as busy
 * blocks at most. Instances are already expanded from their recurrence rules.
 */
class DeviceCalendarChannel(private val activity: Activity) {
    companion object {
        const val CHANNEL = "me.mitlist/device_calendar"
        private const val REQUEST_CODE = 4711
        private const val PREFS = "mitlist_device_calendar"
        private const val ASKED_KEY = "read_calendar_denied"

        private var instance: DeviceCalendarChannel? = null

        fun register(messenger: BinaryMessenger, activity: Activity) {
            val channel = DeviceCalendarChannel(activity)
            instance = channel
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "permission" -> result.success(channel.status())
                    "requestPermission" -> channel.request(result)
                    "openSettings" -> {
                        channel.openSettings()
                        result.success(null)
                    }
                    "calendars" -> channel.background(result) { channel.calendars() }
                    "events" -> {
                        val from = (call.argument<Number>("from"))?.toLong()
                        val to = (call.argument<Number>("to"))?.toLong()
                        if (from == null || to == null || to < from) {
                            result.error("invalid_range", "from/to are required.", null)
                        } else {
                            channel.background(result) { channel.events(from, to) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
            if (requestCode != REQUEST_CODE) return false
            instance?.finishRequest(grantResults)
            return true
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    private fun granted(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun prefs() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun status(): String {
        if (granted()) return "granted"
        val deniedBefore = prefs().getBoolean(ASKED_KEY, false)
        val canAsk = ActivityCompat.shouldShowRequestPermissionRationale(
            activity, Manifest.permission.READ_CALENDAR,
        )
        // Denied before and the system will no longer show its dialog.
        return if (deniedBefore && !canAsk) "denied" else "notDetermined"
    }

    fun request(result: MethodChannel.Result) {
        if (granted()) {
            result.success("granted")
            return
        }
        if (pending != null) {
            result.error("busy", "A permission request is already showing.", null)
            return
        }
        pending = result
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CODE,
        )
    }

    fun finishRequest(grantResults: IntArray) {
        val result = pending ?: return
        pending = null
        if (grantResults.isEmpty()) {
            // Dismissed without an answer.
            result.success(status())
            return
        }
        if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
        } else {
            prefs().edit().putBoolean(ASKED_KEY, true).apply()
            result.success("denied")
        }
    }

    fun openSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", activity.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    fun background(result: MethodChannel.Result, work: () -> Any?) {
        if (!granted()) {
            result.error("permission_denied", "Calendar access was not granted.", null)
            return
        }
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: SecurityException) {
                main.post { result.error("permission_denied", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }
    }

    fun calendars(): List<Map<String, Any?>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.CALENDAR_COLOR,
        )
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projection, null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val color = if (c.isNull(2)) null else String.format("#%06X", 0xFFFFFF and c.getInt(2))
                out.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "name" to (c.getString(1) ?: ""),
                        "color" to color,
                    ),
                )
            }
        }
        return out
    }

    fun events(from: Long, to: Long): List<Map<String, Any?>> {
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.AVAILABILITY,
            CalendarContract.Instances.STATUS,
            CalendarContract.Instances.ACCESS_LEVEL,
        )
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(uri, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val access = if (c.isNull(8)) CalendarContract.Events.ACCESS_DEFAULT else c.getInt(8)
                out.add(
                    mapOf(
                        "eventId" to c.getLong(0).toString(),
                        "calendarId" to c.getLong(1).toString(),
                        "title" to (c.getString(2) ?: ""),
                        "begin" to c.getLong(3),
                        "end" to (if (c.isNull(4)) c.getLong(3) else c.getLong(4)),
                        "allDay" to (c.getInt(5) != 0),
                        "free" to (!c.isNull(6) && c.getInt(6) == CalendarContract.Events.AVAILABILITY_FREE),
                        "cancelled" to (!c.isNull(7) && c.getInt(7) == CalendarContract.Events.STATUS_CANCELED),
                        "private" to (access == CalendarContract.Events.ACCESS_PRIVATE ||
                            access == CalendarContract.Events.ACCESS_CONFIDENTIAL),
                    ),
                )
            }
        }
        return out
    }
}
