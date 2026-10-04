package me.mitlist.widgets

import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.text.format.DateUtils
import androidx.annotation.DrawableRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.background
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.LocalAppWidgetOptions
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.color.ColorProvider
import androidx.glance.color.ColorProviders
import androidx.glance.color.DynamicThemeColorProviders
import androidx.glance.color.colorProviders
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import me.mitlist.MainActivity
import me.mitlist.R

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

/**
 * mitlist colours: brand orange as the accent only (tinted hosts wash it
 * out, so state never relies on it). From Android 12 the surfaces follow the
 * wallpaper's dynamic colours so the widget sits well on any home screen.
 */
object MitlistWidgetColors {
    private val orange = Color(0xFFF97316)
    private val orangeDark = Color(0xFFFB923C)
    private val onOrange = Color(0xFF1A1714)
    private val orangeContainer = Color(0xFFFFEDD5)
    private val orangeContainerDark = Color(0xFF7C2D12)
    private val onOrangeContainer = Color(0xFF431407)
    private val onOrangeContainerDark = Color(0xFFFFEDD5)
    private val surface = Color(0xFFFFFCF7)
    private val surfaceDark = Color(0xFF1A1714)
    private val surfaceVariant = Color(0xFFF7F4EC)
    private val surfaceVariantDark = Color(0xFF26211D)
    private val onSurface = Color(0xFF1A1714)
    private val onSurfaceDark = Color(0xFFF7F4EC)
    private val onSurfaceVariant = Color(0xFF5A5147)
    private val onSurfaceVariantDark = Color(0xFFBAB1A1)
    private val outline = Color(0xFF26211D)
    private val outlineDark = Color(0xFFDCD6C7)
    private val error = Color(0xFFDC2626)
    private val errorDark = Color(0xFFF87171)

    fun providers(): ColorProviders {
        val primary = ColorProvider(day = orange, night = orangeDark)
        val onPrimary = ColorProvider(day = onOrange, night = onOrange)
        val primaryContainer = ColorProvider(day = orangeContainer, night = orangeContainerDark)
        val onPrimaryContainer = ColorProvider(day = onOrangeContainer, night = onOrangeContainerDark)
        val err = ColorProvider(day = error, night = errorDark)
        val dynamic = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val d = DynamicThemeColorProviders
        return colorProviders(
            primary = primary,
            onPrimary = onPrimary,
            primaryContainer = primaryContainer,
            onPrimaryContainer = onPrimaryContainer,
            secondary = primary,
            onSecondary = onPrimary,
            secondaryContainer = primaryContainer,
            onSecondaryContainer = onPrimaryContainer,
            tertiary = primary,
            onTertiary = onPrimary,
            tertiaryContainer = primaryContainer,
            onTertiaryContainer = onPrimaryContainer,
            error = err,
            errorContainer = ColorProvider(day = Color(0xFFFEE2E2), night = Color(0xFF7F1D1D)),
            onError = ColorProvider(day = Color.White, night = Color.White),
            onErrorContainer = ColorProvider(day = Color(0xFF7F1D1D), night = Color(0xFFFEE2E2)),
            background = if (dynamic) d.background else ColorProvider(day = surface, night = surfaceDark),
            onBackground = if (dynamic) d.onBackground else ColorProvider(day = onSurface, night = onSurfaceDark),
            surface = if (dynamic) d.surface else ColorProvider(day = surface, night = surfaceDark),
            onSurface = if (dynamic) d.onSurface else ColorProvider(day = onSurface, night = onSurfaceDark),
            surfaceVariant = if (dynamic) d.surfaceVariant else ColorProvider(day = surfaceVariant, night = surfaceVariantDark),
            onSurfaceVariant = if (dynamic) d.onSurfaceVariant else ColorProvider(day = onSurfaceVariant, night = onSurfaceVariantDark),
            outline = if (dynamic) d.onSurface else ColorProvider(day = outline, night = outlineDark),
            inverseOnSurface = ColorProvider(day = onSurfaceDark, night = onSurface),
            inverseSurface = ColorProvider(day = surfaceDark, night = surface),
            inversePrimary = ColorProvider(day = orangeDark, night = orange),
            widgetBackground = if (dynamic) d.widgetBackground else ColorProvider(day = surface, night = surfaceDark),
        )
    }
}

@Composable
fun MitlistWidgetTheme(content: @Composable () -> Unit) {
    GlanceTheme(colors = MitlistWidgetColors.providers(), content = content)
}

// ---------------------------------------------------------------------------
// Links (contract C5)
// ---------------------------------------------------------------------------

object WidgetLinks {
    fun list(context: Context, householdId: String?, listId: String, add: Boolean = false) =
        open(context, "/lists/${Uri.encode(listId)}", householdId, if (add) "add=1" else null)

    fun lists(context: Context, householdId: String?) = open(context, "/lists", householdId)

