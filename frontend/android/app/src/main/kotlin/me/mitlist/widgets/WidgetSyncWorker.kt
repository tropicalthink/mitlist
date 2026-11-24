package me.mitlist.widgets

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import me.mitlist.R
import java.util.concurrent.TimeUnit

/** Runs [WidgetSync] with network, retried with backoff while ops are stuck. */
class WidgetSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val forceFetch = inputData.getBoolean(KEY_FORCE_FETCH, false)
        return when (WidgetSync.run(applicationContext, forceFetch)) {
            WidgetSync.Result.DONE -> Result.success()
            // Give up after a few tries; the periodic backstop or the next app
            // open delivers what is left.
            WidgetSync.Result.RETRY -> if (runAttemptCount < MAX_ATTEMPTS) Result.retry() else Result.success()
        }
    }

    // Expedited work runs as a foreground service before Android 12.
    override suspend fun getForegroundInfo(): ForegroundInfo {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    applicationContext.getString(R.string.widget_sync_channel),
                    NotificationManager.IMPORTANCE_MIN,
                ),
            )
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(applicationContext, CHANNEL_ID)
        } else {
            Notification.Builder(applicationContext)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_widget_sync)
            .setContentTitle(applicationContext.getString(R.string.widget_syncing))
            .setOngoing(true)
            .build()
        // Only called below Android 12 (from 12 on, expedited work is an
        // expedited job, not a foreground service), so no service type.
        return ForegroundInfo(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val KEY_FORCE_FETCH = "force_fetch"
        private const val MAX_ATTEMPTS = 5
        private const val CHANNEL_ID = "mitlist_widget_sync"
        private const val NOTIFICATION_ID = 4701
    }
}

object WidgetSyncScheduler {
    // v2: work enqueued by older builds needs a validated network and, on a
    // network that never validates, never runs; new syncs appended to that
    // chain would wait behind it forever. New names, and the old ones are
    // cancelled (see [cancelLegacy]).
    private const val UNIQUE_NOW = "mitlist_widget_sync_v2"
    private const val UNIQUE_PERIODIC = "mitlist_widget_periodic_v2"
    private val LEGACY = listOf("mitlist_widget_sync", "mitlist_widget_periodic")

    /**
     * Any network with internet, validated or not. WorkManager's plain
     * CONNECTED becomes a JobScheduler request that also needs VALIDATED, so
     * on Wi-Fi whose connectivity check fails (corporate proxies, captive
     * portals, a self-hosted server on a LAN with no internet) a widget tick
     * would never be sent, even though the server is reachable. Found on an
     * emulator behind such a network. A request that cannot reach the
     * server fails fast and is retried with backoff.
     */
    private val network: Constraints = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        Constraints.Builder()
            .setRequiredNetworkRequest(
                NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .removeCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                    .build(),
                NetworkType.CONNECTED,
            )
            .build()
    } else {
        Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
    }

    /**
     * Delivers queued ops and refreshes the snapshot as soon as there is
     * network. Appended to a running pass, so an op queued while one runs is
     * not dropped by a "keep the existing work" policy.
     */
    fun syncNow(context: Context, forceFetch: Boolean = false, expedited: Boolean = true) {
        val request = OneTimeWorkRequestBuilder<WidgetSyncWorker>()
            .setConstraints(network)
            .setInputData(workDataOf("force_fetch" to forceFetch))
            .setBackoffCriteria(androidx.work.BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .apply { if (expedited) setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST) }
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork(UNIQUE_NOW, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
    }

    /**
     * The periodic backstop (D6), kept while any widget is on a home screen.
     * 15 minutes is WorkManager's minimum: until a push token is registered
     * it is the only way other members' changes reach an idle phone. UPDATE
     * (not KEEP) so installs that still hold the old hourly job move to the
     * new interval without losing its schedule.
     */
    fun ensurePeriodic(context: Context) {
        cancelLegacy(context)
        val request = PeriodicWorkRequestBuilder<WidgetSyncWorker>(PERIODIC_MINUTES, TimeUnit.MINUTES)
            .setConstraints(network)
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniquePeriodicWork(UNIQUE_PERIODIC, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    /**
     * Fetches now when there is a credential and the snapshot is missing or
     * older than [STALE_FOR_REFRESH_MILLIS] (a widget was just placed, the
     * phone rebooted, the app was updated).
     */
    fun refreshIfStale(context: Context, now: Long = System.currentTimeMillis()) {
        val app = context.applicationContext
        if (!CredentialStore.has(app)) return
        val lastFetch = WidgetStateStore(app).lastFetchAt
        val missing = WidgetFiles.snapshot(app).read() == null
        if (missing || now - lastFetch > STALE_FOR_REFRESH_MILLIS) {
            syncNow(app, forceFetch = true, expedited = missing)
        }
    }

    const val PERIODIC_MINUTES = 15L
    private const val STALE_FOR_REFRESH_MILLIS = 5L * 60 * 1000

    private fun cancelLegacy(context: Context) {
        val wm = WorkManager.getInstance(context.applicationContext)
        LEGACY.forEach(wm::cancelUniqueWork)
    }

    fun cancelPeriodic(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(UNIQUE_PERIODIC)
    }

    fun cancelAll(context: Context) {
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.cancelUniqueWork(UNIQUE_NOW)
        wm.cancelUniqueWork(UNIQUE_PERIODIC)
        LEGACY.forEach(wm::cancelUniqueWork)
    }
}
