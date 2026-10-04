package me.mitlist.widgets

import android.app.Activity
import android.os.Bundle
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.runBlocking
import java.io.File

/**
 * Debug builds only: drives the widgets from adb without the Flutter side.
 *
 * ```
 * adb shell am start -n me.mitlist/me.mitlist.widgets.WidgetDebugActivity --es pin shopping
 * adb shell am start -n me.mitlist/me.mitlist.widgets.WidgetDebugActivity --es snapshot widgets/import.json
 * adb shell am start -n me.mitlist/me.mitlist.widgets.WidgetDebugActivity \
 *     --es token ml_int_test --es base_url http://10.0.2.2:8000/api/v1 --es expires_at 2030-01-01T00:00:00Z
 * adb shell am start -n me.mitlist/me.mitlist.widgets.WidgetDebugActivity --ez sync true
 * adb shell am start -n me.mitlist/me.mitlist.widgets.WidgetDebugActivity --ez clear true
 * ```
 * `snapshot` is a path relative to the app's files dir (copy it there with
 * `adb shell run-as me.mitlist`).
 */
class WidgetDebugActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = applicationContext
        runBlocking {
            intent.getStringExtra("snapshot")?.let { path ->
                WidgetFiles.snapshot(app).write(File(filesDir, path).readText())
                WidgetStateStore(app).lastFetchAt = System.currentTimeMillis()
                Log.i(TAG, "snapshot loaded from $path")
            }
            intent.getStringExtra("token")?.let { token ->
                CredentialStore.save(
                    app,
                    WidgetCredential(
                        token = token,
                        expiresAt = intent.getStringExtra("expires_at"),
                        apiBaseUrl = intent.getStringExtra("base_url") ?: "http://10.0.2.2:8000/api/v1",
                        userId = null,
                        deviceId = "debug",
                    ),
                )
                Log.i(TAG, "credential set")
            }
            if (intent.getBooleanExtra("clear", false)) {
                CredentialStore.clear(app)
                WidgetFiles.snapshot(app).delete()
                WidgetFiles.queue(app).clear()
                WidgetStateStore(app).clear()
                Log.i(TAG, "cleared")
            }
            WidgetUpdater.updateAll(app)
            if (intent.getBooleanExtra("sync", false)) WidgetSyncScheduler.syncNow(app, forceFetch = true)
            intent.getStringExtra("pin")?.let { kind ->
                val receiver = when (kind) {
                    "shopping" -> ShoppingListWidgetReceiver::class.java
                    "chores" -> ChoresWidgetReceiver::class.java
                    "today" -> HouseholdTodayWidgetReceiver::class.java
                    "balance" -> BalanceWidgetReceiver::class.java
                    else -> QuickAddWidgetReceiver::class.java
                }
                val ok = GlanceAppWidgetManager(app).requestPinGlanceAppWidget(receiver)
                Log.i(TAG, "pin $kind requested: $ok")
            }
        }
        finish()
    }

    companion object {
        private const val TAG = "MitlistWidgetDebug"
    }
}