    fun chores(context: Context, householdId: String?) = open(context, "/chores", householdId)

    fun money(context: Context, householdId: String?) = open(context, "/money", householdId)

    fun home(context: Context, householdId: String?) = open(context, "/home", householdId)

    fun app(context: Context) = open(context, "/home", null)

    private fun open(context: Context, path: String, householdId: String?, extra: String? = null): Intent {
        val query = listOfNotNull(householdId?.let { "group=${Uri.encode(it)}" }, extra).joinToString("&")
        val uri = Uri.parse("mitlist://$path" + if (query.isEmpty()) "" else "?$query")
        // Straight to MainActivity, as DeepLinkActivity would forward it: the
        // running app gets it in onNewIntent, a cold start as its first route.
        return Intent(Intent.ACTION_VIEW, uri, context, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
    }
}

// ---------------------------------------------------------------------------
// What a widget renders
// ---------------------------------------------------------------------------

/** Everything a widget needs, read in one go from files and prefs. */
data class WidgetModel(
    /** The snapshot with the queue applied (C2 overlay); null when there is none. */
    val snapshot: WidgetSnapshot?,
    val hasCredential: Boolean,
    val authFailed: Boolean,
    /** Epoch millis of the last snapshot write, or the snapshot's own time. */
    val updatedAt: Long?,
    val configuredHousehold: String?,
    val configuredList: String?,
) {
    /** The widget can show data, but taps cannot reach the server until the app is opened. */
    val needsApp: Boolean get() = authFailed || !hasCredential

    companion object {
        suspend fun loadAsync(context: Context, appWidgetId: Int): WidgetModel =
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { load(context, appWidgetId) }

        fun load(context: Context, appWidgetId: Int): WidgetModel {
            val raw = WidgetFiles.snapshot(context).read()
            val ops = if (raw == null) emptyList() else WidgetFiles.queue(context).readAll()
            val state = WidgetStateStore(context)
            val config = WidgetConfigStore(context)
            return WidgetModel(
                snapshot = raw?.let { WidgetOverlay.apply(it, ops) },
                hasCredential = CredentialStore.has(context),
                authFailed = state.authFailed,
                updatedAt = state.lastFetchAt.takeIf { it > 0 } ?: raw?.generatedAt,
                configuredHousehold = config.householdId(appWidgetId),
                configuredList = config.listId(appWidgetId),
            )
        }
    }
}

/**
 * The widget's data, reloaded (off the main thread) whenever [WidgetData]
 * is bumped, so a session that is on screen picks up writes made elsewhere.
 */
@Composable
fun rememberWidgetModel(context: Context, appWidgetId: Int, initial: WidgetModel): WidgetModel {
    val version by WidgetData.version.collectAsState()
    val model: State<WidgetModel> = produceState(initial, version) {
        value = WidgetModel.loadAsync(context, appWidgetId)
    }
    return model.value
}

/** True on a lock screen host: show counts, not names or amounts. */
@Composable
fun isKeyguardHost(): Boolean {
    val category = LocalAppWidgetOptions.current.getInt(
        android.appwidget.AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY,
        AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
    )
    return category and AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD != 0
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/** The outer container: system corner radius outside, square geometry inside. */
@Composable
fun WidgetFrame(
    modifier: GlanceModifier = GlanceModifier,
    padding: Dp = 12.dp,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(android.R.dimen.system_app_widget_background_radius)
            .then(modifier)
            .padding(padding),
    ) {
        content()
    }
}

@Composable
fun WidgetText(
    text: String,
    modifier: GlanceModifier = GlanceModifier,
    size: TextUnit = 14.sp,
    bold: Boolean = false,
    color: androidx.glance.unit.ColorProvider = GlanceTheme.colors.onSurface,
    maxLines: Int = 1,
    align: TextAlign = TextAlign.Start,
) {
    Text(
        text = text,
        modifier = modifier,
        maxLines = maxLines,
        style = TextStyle(
            color = color,
            fontSize = size,
            fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
            textAlign = align,
        ),
    )
}

@Composable
fun SecondaryText(text: String, modifier: GlanceModifier = GlanceModifier, maxLines: Int = 1) =
    WidgetText(text, modifier, size = 12.sp, color = GlanceTheme.colors.onSurfaceVariant, maxLines = maxLines)

/** A 48dp touch target holding a 24dp icon. */
@Composable
fun WidgetIconButton(
    @DrawableRes icon: Int,
    contentDescription: String,
    onClick: Action,
    tint: androidx.glance.unit.ColorProvider = GlanceTheme.colors.onSurface,
    filled: Boolean = false,
) {
    Box(
        modifier = GlanceModifier
            .size(48.dp)
            .clickable(onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        if (filled) {
            Box(
                modifier = GlanceModifier.size(36.dp).background(GlanceTheme.colors.primary),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    provider = ImageProvider(icon),
                    contentDescription = null,
                    modifier = GlanceModifier.size(22.dp),
                    colorFilter = ColorFilter.tint(GlanceTheme.colors.onPrimary),
                )
            }
        } else {
            Image(
                provider = ImageProvider(icon),
                contentDescription = null,
                modifier = GlanceModifier.size(24.dp),
                colorFilter = ColorFilter.tint(tint),
            )
        }
    }
}

/**
 * An empty square with a 2dp outline, mitlist's checkbox, in a 48dp touch
 * target. Glance has no border modifier: the outline is a filled square with
 * a smaller square of the background on top.
 */
@Composable
fun SquareTick(contentDescription: String, onClick: Action?, enabled: Boolean = true) {
    val outline = if (enabled) GlanceTheme.colors.outline else GlanceTheme.colors.onSurfaceVariant
    var modifier = GlanceModifier.size(48.dp).semantics { this.contentDescription = contentDescription }
    if (onClick != null && enabled) modifier = modifier.clickable(onClick)
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Box(modifier = GlanceModifier.size(22.dp).background(outline).padding(2.dp)) {
            Box(modifier = GlanceModifier.fillMaxSize().background(GlanceTheme.colors.widgetBackground)) {}
        }
    }
}

