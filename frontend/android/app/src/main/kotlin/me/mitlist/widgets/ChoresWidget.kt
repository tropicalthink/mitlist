package me.mitlist.widgets

import android.content.Context
import android.text.format.DateUtils
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.TextAlign
import me.mitlist.R
import java.util.Calendar

class ChoresWidgetReceiver : MitlistWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ChoresWidget()
}

/** Due and overdue chores with a Done button each (C7). */
class ChoresWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(TILE, WIDE, TALL))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val initial = WidgetModel.loadAsync(context, appWidgetId)
        provideContent {
            val model = rememberWidgetModel(context, appWidgetId, initial)
            MitlistWidgetTheme { Content(model) }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { MitlistWidgetTheme { Content(SampleData.model(context)) } }
    }

    companion object {
        val TILE = DpSize(110.dp, 110.dp)
        val WIDE = DpSize(250.dp, 110.dp)
        val TALL = DpSize(250.dp, 250.dp)
    }
}

@Composable
private fun Content(model: WidgetModel) {
    val context = LocalContext.current
    if (NoDataStates(model)) return
    val snapshot = model.snapshot ?: return
    val household = snapshot.resolveHousehold(model.configuredHousehold)
    if (household == null) {
        MessageState(context.getString(R.string.widget_no_household), actionStartActivity(WidgetLinks.app(context)))
        return
    }
    val size = LocalSize.current
    val keyguard = isKeyguardHost()
    if (keyguard || (size.width < 180.dp && size.height < 180.dp)) {
        ChoresTile(household, countsOnly = keyguard)
    } else {
        ChoresList(model, household)
    }
}

@Composable
private fun ChoresTile(household: WidgetHousehold, countsOnly: Boolean) {
    val context = LocalContext.current
    val chores = household.chores
    val mine = chores.count { it.isMine }
    WidgetFrame(modifier = GlanceModifier.clickable(actionStartActivity(WidgetLinks.chores(context, household.id)))) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            WidgetText(context.getString(R.string.widget_chores_title), bold = true, size = 15.sp)
            if (!countsOnly) SecondaryText(household.name)
            Spacer(GlanceModifier.defaultWeight())
            WidgetText(chores.size.toString(), bold = true, size = 30.sp, color = GlanceTheme.colors.primary)
            SecondaryText(
                if (chores.isEmpty()) {
                    context.getString(R.string.widget_chores_nothing_due_short)
                } else {
                    context.resources.getQuantityString(R.plurals.widget_chores_due, chores.size, chores.size)
                },
            )
            if (!countsOnly && mine > 0) {
                SecondaryText(context.resources.getQuantityString(R.plurals.widget_chores_mine, mine, mine))
            }
        }
    }
}

@Composable
private fun ChoresList(model: WidgetModel, household: WidgetHousehold) {
    val context = LocalContext.current
    WidgetFrame(padding = 8.dp) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(
                modifier = GlanceModifier.fillMaxWidth().padding(start = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = GlanceModifier.defaultWeight()
                        .clickable(actionStartActivity(WidgetLinks.chores(context, household.id))),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        WidgetText(context.getString(R.string.widget_chores_title), bold = true, size = 15.sp)
                        Spacer(GlanceModifier.width(6.dp))
                        CountBadge(household.chores.size)
                    }
                    SecondaryText(household.name)
                }
                WidgetIconButton(
                    R.drawable.ic_widget_refresh,
                    context.getString(R.string.widget_refresh),
                    actionRunCallback<RefreshAction>(),
                    tint = GlanceTheme.colors.onSurfaceVariant,
                )
            }
            if (household.chores.isEmpty()) {
                Column(
                    modifier = GlanceModifier.fillMaxWidth().defaultWeight()
                        .clickable(actionStartActivity(WidgetLinks.chores(context, household.id))),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    WidgetText(context.getString(R.string.widget_chores_empty), align = TextAlign.Center, maxLines = 2)
                    SecondaryText(context.getString(R.string.widget_chores_empty_action))
                }
            } else {
                LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                    items(household.chores, itemId = { stableId(it.id) }) { chore ->
                        ChoreRow(household, chore)
                    }
                }
            }
            Column(modifier = GlanceModifier.padding(start = 8.dp)) { StatusLine(model) }
        }
    }
}

@Composable
private fun ChoreRow(household: WidgetHousehold, chore: WidgetChore) {
    val context = LocalContext.current
    Row(modifier = GlanceModifier.fillMaxWidth().padding(start = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(
            modifier = GlanceModifier.defaultWeight()
                .clickable(actionStartActivity(WidgetLinks.chores(context, household.id))),
        ) {
            WidgetText(chore.title, bold = chore.isMine)
            SecondaryText(choreSubtitle(context, chore))
        }
        DoneButton(household, chore)
    }
}

@Composable
internal fun DoneButton(household: WidgetHousehold, chore: WidgetChore) {
    val context = LocalContext.current
    val label = context.getString(R.string.widget_chore_done)
    Box(
        modifier = GlanceModifier.height(48.dp).padding(vertical = 6.dp)
            .clickable(
                actionRunCallback<CompleteChoreAction>(
                    actionParametersOf(
                        WidgetActionKeys.household to household.id,
                        WidgetActionKeys.chore to chore.id,
                    ),
                ),
            )
            .semantics { contentDescription = context.getString(R.string.widget_chore_done_cd, chore.title) },
        contentAlignment = Alignment.Center,
    ) {
        // A square 2dp outline around the label (Glance has no border).
        Box(modifier = GlanceModifier.background(GlanceTheme.colors.outline).padding(2.dp)) {
            Box(
                modifier = GlanceModifier.background(GlanceTheme.colors.widgetBackground).padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                WidgetText(label, bold = true, size = 13.sp)
            }
        }
    }
}

/** "Overdue · Sam Tester", "Today · You · Next: Alex", "Thu · Jo". */
internal fun choreSubtitle(context: Context, chore: WidgetChore, now: Long = System.currentTimeMillis()): String {
    val parts = mutableListOf(dueLabel(context, chore, now))
    // Assignee names are full display names; the TextView ellipsizes them.
    if (chore.isMine) {
        parts += context.getString(R.string.widget_chore_you)
    } else if (chore.assigneeName != null) {
        parts += chore.assigneeName
    }
    if (chore.nextAssigneeName != null) parts += context.getString(R.string.widget_chore_next, chore.nextAssigneeName)
    return parts.joinToString(" · ")
}

/**
 * When a chore is due, in the device's time zone (the server's "today" is
 * UTC, C1). Falls back to the server's status when there is no due time.
 */
internal fun dueLabel(context: Context, chore: WidgetChore, now: Long): String {
    val due = chore.dueAt
        ?: return when (chore.dueStatus) {
            "overdue" -> context.getString(R.string.widget_due_overdue)
            "due_today" -> context.getString(R.string.widget_due_today)
            else -> context.getString(R.string.widget_due_soon)
        }
    val today = startOfDay(now)
    val dueDay = startOfDay(due)
    val days = Math.round((dueDay - today) / DateUtils.DAY_IN_MILLIS.toDouble()).toInt()
    return when {
        days < 0 -> context.getString(R.string.widget_due_overdue)
        days == 0 -> context.getString(R.string.widget_due_today)
        days == 1 -> context.getString(R.string.widget_due_tomorrow)
        else -> DateUtils.formatDateTime(context, due, DateUtils.FORMAT_SHOW_WEEKDAY or DateUtils.FORMAT_ABBREV_WEEKDAY)
    }
}

private fun startOfDay(millis: Long): Long {
    val cal = Calendar.getInstance()
    cal.timeInMillis = millis
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}
