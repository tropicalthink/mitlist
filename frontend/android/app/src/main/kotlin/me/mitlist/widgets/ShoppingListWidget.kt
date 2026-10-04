package me.mitlist.widgets

import android.content.Context
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
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.TextAlign
import me.mitlist.R
import java.text.DecimalFormat

class ShoppingListWidgetReceiver : MitlistWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ShoppingListWidget()
}

/** One list: tick items off in place, "+" opens the composer (C7). */
class ShoppingListWidget : GlanceAppWidget() {
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
    val resolved = snapshot.resolveList(model.configuredHousehold, model.configuredList)
    if (resolved == null) {
        MessageState(context.getString(R.string.widget_no_lists), actionStartActivity(WidgetLinks.app(context)))
        return
    }
    val (household, list) = resolved
    val size = LocalSize.current
    val keyguard = isKeyguardHost()
    if (keyguard || (size.width < 180.dp && size.height < 180.dp)) {
        ListTile(model, household, list, countsOnly = keyguard)
    } else {
        ListWithItems(model, household, list)
    }
}

/** 2x2 and lock screen: name, count, "+". */
@Composable
private fun ListTile(model: WidgetModel, household: WidgetHousehold, list: WidgetList, countsOnly: Boolean) {
    val context = LocalContext.current
    WidgetFrame(modifier = GlanceModifier.clickable(actionStartActivity(WidgetLinks.list(context, household.id, list.id)))) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            WidgetText(list.name, bold = true, size = 15.sp)
            if (!countsOnly) SecondaryText(household.name)
            Spacer(GlanceModifier.defaultWeight())
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    WidgetText(list.openCount.toString(), bold = true, size = 30.sp, color = GlanceTheme.colors.primary)
                    SecondaryText(context.resources.getQuantityString(R.plurals.widget_items_left, list.openCount, list.openCount))
                }
                if (!countsOnly) {
                    WidgetIconButton(
                        R.drawable.ic_widget_add,
                        context.getString(R.string.widget_add_item_to, list.name),
                        actionStartActivity(WidgetLinks.list(context, household.id, list.id, add = true)),
                        filled = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun ListWithItems(model: WidgetModel, household: WidgetHousehold, list: WidgetList) {
    val context = LocalContext.current
    WidgetFrame(padding = 8.dp) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(
                modifier = GlanceModifier.fillMaxWidth().padding(start = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = GlanceModifier.defaultWeight()
                        .clickable(actionStartActivity(WidgetLinks.list(context, household.id, list.id))),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        WidgetText(list.name, bold = true, size = 15.sp)
                        Spacer(GlanceModifier.width(6.dp))
                        CountBadge(list.openCount)
                    }
                    SecondaryText(household.name)
                }
                WidgetIconButton(
                    R.drawable.ic_widget_refresh,
                    context.getString(R.string.widget_refresh),
                    actionRunCallback<RefreshAction>(),
                    tint = GlanceTheme.colors.onSurfaceVariant,
                )
                WidgetIconButton(
                    R.drawable.ic_widget_add,
                    context.getString(R.string.widget_add_item_to, list.name),
                    actionStartActivity(WidgetLinks.list(context, household.id, list.id, add = true)),
                    filled = true,
                )
            }
            if (list.items.isEmpty()) {
                Column(
                    modifier = GlanceModifier.fillMaxWidth().defaultWeight()
                        .clickable(actionStartActivity(WidgetLinks.list(context, household.id, list.id, add = true))),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    WidgetText(context.getString(R.string.widget_list_empty), align = TextAlign.Center, maxLines = 2)
                    SecondaryText(context.getString(R.string.widget_list_empty_action))
                }
            } else {
                LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                    items(list.items, itemId = { stableId(it.id) }) { item ->
                        ItemRow(household, list, item)
                    }
                    if (list.openCount > list.items.size) {
                        item(stableId("more:${list.id}")) {
                            SecondaryText(
                                context.getString(R.string.widget_more_items, list.openCount - list.items.size),
                                modifier = GlanceModifier.fillMaxWidth().padding(start = 48.dp, top = 4.dp, bottom = 4.dp)
                                    .clickable(actionStartActivity(WidgetLinks.list(context, household.id, list.id))),
                            )
                        }
                    }
                }
            }
            Column(modifier = GlanceModifier.padding(start = 8.dp)) { StatusLine(model) }
        }
    }
}

@Composable
private fun ItemRow(household: WidgetHousehold, list: WidgetList, item: WidgetListItem) {
    val context = LocalContext.current
    Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        SquareTick(
            contentDescription = if (item.local) {
                context.getString(R.string.widget_item_waiting, item.name)
            } else {
                context.getString(R.string.widget_tick_off, item.name)
            },
            onClick = actionRunCallback<ToggleItemAction>(
                actionParametersOf(
                    WidgetActionKeys.household to household.id,
                    WidgetActionKeys.list to list.id,
                    WidgetActionKeys.item to item.id,
                ),
            ),
            // An add still waiting for the server has no server id to tick.
            enabled = !item.local,
        )
        Column(
            modifier = GlanceModifier.defaultWeight().padding(end = 8.dp)
                .clickable(actionStartActivity(WidgetLinks.list(context, household.id, list.id))),
        ) {
            WidgetText(
                itemLabel(item),
                color = if (item.local) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onSurface,
            )
            when {
                item.local -> SecondaryText(context.getString(R.string.widget_waiting_to_sync))
                item.addedByName != null -> SecondaryText(context.getString(R.string.widget_added_by, item.addedByName))
            }
        }
    }
}

private val quantityFormat = DecimalFormat("0.##")

/** "Oat milk · 2 l"; a quantity of 1 with no unit is left out. */
internal fun itemLabel(item: WidgetListItem): String {
    val q = item.quantity
    val amount = when {
        q == null -> null
        item.unit != null -> "${quantityFormat.format(q)} ${item.unit}"
        q != 1.0 -> quantityFormat.format(q)
        else -> null
    }
    return if (amount == null) item.name else "${item.name} · $amount"
}

/**
 * Stable LazyColumn ids from string ids, so rows animate rather than rebind.
 * Glance reserves ids below -2^62, so the hash is kept non-negative.
 */
internal fun stableId(id: String): Long {
    var h = 1125899906842597L
    for (c in id) h = 31 * h + c.code
    return h and Long.MAX_VALUE
}
