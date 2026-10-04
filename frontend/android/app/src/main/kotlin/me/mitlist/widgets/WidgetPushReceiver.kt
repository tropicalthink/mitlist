package me.mitlist.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The "household changed" push (contract C6). FCM data messages arrive as a
 * `com.google.android.c2dm.intent.RECEIVE` broadcast, which every matching
 * receiver in the app gets; FlutterFire's own receiver works the same way.
 * Handling it here refreshes widgets without booting a Dart engine.
 */
class WidgetPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getStringExtra("type") != TYPE) return
        if (!WidgetUpdater.hasAnyWidget(context)) return
        WidgetStateStore(context).refreshRequested = true
        WidgetSyncScheduler.syncNow(context, forceFetch = true, expedited = false)
    }

    companion object {
        const val TYPE = "widget_refresh"
    }
}
