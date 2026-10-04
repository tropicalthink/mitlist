package me.mitlist.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import me.mitlist.R

/**
 * Picks the household (and, for list widgets, the list) a widget shows
 * (D7). Optional and reconfigurable: an unconfigured widget follows the
 * snapshot defaults, never the household currently open in the app.
 */
class WidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    /** One choice: null ids mean "my default". */
    private data class Choice(val label: String, val householdId: String?, val listId: String?)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // Backing out still places the widget, with the defaults.
        setResult(RESULT_OK, resultIntent())

        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)?.provider?.className
        val pickList = provider == ShoppingListWidgetReceiver::class.java.name ||
            provider == QuickAddWidgetReceiver::class.java.name
        setTitle(if (pickList) R.string.widget_config_choose_list else R.string.widget_config_choose_household)

        val snapshot = WidgetFiles.snapshot(this).read()
        val config = WidgetConfigStore(this)
        val choices = mutableListOf(
            Choice(getString(if (pickList) R.string.widget_config_default_list else R.string.widget_config_default_household), null, null),
        )
        snapshot?.households?.forEach { h ->
            if (pickList) {
                h.lists.forEach { choices += Choice(getString(R.string.quick_add_target, it.name, h.name), h.id, it.id) }
            } else {
                choices += Choice(h.name, h.id, null)
            }
        }
        val current = choices.indexOfFirst {
            it.householdId == config.householdId(appWidgetId) && it.listId == config.listId(appWidgetId)
        }.coerceAtLeast(0)

        val pad = dp(20)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, dp(8), pad, dp(12))
        }
        if (snapshot == null) {
            root.addView(
                TextView(this).apply {
                    setText(R.string.widget_config_no_data)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                    setPadding(0, 0, 0, dp(8))
                },
            )
        }
        val group = RadioGroup(this)
        choices.forEachIndexed { index, choice ->
            group.addView(
                RadioButton(this).apply {
                    id = index + 1
                    text = choice.label
                    minHeight = dp(48)
                    isChecked = index == current
                },
            )
        }
        val scroll = ScrollView(this).apply { addView(group) }
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        val save = Button(this).apply {
            setText(R.string.widget_config_save)
            minHeight = dp(48)
            setTextColor(Color.parseColor("#1A1714"))
            background = GradientDrawable().apply { setColor(Color.parseColor("#F97316")) }
            setPadding(dp(20), 0, dp(20), 0)
            setOnClickListener {
                val choice = choices.getOrNull(group.checkedRadioButtonId - 1) ?: choices.first()
                config.set(appWidgetId, choice.householdId, choice.listId)
                WidgetUpdater.updateAllAsync(applicationContext)
                setResult(RESULT_OK, resultIntent())
                finish()
            }
        }
        root.addView(
            save,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48)).apply {
                gravity = Gravity.END
                topMargin = dp(12)
            },
        )
        setContentView(root)
        window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    private fun resultIntent() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()
}
