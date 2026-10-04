package me.mitlist.widgets

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.IOException

/**
 * Delivers queued ops and refreshes the snapshot with the widget credential
 * (D4 step 3–4, contract C4). Runs only inside [WidgetSyncWorker], and one
 * pass at a time, so an op is never in flight twice.
 */
object WidgetSync {
    private const val TAG = "MitlistWidgetSync"

    /** A snapshot younger than this is not refetched unless something changed. */
    private const val FRESH_MILLIS = 2_000L

    private val mutex = Mutex()

    enum class Result {
        /** Nothing left to deliver (or nothing can be: no credential, or a 401). */
        DONE,

        /** Some op is still pending because the server could not be reached. */
        RETRY,
    }

    suspend fun run(context: Context, forceFetch: Boolean = false): Result = mutex.withLock {
        withContext(Dispatchers.IO) { runLocked(context.applicationContext, forceFetch) }
    }

    private suspend fun runLocked(context: Context, forceFetch: Boolean): Result {
        val queue = WidgetFiles.queue(context)
        val state = WidgetStateStore(context)
        val now = System.currentTimeMillis()
        queue.prune(now)

        val credential = CredentialStore.load(context)
        if (credential == null) {
            // Ops stay queued: the app imports and delivers them on next open.
            WidgetUpdater.updateAll(context)
            return Result.DONE
        }
        val api = WidgetApi(credential)

        var delivered = false
        var result = Result.DONE
        // Re-read after each op: a tick made while this pass runs is picked up
        // by the same pass instead of waiting for another trigger.
        val attempted = HashSet<String>()
        while (true) {
            val op = queue.readAll().firstOrNull { it.state == OpState.PENDING && it.opId !in attempted } ?: break
            attempted += op.opId
            val outcome = try {
                val response = api.send(op)
                when (DeliveryOutcome.fromStatus(response.status, response.retryAfter)) {
                    DeliveryOutcome.DELIVERED -> {
                        queue.replace(op.delivered(System.currentTimeMillis(), response.body))
                        delivered = true
                        DeliveryOutcome.DELIVERED
                    }
                    DeliveryOutcome.FAILED -> {
                        Log.w(TAG, "op ${op.type} rejected with ${response.status}")
                        queue.replace(op.failed(response.status))
                        DeliveryOutcome.FAILED
                    }
                    DeliveryOutcome.AUTH_FAILED -> {
                        queue.replace(op.retried("401"))
                        DeliveryOutcome.AUTH_FAILED
                    }
                    DeliveryOutcome.RETRY -> {
                        queue.replace(op.retried(response.status.toString()))
                        DeliveryOutcome.RETRY
                    }
                }
            } catch (e: IOException) {
                queue.replace(op.retried("network"))
                DeliveryOutcome.RETRY
            }
            WidgetData.bump()
            if (outcome == DeliveryOutcome.AUTH_FAILED) {
                // The credential is dead: stop, keep everything for the app.
                state.authFailed = true
                WidgetUpdater.updateAll(context)
                return Result.DONE
            }
            if (outcome == DeliveryOutcome.RETRY) {
                // Keep per-entity order: if one op cannot get through, the rest wait.
                result = Result.RETRY
                break
            }
        }

        val stale = now - state.lastFetchAt > FRESH_MILLIS
        if (result == Result.DONE && (forceFetch || delivered || state.refreshRequested || stale)) {
            try {
                val response = api.fetchSnapshot()
                when {
                    response.status == 200 && response.body != null -> {
                        WidgetFiles.snapshot(context).write(response.body)
                        state.refreshRequested = false
                        state.lastFetchAt = System.currentTimeMillis()
                        state.authFailed = false
                    }
                    response.status == 401 -> state.authFailed = true
                    response.status >= 500 -> result = Result.RETRY
                    else -> Log.w(TAG, "snapshot fetch returned ${response.status}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "snapshot fetch failed: ${e.javaClass.simpleName}")
                if (state.refreshRequested) result = Result.RETRY
            }
        }

        WidgetUpdater.updateAll(context)
        return result
    }
}