/** A full-widget message with an optional action ("Open mitlist"). */
@Composable
fun MessageState(message: String, onClick: Action? = null, @DrawableRes icon: Int = R.drawable.ic_widget_list) {
    val context = LocalContext.current
    WidgetFrame(modifier = if (onClick != null) GlanceModifier.clickable(onClick) else GlanceModifier) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Image(
                provider = ImageProvider(icon),
                contentDescription = null,
                modifier = GlanceModifier.size(28.dp),
                colorFilter = ColorFilter.tint(GlanceTheme.colors.primary),
            )
            Spacer(GlanceModifier.height(8.dp))
            WidgetText(message, maxLines = 3, align = TextAlign.Center, size = 13.sp)
            if (onClick != null) {
                Spacer(GlanceModifier.height(4.dp))
                WidgetText(
                    context.getString(R.string.widget_open_app),
                    bold = true,
                    size = 13.sp,
                    color = GlanceTheme.colors.primary,
                    align = TextAlign.Center,
                )
            }
        }
    }
}

/** "Open mitlist to sync" / "Updated 2 hours ago": the footer of a data widget. */
@Composable
fun StatusLine(model: WidgetModel, now: Long = System.currentTimeMillis()) {
    val context = LocalContext.current
    val text = when {
        model.needsApp -> context.getString(R.string.widget_open_app_to_sync)
        model.updatedAt != null && now - model.updatedAt > STALE_AFTER_MILLIS ->
            context.getString(
                R.string.widget_updated_ago,
                DateUtils.getRelativeTimeSpanString(model.updatedAt, now, DateUtils.MINUTE_IN_MILLIS),
            )
        else -> return
    }
    Row(
        modifier = GlanceModifier.fillMaxWidth().padding(top = 4.dp).let {
            if (model.needsApp) it.clickable(androidx.glance.appwidget.action.actionStartActivity(WidgetLinks.app(context))) else it
        },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (model.needsApp) {
            Image(
                provider = ImageProvider(R.drawable.ic_widget_info),
                contentDescription = null,
                modifier = GlanceModifier.size(14.dp),
                colorFilter = ColorFilter.tint(GlanceTheme.colors.error),
            )
            Spacer(GlanceModifier.width(4.dp))
        }
        SecondaryText(text)
    }
}

/** Snapshots older than this get an "updated X ago" line. */
const val STALE_AFTER_MILLIS = 30L * 60 * 1000

/** The standard "no data yet" states. Returns true when it rendered one. */
@Composable
fun NoDataStates(model: WidgetModel): Boolean {
    val context = LocalContext.current
    if (model.snapshot != null) return false
    if (model.hasCredential) {
        MessageState(context.getString(R.string.widget_loading), null, R.drawable.ic_widget_sync)
    } else {
        MessageState(
            context.getString(R.string.widget_signed_out),
            androidx.glance.appwidget.action.actionStartActivity(WidgetLinks.app(context)),
        )
    }
    return true
}

/** A small orange count, e.g. the number of open items. */
@Composable
fun CountBadge(count: Int) {
    Box(
        modifier = GlanceModifier.background(GlanceTheme.colors.primaryContainer).padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        WidgetText(count.toString(), size = 12.sp, bold = true, color = GlanceTheme.colors.onPrimaryContainer)
    }
}

/** A thin rule between sections. */
@Composable
fun Divider() {
    Box(modifier = GlanceModifier.fillMaxWidth().height(1.dp).background(GlanceTheme.colors.surfaceVariant)) {}
}
