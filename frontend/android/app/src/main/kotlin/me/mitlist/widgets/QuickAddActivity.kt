package me.mitlist.widgets

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.speech.RecognizerIntent
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import kotlinx.coroutines.launch
import me.mitlist.R

/**
 * Stage 6 quick add: a small native dialog over whatever the user was doing,
 * so adding "milk" never waits for Flutter to start. The item goes through
 * the same queue and delivery as a widget tap (D4).
 */
class QuickAddActivity : Activity() {
    private lateinit var input: EditText
    private lateinit var listChip: Button
    private var targets: List<Target> = emptyList()
    private var selected: Target? = null

    /** A list the user can add to, with its household. */
    private data class Target(val householdId: String, val householdName: String, val listId: String, val listName: String)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setTitle(R.string.quick_add_title)
        val snapshot = WidgetFiles.snapshot(this).read()
        if (snapshot == null) {
            showSetup()
            return
        }
        targets = snapshot.households.flatMap { h ->
            h.lists.map { Target(h.id, h.name, it.id, it.name) }
        }
        if (targets.isEmpty()) {
            showSetup()
            return
        }
        val widgetId = intent.quickAddWidgetId()
        val config = WidgetConfigStore(this)
        val configured = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            snapshot.resolveList(config.householdId(widgetId), config.listId(widgetId))
        } else {
            snapshot.resolveList(null, null)
        }
        selected = configured?.let { (h, l) -> targets.firstOrNull { it.householdId == h.id && it.listId == l.id } }
            ?: targets.first()
        buildForm()
        if (savedInstanceState == null && intent.getBooleanExtra(EXTRA_VOICE, false)) startVoice()
    }

    private fun buildForm() {
        val pad = dp(20)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, dp(8), pad, dp(12))
        }
        listChip = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            isAllCaps = false
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            minHeight = dp(48)
            setOnClickListener { chooseList() }
        }
        updateChip()
        root.addView(listChip, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        input = EditText(this).apply {
            setHint(R.string.quick_add_hint)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_DONE
            isSingleLine = true
            minHeight = dp(48)
            setOnEditorActionListener { _, actionId, event ->
                if (actionId == EditorInfo.IME_ACTION_DONE ||
                    (event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN)
                ) {
                    add()
                    true
                } else {
                    false
                }
            }
        }
        row.addView(input, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val mic = ImageButton(this).apply {
            setImageResource(R.drawable.ic_widget_mic)
            contentDescription = getString(R.string.quick_add_voice)
            background = null
            minimumWidth = dp(48)
            minimumHeight = dp(48)
            setColorFilter(BRAND_ORANGE)
            setOnClickListener { startVoice() }
        }
        row.addView(mic, LinearLayout.LayoutParams(dp(48), dp(48)))
        root.addView(row)

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, dp(12), 0, 0)
        }
        val cancel = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            setText(android.R.string.cancel)
            minHeight = dp(48)
            setOnClickListener { finish() }
        }
        val addButton = Button(this).apply {
            setText(R.string.quick_add_button)
            minHeight = dp(48)
            setTextColor(Color.parseColor("#1A1714"))
            background = GradientDrawable().apply { setColor(BRAND_ORANGE) }
            setPadding(dp(20), 0, dp(20), 0)
            setOnClickListener { add() }
        }
        actions.addView(cancel)
        actions.addView(addButton, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48)).apply { marginStart = dp(8) })
        root.addView(actions)

        setContentView(root)
        window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        input.requestFocus()
    }

    private fun updateChip() {
        val target = selected ?: return
        listChip.text = getString(R.string.quick_add_target, target.listName, target.householdName)
        listChip.contentDescription = getString(R.string.quick_add_choose_list_cd, target.listName)
    }

    private fun chooseList() {
        val labels = targets.map { getString(R.string.quick_add_target, it.listName, it.householdName) }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(R.string.quick_add_choose_list)
            .setSingleChoiceItems(labels, targets.indexOf(selected)) { dialog, which ->
                selected = targets[which]
                updateChip()
                dialog.dismiss()
            }
            .show()
    }

    private fun add() {
        val target = selected ?: return
        val name = input.text.toString().trim()
        if (name.isEmpty()) {
            input.error = getString(R.string.quick_add_empty)
            return
        }
        val op = PendingOp.addItem(target.householdId, target.listId, name, System.currentTimeMillis(), PendingOp.SOURCE_QUICK_ADD)
        val app = applicationContext
        WidgetScope.launch { enqueue(app, op) }
        Toast.makeText(app, getString(R.string.quick_add_added, target.listName), Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun startVoice() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PROMPT, getString(R.string.quick_add_voice_prompt))
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_VOICE)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, R.string.quick_add_voice_unavailable, Toast.LENGTH_SHORT).show()
        }
    }

    @Deprecated("Activity result API needs androidx.activity; this activity stays dependency-free.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_VOICE || resultCode != RESULT_OK) return
        val spoken = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.trim()
        if (spoken.isNullOrEmpty() || !::input.isInitialized) return
        // Spoken items start capitalised like typed ones ("milk" → "Milk").
        input.setText(spoken.replaceFirstChar { it.titlecase() })
        input.setSelection(input.text.length)
    }

    /** No snapshot yet: the app has to be opened once (sign-in, first sync). */
    private fun showSetup() {
        val pad = dp(20)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, dp(8), pad, dp(12))
        }
        root.addView(
            TextView(this).apply {
                setText(R.string.quick_add_setup)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            },
        )
        val open = Button(this).apply {
            setText(R.string.widget_open_app)
            minHeight = dp(48)
            setTextColor(Color.parseColor("#1A1714"))
            background = GradientDrawable().apply { setColor(BRAND_ORANGE) }
            setOnClickListener {
                startLink(WidgetLinks.app(this@QuickAddActivity))
                finish()
            }
        }
        root.addView(open, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48)).apply { topMargin = dp(16); gravity = Gravity.END })
        setContentView(root)
        window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        root.visibility = View.VISIBLE
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    companion object {
        private const val EXTRA_VOICE = "me.mitlist.widgets.VOICE"
        private const val REQUEST_VOICE = 47
        private val BRAND_ORANGE = Color.parseColor("#F97316")

        fun intent(context: Context, appWidgetId: Int, voice: Boolean): Intent =
            Intent(context, QuickAddActivity::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                .putExtra(EXTRA_VOICE, voice)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
    }
}
