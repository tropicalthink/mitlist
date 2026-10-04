package me.mitlist.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Process-wide scope for fire-and-forget widget work (channel calls, app start). */
object WidgetScope : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default)

object WidgetUpdater {
    private const val TAG = "MitlistWidgets"

    val receivers: List<Class<out GlanceAppWidgetReceiver>> = listOf(
        ShoppingListWidgetReceiver::class.java,
        ChoresWidgetReceiver::class.java,
        HouseholdTodayWidgetReceiver::class.java,
        BalanceWidgetReceiver::class.java,
        QuickAddWidgetReceiver::class.java,
    )

    private fun widgets(): List<GlanceAppWidget> = listOf(
        ShoppingListWidget(),
        ChoresWidget(),
        HouseholdTodayWidget(),
        BalanceWidget(),
        QuickAddWidget(),
    )

    /** Re-renders every placed widget from the files on disk. */
    suspend fun updateAll(context: Context) {
        WidgetData.bump()
        for (widget in widgets()) {
            try {
                widget.updateAll(context.applicationContext)
            } catch (e: Exception) {
                Log.w(TAG, "update ${widget.javaClass.simpleName} failed", e)
            }
        }
    }

    fun updateAllAsync(context: Context) {
        val app = context.applicationContext
        WidgetScope.launch { updateAll(app) }
    }

    fun hasAnyWidget(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return receivers.any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
    }

    /**
     * App start: re-push every widget (Android 15 cancels a widget's
     * PendingIntents when the app is force-stopped) and keep the backstop.
     */
    fun onAppStart(context: Context) {
        val app = context.applicationContext
        WidgetScope.launch {
            updateAll(app)
            if (hasAnyWidget(app)) WidgetSyncScheduler.ensurePeriodic(app)
        }
    }
}

/** Shared receiver behaviour: the hourly backstop and per-widget config cleanup. */
abstract class MitlistWidgetReceiver : GlanceAppWidgetReceiver() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetSyncScheduler.ensurePeriodic(context)
        // A first widget with no data yet: fetch now rather than in an hour.
        if (CredentialStore.has(context) && WidgetFiles.snapshot(context).read() == null) {
            WidgetSyncScheduler.syncNow(context, forceFetch = true, expedited = false)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        if (!WidgetUpdater.hasAnyWidget(context)) WidgetSyncScheduler.cancelPeriodic(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val config = WidgetConfigStore(context)
        appWidgetIds.forEach(config::remove)
    }
}

// ---------------------------------------------------------------------------
// Tap actions (D4): change what the widget shows, queue, deliver.
// ---------------------------------------------------------------------------

object WidgetActionKeys {
    val household = ActionParameters.Key<String>("household_id")
    val list = ActionParameters.Key<String>("list_id")
    val item = ActionParameters.Key<String>("item_id")
    val chore = ActionParameters.Key<String>("chore_id")
}

/** Ticks a list item off. */
class ToggleItemAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val household = parameters[WidgetActionKeys.household] ?: return
        val list = parameters[WidgetActionKeys.list] ?: return
        val item = parameters[WidgetActionKeys.item] ?: return
        enqueue(context, PendingOp.checkItem(household, list, item, System.currentTimeMillis()))
    }
}

/** Marks a chore done. */
class CompleteChoreAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val household = parameters[WidgetActionKeys.household] ?: return
        val chore = parameters[WidgetActionKeys.chore] ?: return
        enqueue(context, PendingOp.completeChore(household, chore, System.currentTimeMillis()))
    }
}

/** The manual refresh button. */
class RefreshAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        WidgetStateStore(context).refreshRequested = true
        WidgetSyncScheduler.syncNow(context, forceFetch = true)
    }
}

/** Steps 1–4 of D4 for an op made on this device (widgets and quick add). */
suspend fun enqueue(context: Context, op: PendingOp) {
    val app = context.applicationContext
    WidgetFiles.queue(app).append(op)
    // The overlay shows the change at once; delivery follows with network.
    WidgetUpdater.updateAll(app)
    WidgetSyncScheduler.syncNow(app)
}

/** Opens [intent] from a non-activity context. */
fun Context.startLink(intent: Intent) {
    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}
