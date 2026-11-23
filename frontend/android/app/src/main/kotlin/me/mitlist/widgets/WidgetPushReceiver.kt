package me.mitlist.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The "household changed" push (contract C6).
 *
 * Why a receiver and not a FirebaseMessagingService: Play services delivers
 * an FCM message as a `com.google.android.c2dm.intent.RECEIVE` broadcast
 * addressed to this package (not to one component), so every receiver here
 * with that filter and the c2dm SEND permission gets it: firebase-messaging
 * 25's FirebaseInstanceIdReceiver, FlutterFire 16's
 * FlutterFirebaseMessagingReceiver (how the app's own pushes reach Dart) and
 * this one. Only one MESSAGING_EVENT service can win, and FlutterFire already
 * declares one, so a second service would be the unreliable path. If this
 * broadcast stopped arriving, FlutterFire's messaging would stop with it.
 *
 * The refresh runs right here (goAsync), not only as WorkManager work: an app
 * in a rare or restricted standby bucket can have its jobs deferred for
 * hours, which reads as "my partner's changes never show". The worker is the
 * fallback when the fetch does not finish in time.
 */
class WidgetPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getStringExtra("type") != TYPE) return
        val app = context.applicationContext
        if (!WidgetUpdater.hasAnyWidget(app)) return
        WidgetStateStore(app).refreshRequested = true
        val pending = goAsync()
        WidgetScope.launch {
            try {
                val sync = WidgetScope.async { WidgetSync.run(app, forceFetch = true) }
                // A blocking HTTP call cannot be cancelled: wait on it, not in it.
                val result = withTimeoutOrNull(INLINE_BUDGET_MILLIS) { sync.await() }
                if (result != WidgetSync.Result.DONE) {
                    WidgetSyncScheduler.syncNow(app, forceFetch = true, expedited = false)
                }
            } catch (e: Exception) {
                Log.w(TAG, "inline refresh failed", e)
                WidgetSyncScheduler.syncNow(app, forceFetch = true, expedited = false)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val TYPE = "widget_refresh"
        private const val TAG = "MitlistWidgetPush"

        /** Well inside the ~10 s a broadcast receiver may run. */
        private const val INLINE_BUDGET_MILLIS = 8_000L
    }
}
