package me.mitlist.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import me.mitlist.R
import java.text.NumberFormat
import java.util.Currency
import kotlin.math.abs

class HouseholdTodayWidgetReceiver : MitlistWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = HouseholdTodayWidget()
}

/**
 * Stage 7: the household at a glance (C7): due chores, the shopping list,
 * tonight's meal and the user's balance.
 */
class HouseholdTodayWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val initial = WidgetModel.loadAsync(context, appWidgetId)
        provideContent {
            val model = rememberWidgetModel(context, appWidgetId, initial)
            MitlistWidgetTheme { HouseholdTodayContent(model) }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { MitlistWidgetTheme { HouseholdTodayContent(SampleData.model(context)) } }
    }
}

@Composable
private fun HouseholdTodayContent(model: WidgetModel) {
    val context = LocalContext.current
    if (NoDataStates(model)) return
    val snapshot = model.snapshot ?: return
    val household = snapshot.resolveHousehold(model.configuredHousehold)
    if (household == null) {
        MessageState(context.getString(R.string.widget_no_household), actionStartActivity(WidgetLinks.app(context)))
        return
    }
    val list = snapshot.resolveList(household.id, model.configuredList)?.second
    val roomy = LocalSize.current.height >= 300.dp
    WidgetFrame {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(
                    modifier = GlanceModifier.defaultWeight()
                        .clickable(actionStartActivity(WidgetLinks.home(context, household.id))),
                ) {
                    WidgetText(household.name, bold = true, size = 16.sp)
                    SecondaryText(context.getString(R.string.widget_today))
                }
                WidgetIconButton(
                    R.drawable.ic_widget_refresh,
                    context.getString(R.string.widget_refresh),
                    actionRunCallback<RefreshAction>(),
                    tint = GlanceTheme.colors.onSurfaceVariant,
                )
            }

            // RemoteViews layouts hold at most 10 children, so each section
            // is its own column.
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                Section(
                    icon = R.drawable.ic_widget_chore,
                    title = context.getString(R.string.widget_chores_title),
                    count = household.chores.size,
                    link = WidgetLinks.chores(context, household.id),
                )
                if (household.chores.isEmpty()) {
                    SecondaryText(context.getString(R.string.widget_chores_nothing_due_short), GlanceModifier.padding(start = 26.dp))
                } else {
                    household.chores.take(if (roomy) 3 else 2).forEach { chore ->
                        Row(modifier = GlanceModifier.fillMaxWidth().padding(start = 26.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = GlanceModifier.defaultWeight()) {
                                WidgetText(chore.title, size = 13.sp, bold = chore.isMine)
                                SecondaryText(choreSubtitle(context, chore))
                            }
                            DoneButton(household, chore)
                        }
                    }
                }
                Spacer(GlanceModifier.height(6.dp))
            }
            Divider()

            if (list != null) {
                Column(modifier = GlanceModifier.fillMaxWidth()) {
                    Section(
                        icon = R.drawable.ic_widget_list,
                        title = list.name,
                        count = list.openCount,
                        link = WidgetLinks.list(context, household.id, list.id),
                        addLink = WidgetLinks.list(context, household.id, list.id, add = true),
                    )
                    val names = list.items.take(if (roomy) 5 else 3).joinToString(", ") { it.name }
                    SecondaryText(
                        names.ifEmpty { context.getString(R.string.widget_list_empty) },
                        GlanceModifier.padding(start = 26.dp),
                        maxLines = 2,
                    )
                    Spacer(GlanceModifier.height(6.dp))
                }
                Divider()
            }

            Row(
                modifier = GlanceModifier.fillMaxWidth().padding(vertical = 6.dp)
                    .clickable(actionStartActivity(WidgetLinks.home(context, household.id))),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SectionIcon(R.drawable.ic_widget_meal)
                WidgetText(
                    household.tonightMeal?.let { context.getString(R.string.widget_tonight, it.title) }
                        ?: context.getString(R.string.widget_tonight_nothing),
                    size = 13.sp,
                )
            }

            household.balance?.let { balance ->
                Column(modifier = GlanceModifier.fillMaxWidth()) {
                    Divider()
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 6.dp)
                            .clickable(actionStartActivity(WidgetLinks.money(context, household.id))),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SectionIcon(R.drawable.ic_widget_money)
                        WidgetText(balanceLine(context, balance), size = 13.sp)
                    }
                }
            }
            Spacer(GlanceModifier.defaultWeight())
            StatusLine(model)
        }
    }
}

