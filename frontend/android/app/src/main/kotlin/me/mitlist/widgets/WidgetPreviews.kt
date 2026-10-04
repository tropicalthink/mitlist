package me.mitlist.widgets

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidgetManager
import me.mitlist.R

/** Made-up household data for the widget picker previews. */
object SampleData {
    fun model(context: Context): WidgetModel {
        val now = System.currentTimeMillis()
        val sam = context.getString(R.string.widget_sample_person_1)
        val alex = context.getString(R.string.widget_sample_person_2)
        val household = WidgetHousehold(
            id = "sample-household",
            name = context.getString(R.string.widget_sample_household),
            lists = listOf(
                WidgetList(
                    id = "sample-list",
                    name = context.getString(R.string.widget_sample_list),
                    type = "shopping",
                    openCount = 4,
                    items = listOf(
                        WidgetListItem("s1", context.getString(R.string.widget_sample_item_1), 2.0, "l", sam),
                        WidgetListItem("s2", context.getString(R.string.widget_sample_item_2), 1.0),
                        WidgetListItem("s3", context.getString(R.string.widget_sample_item_3), 1.0, null, alex),
                        WidgetListItem("s4", context.getString(R.string.widget_sample_item_4), 6.0),
                    ),
                ),
            ),
            chores = listOf(
                WidgetChore("c1", context.getString(R.string.widget_sample_chore_1), now, "due_today", true, null, alex),
                WidgetChore("c2", context.getString(R.string.widget_sample_chore_2), now - 2 * 86_400_000L, "overdue", false, sam, null),
            ),
            tonightMeal = TonightMeal(context.getString(R.string.widget_sample_meal), "dinner", null),
            balance = WidgetBalance("EUR", -1200, sam, 1200),
        )
        return WidgetModel(
            snapshot = WidgetSnapshot(
                version = 1,
                generatedAt = now,
                source = "server",
                userId = "",
                defaults = WidgetDefaults(household.id, "sample-list"),
                households = listOf(household),
            ),
            hasCredential = true,
            authFailed = false,
            updatedAt = now,
            configuredHousehold = null,
            configuredList = null,
        )
    }
}

/**
 * Generated previews for the widget picker (Android 15+). The platform rate
 * limits publishing to a couple of calls an hour, so it is done once per app
 * version, after the first snapshot shows the app is set up.
 */
object WidgetPreviews {
    private const val TAG = "MitlistWidgetPreviews"

    suspend fun publishIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val app = context.applicationContext
        val state = WidgetStateStore(app)
        val version = appVersionCode(app)
        if (state.previewsPublishedFor == version) return
        val manager = GlanceAppWidgetManager(app)
        var allPublished = true
        for (receiver in WidgetUpdater.receivers) {
            try {
                val result = manager.setWidgetPreviews(receiver.kotlin)
                if (result != GlanceAppWidgetManager.SET_WIDGET_PREVIEWS_RESULT_SUCCESS) allPublished = false
            } catch (e: Exception) {
                Log.w(TAG, "setWidgetPreviews ${receiver.simpleName} failed", e)
                allPublished = false
            }
        }
        // Rate limited or failed: the next snapshot write tries again.
        if (allPublished) state.previewsPublishedFor = version
    }

    @Suppress("DEPRECATION")
    private fun appVersionCode(context: Context): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
    }
}
