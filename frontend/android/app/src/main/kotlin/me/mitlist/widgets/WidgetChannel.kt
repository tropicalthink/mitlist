package me.mitlist.widgets

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The app side of the widget bridge: `me.mitlist/widgets` (contract C4).
 * Dart calls in while the app is in the foreground; nothing calls back.
 */
class WidgetChannel private constructor(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        WidgetScope.launch {
            try {
                val value = withContext(Dispatchers.IO) { handle(call) }
                withContext(Dispatchers.Main) {
                    if (value === NotImplemented) result.notImplemented() else result.success(value)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("widget_error", e.message, null) }
            }
        }
    }

    private suspend fun handle(call: MethodCall): Any? {
        val state = WidgetStateStore(context)
        return when (call.method) {
            "setCredential" -> {
                val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException("credential map required")
                val credential = WidgetCredential.fromMap(args) ?: throw IllegalArgumentException("token and api_base_url required")
                CredentialStore.save(context, credential)
                state.authFailed = false
                WidgetUpdater.updateAll(context)
                // Anything a widget queued while the credential was missing or
                // dead can go now.
                if (WidgetFiles.queue(context).readAll().any { it.state == OpState.PENDING }) {
                    WidgetSyncScheduler.syncNow(context)
                }
                null
            }
            "clearAll" -> {
                WidgetSyncScheduler.cancelAll(context)
                CredentialStore.clear(context)
                WidgetFiles.snapshot(context).delete()
                WidgetFiles.queue(context).clear()
                state.clear()
                WidgetUpdater.updateAll(context)
                null
            }
            "writeSnapshot" -> {
                val json = call.argument<String>("json") ?: throw IllegalArgumentException("json required")
                WidgetFiles.snapshot(context).write(json)
                state.refreshRequested = false
                state.lastFetchAt = System.currentTimeMillis()
                WidgetUpdater.updateAll(context)
                if (WidgetUpdater.hasAnyWidget(context)) WidgetSyncScheduler.ensurePeriodic(context)
                WidgetPreviews.publishIfNeeded(context)
                null
            }
            "readPendingOps" -> {
                val queue = WidgetFiles.queue(context)
                queue.prune(System.currentTimeMillis())
                queue.readLines()
            }
            "ackPendingOps" -> {
                val ids = call.argument<List<String>>("op_ids") ?: emptyList()
                WidgetFiles.queue(context).remove(ids)
                WidgetUpdater.updateAll(context)
                null
            }
            "consumeAuthFailure" -> {
                val failed = state.authFailed
                state.authFailed = false
                if (failed) WidgetUpdater.updateAll(context)
                failed
            }
            "hasCredential" -> CredentialStore.hasValid(context)
            "reloadWidgets" -> {
                WidgetUpdater.updateAll(context)
                null
            }
            "requestRefresh" -> {
                state.refreshRequested = true
                WidgetSyncScheduler.syncNow(context, forceFetch = true, expedited = false)
                null
            }
            // Live Activities are iOS only (C4).
            "startShoppingTrip", "updateShoppingTrip", "endShoppingTrip" -> null
            else -> NotImplemented
        }
    }

    private object NotImplemented

    companion object {
        const val NAME = "me.mitlist/widgets"

        fun register(messenger: BinaryMessenger, context: Context) {
            MethodChannel(messenger, NAME).setMethodCallHandler(WidgetChannel(context.applicationContext))
        }
    }
}