@Composable
private fun SectionIcon(icon: Int) {
    Image(
        provider = ImageProvider(icon),
        contentDescription = null,
        modifier = GlanceModifier.size(18.dp),
        colorFilter = ColorFilter.tint(GlanceTheme.colors.primary),
    )
    Spacer(GlanceModifier.width(8.dp))
}

@Composable
private fun Section(icon: Int, title: String, count: Int, link: android.content.Intent, addLink: android.content.Intent? = null) {
    val context = LocalContext.current
    Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(
            modifier = GlanceModifier.defaultWeight().clickable(actionStartActivity(link)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SectionIcon(icon)
            WidgetText(title, bold = true, size = 14.sp)
            Spacer(GlanceModifier.width(6.dp))
            CountBadge(count)
        }
        if (addLink != null) {
            WidgetIconButton(
                R.drawable.ic_widget_add,
                context.getString(R.string.widget_add_item_to, title),
                actionStartActivity(addLink),
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Balance
// ---------------------------------------------------------------------------

class BalanceWidgetReceiver : MitlistWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = BalanceWidget()
}

/** Stage 7: "You owe Sam €12". Home screen only, never the lock screen (C7). */
class BalanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(110.dp, 50.dp), DpSize(110.dp, 110.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val initial = WidgetModel.loadAsync(context, appWidgetId)
        provideContent {
            val model = rememberWidgetModel(context, appWidgetId, initial)
            MitlistWidgetTheme { BalanceContent(model) }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { MitlistWidgetTheme { BalanceContent(SampleData.model(context)) } }
    }
}

@Composable
private fun BalanceContent(model: WidgetModel) {
    val context = LocalContext.current
    if (NoDataStates(model)) return
    val snapshot = model.snapshot ?: return
    val household = snapshot.resolveHousehold(model.configuredHousehold)
    if (household == null) {
        MessageState(context.getString(R.string.widget_no_household), actionStartActivity(WidgetLinks.app(context)))
        return
    }
    val balance = household.balance
    val short = LocalSize.current.height < 100.dp
    WidgetFrame(modifier = GlanceModifier.clickable(actionStartActivity(WidgetLinks.money(context, household.id)))) {
        Column(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            if (!short) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionIcon(R.drawable.ic_widget_money)
                    SecondaryText(household.name)
                }
                Spacer(GlanceModifier.height(6.dp))
            }
            WidgetText(
                if (balance == null) context.getString(R.string.widget_balance_settled) else balanceLine(context, balance),
                bold = true,
                size = if (short) 14.sp else 16.sp,
                maxLines = if (short) 1 else 3,
                color = when {
                    balance == null || balance.netCents == 0L -> GlanceTheme.colors.onSurface
                    balance.netCents < 0 -> GlanceTheme.colors.error
                    else -> GlanceTheme.colors.onSurface
                },
            )
            if (!short) StatusLine(model)
        }
    }
}

/** "You owe Sam €12.00", "Sam owes you €8.00", "All settled". */
internal fun balanceLine(context: Context, balance: WidgetBalance): String {
    val name = balance.settleWithName
    val settle = balance.settleCents
    return when {
        balance.netCents == 0L -> context.getString(R.string.widget_balance_settled)
        name != null && settle != null && balance.netCents < 0 ->
            context.getString(R.string.widget_balance_you_owe, name, formatMoney(settle, balance.currency))
        name != null && settle != null ->
            context.getString(R.string.widget_balance_owes_you, name, formatMoney(settle, balance.currency))
        balance.netCents < 0 -> context.getString(R.string.widget_balance_net_owe, formatMoney(abs(balance.netCents), balance.currency))
        else -> context.getString(R.string.widget_balance_net_owed, formatMoney(balance.netCents, balance.currency))
    }
}

internal fun formatMoney(cents: Long, currencyCode: String): String {
    val format = NumberFormat.getCurrencyInstance()
    val currency = runCatching { Currency.getInstance(currencyCode) }.getOrNull()
    if (currency != null) format.currency = currency
    val digits = currency?.defaultFractionDigits?.takeIf { it >= 0 } ?: 2
    format.minimumFractionDigits = digits
    format.maximumFractionDigits = digits
    var divisor = 1.0
    repeat(digits) { divisor *= 10 }
    return format.format(cents / divisor)
}
