package me.mitlist.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import kotlinx.coroutines.launch

/**
 * "Add to home screen" from the app's Widgets page (channel methods
 * `isPinWidgetSupported` and `pinWidget`). The launcher shows the widget's
 * picker preview (previewLayout, or the generated preview on Android 15+) in
 * its confirmation sheet.
 */
object WidgetPinning {
    private const val TAG = "MitlistWidgetPin"

    fun isSupported(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported
    }

    fun receiverFor(kind: String): Class<out GlanceAppWidgetReceiver>? = when (kind) {
        WidgetUpdater.KIND_SHOPPING_LIST -> ShoppingListWidgetReceiver::class.java
        WidgetUpdater.KIND_CHORES -> ChoresWidgetReceiver::class.java
        WidgetUpdater.KIND_QUICK_ADD -> QuickAddWidgetReceiver::class.java
        WidgetUpdater.KIND_HOUSEHOLD -> HouseholdTodayWidgetReceiver::class.java
        else -> null
    }

    /** True when the launcher accepted the request (its sheet is showing). */
    fun request(context: Context, kind: String): Boolean {
        val receiver = receiverFor(kind) ?: throw IllegalArgumentException("unknown widget kind: $kind")
        if (!isSupported(context)) return false
        // Mutable: the launcher adds EXTRA_APPWIDGET_ID to it. Explicit, so
        // allowed as mutable on Android 12-15.
        val callback = PendingIntent.getBroadcast(
            context,
            kind.hashCode(),
            Intent(context, WidgetPinnedReceiver::class.java).putExtra(WidgetPinnedReceiver.EXTRA_KIND, kind),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0),
        )
        return try {
            AppWidgetManager.getInstance(context).requestPinAppWidget(ComponentName(context, receiver), null, callback)
        } catch (e: Exception) {
            // Some launchers throw when the app is not in the foreground.
            Log.w(TAG, "requestPinAppWidget failed", e)
            false
        }
    }

    /**
     * A pinned widget skips WidgetConfigActivity, so bind it now to what the
     * person is looking at: the app's current household (Flutter's
     * shared_preferences file, `current_group_id`) and the list last used from a
     * widget, falling back to the snapshot defaults. Bound by id (D7), so
     * switching household in the app later does not move it.
     */
    fun bindDefaults(context: Context, appWidgetId: Int) {
        val snapshot = WidgetFiles.snapshot(context).read() ?: return
        val current = appCurrentHouseholdId(context)
        val household = snapshot.household(current) ?: snapshot.resolveHousehold(null) ?: return
        val lastList = WidgetStateStore(context).lastListId?.takeIf { id -> household.lists.any { it.id == id } }
        val list = lastList ?: snapshot.resolveList(household.id, null)?.takeIf { it.first.id == household.id }?.second?.id
        WidgetConfigStore(context).set(appWidgetId, household.id, list)
    }

    /** The household the app last showed (router.dart, `current_group_id`). */
    private fun appCurrentHouseholdId(context: Context): String? = try {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.current_group_id", null)
    } catch (_: Exception) {
        null
    }
}

/** The launcher placed a widget we asked it to pin. */
class WidgetPinnedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val app = context.applicationContext
        val pending = goAsync()
        WidgetScope.launch {
            try {
                WidgetPinning.bindDefaults(app, appWidgetId)
                WidgetUpdater.updateAll(app)
                WidgetSyncScheduler.ensurePeriodic(app)
                WidgetSyncScheduler.refreshIfStale(app)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val EXTRA_KIND = "me.mitlist.widgets.KIND"
    }
}
