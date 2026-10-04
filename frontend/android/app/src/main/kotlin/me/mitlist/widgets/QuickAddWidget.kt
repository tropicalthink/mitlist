package me.mitlist.widgets

import android.content.Context
import android.content.Intent
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
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.TextAlign
import me.mitlist.R

class QuickAddWidgetReceiver : MitlistWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuickAddWidget()
}

/**
 * Stage 6: a 1x1 "+" or a 4x1 "Add to Groceries" bar with a mic. Both open
 * the native [QuickAddActivity]; widgets cannot take typed text.
 */
class QuickAddWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(50.dp, 50.dp), DpSize(200.dp, 50.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val initial = WidgetModel.loadAsync(context, appWidgetId)
        provideContent {
            val model = rememberWidgetModel(context, appWidgetId, initial)
            MitlistWidgetTheme { QuickAddContent(model, appWidgetId) }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { MitlistWidgetTheme { QuickAddContent(SampleData.model(context), android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID) } }
    }
}

@Composable
private fun QuickAddContent(model: WidgetModel, appWidgetId: Int) {
    val context = LocalContext.current
    val list = model.snapshot?.resolveList(model.configuredHousehold, model.configuredList)?.second
    val wide = LocalSize.current.width >= 200.dp
    val open = actionStartActivity(QuickAddActivity.intent(context, appWidgetId, voice = false))
    val label = list?.let { context.getString(R.string.widget_add_to, it.name) }
        ?: context.getString(R.string.quick_add_title)
    if (!wide) {
        WidgetFrame(padding = 0.dp, modifier = GlanceModifier.clickable(open).semantics { contentDescription = label }) {
            Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Box(
                    modifier = GlanceModifier.size(44.dp).background(GlanceTheme.colors.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_add),
                        contentDescription = null,
                        modifier = GlanceModifier.size(28.dp),
                        colorFilter = ColorFilter.tint(GlanceTheme.colors.onPrimary),
                    )
                }
            }
        }
        return
    }
    WidgetFrame(padding = 4.dp) {
        Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Row(
                modifier = GlanceModifier.defaultWeight().fillMaxHeight().padding(start = 8.dp).clickable(open)
                    .semantics { contentDescription = label },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier.size(32.dp).background(GlanceTheme.colors.primary),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_add),
                        contentDescription = null,
                        modifier = GlanceModifier.size(22.dp),
                        colorFilter = ColorFilter.tint(GlanceTheme.colors.onPrimary),
                    )
                }
                Spacer(GlanceModifier.width(10.dp))
                Column {
                    WidgetText(label, bold = true, size = 14.sp, align = TextAlign.Start)
                }
            }
            WidgetIconButton(
                R.drawable.ic_widget_mic,
                context.getString(R.string.quick_add_voice),
                actionStartActivity(QuickAddActivity.intent(context, appWidgetId, voice = true)),
                tint = GlanceTheme.colors.primary,
            )
        }
    }
}

/** Intent extras for [QuickAddActivity]. */
internal fun Intent.quickAddWidgetId(): Int =
    getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID)
