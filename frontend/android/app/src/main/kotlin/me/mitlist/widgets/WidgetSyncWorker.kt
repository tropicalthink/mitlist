package me.mitlist.widgets

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
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
    private const val UNIQUE_NOW = "mitlist_widget_sync"
    private const val UNIQUE_PERIODIC = "mitlist_widget_periodic"

    private val network = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

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

    /** The hourly backstop (D6), kept while any widget is on a home screen. */
    fun ensurePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<WidgetSyncWorker>(60, TimeUnit.MINUTES)
            .setConstraints(network)
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniquePeriodicWork(UNIQUE_PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun cancelPeriodic(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(UNIQUE_PERIODIC)
    }

    fun cancelAll(context: Context) {
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.cancelUniqueWork(UNIQUE_NOW)
        wm.cancelUniqueWork(UNIQUE_PERIODIC)
    }
}
