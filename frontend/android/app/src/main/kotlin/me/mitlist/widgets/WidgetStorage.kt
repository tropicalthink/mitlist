package me.mitlist.widgets

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/** Where widget data lives (contract C4, Android). */
object WidgetFiles {
    fun dir(context: Context): File = File(context.applicationContext.filesDir, "widgets")

    fun queue(context: Context) = PendingOpsQueue(dir(context))

    fun snapshot(context: Context) = SnapshotStore(dir(context))
}

/**
 * Bumped after every write to the snapshot, the queue or the flags. Running
 * Glance sessions collect it, so a widget that is on screen recomposes with
 * the new data instead of keeping what it read when the session started.
 */
object WidgetData {
    private val _version = MutableStateFlow(0L)
    val version: StateFlow<Long> = _version

    fun bump() {
        _version.value = _version.value + 1
    }
}

/** `<filesDir>/widgets/snapshot.json`, written atomically. */
class SnapshotStore(private val dir: File) {
    private val file get() = File(dir, FILE_NAME)

    fun read(): WidgetSnapshot? {
        val f = file
        if (!f.exists()) return null
        return try {
            WidgetSnapshot.parse(f.readText(Charsets.UTF_8))
        } catch (_: Exception) {
            null
        }
    }

    /** Validates [json] as a snapshot, then replaces the file. */
    fun write(json: String): WidgetSnapshot {
        val parsed = WidgetSnapshot.parse(json)
        dir.mkdirs()
        synchronized(lock) {
            val tmp = File(dir, "$FILE_NAME.tmp")
            tmp.writeText(json, Charsets.UTF_8)
            if (!tmp.renameTo(file)) {
                file.delete()
                if (!tmp.renameTo(file)) error("could not replace $FILE_NAME")
            }
        }
        return parsed
    }

    fun delete() {
        synchronized(lock) { file.delete() }
    }

    companion object {
        const val FILE_NAME = "snapshot.json"
        private val lock = Any()
    }
}

/** Flags shared by widgets, workers and the channel (C4: `mitlist_widget_state`). */
class WidgetStateStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var authFailed: Boolean
        get() = prefs.getBoolean(KEY_AUTH_FAILED, false)
        set(value) = prefs.edit().putBoolean(KEY_AUTH_FAILED, value).apply()

    /** Epoch millis of the last snapshot written, 0 when none. */
    var lastFetchAt: Long
        get() = prefs.getLong(KEY_LAST_FETCH_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_FETCH_AT, value).apply()

    var refreshRequested: Boolean
        get() = prefs.getBoolean(KEY_REFRESH_REQUESTED, false)
        set(value) = prefs.edit().putBoolean(KEY_REFRESH_REQUESTED, value).apply()

    /** App version code whose generated widget previews were published. */
    var previewsPublishedFor: Long
        get() = prefs.getLong(KEY_PREVIEWS_VERSION, -1L)
        set(value) = prefs.edit().putLong(KEY_PREVIEWS_VERSION, value).apply()

    fun clear() {
        prefs.edit()
            .remove(KEY_AUTH_FAILED)
            .remove(KEY_LAST_FETCH_AT)
            .remove(KEY_REFRESH_REQUESTED)
            .apply()
    }

    companion object {
        const val PREFS = "mitlist_widget_state"
        private const val KEY_AUTH_FAILED = "auth_failed"
        private const val KEY_LAST_FETCH_AT = "last_fetch_at"
        private const val KEY_REFRESH_REQUESTED = "refresh_requested"
        private const val KEY_PREVIEWS_VERSION = "previews_version"
    }
}

/** Per-widget household/list choice (C4: `mitlist_widget_config`). */
class WidgetConfigStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun householdId(appWidgetId: Int): String? = prefs.getString("$appWidgetId.household_id", null)

    fun listId(appWidgetId: Int): String? = prefs.getString("$appWidgetId.list_id", null)

    fun set(appWidgetId: Int, householdId: String?, listId: String?) {
        prefs.edit().apply {
            if (householdId != null) putString("$appWidgetId.household_id", householdId) else remove("$appWidgetId.household_id")
            if (listId != null) putString("$appWidgetId.list_id", listId) else remove("$appWidgetId.list_id")
        }.apply()
    }

    fun remove(appWidgetId: Int) = set(appWidgetId, null, null)

    companion object {
        const val PREFS = "mitlist_widget_config"
    }
}
