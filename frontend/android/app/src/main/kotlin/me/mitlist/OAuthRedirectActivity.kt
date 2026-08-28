package me.mitlist

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives the `mitlist:///auth/callback` redirect that ends the OAuth flow and
 * hands it to [MainActivity].
 *
 * The indirection exists to close the Custom Tab. The tab runs inside this
 * app's task, sitting above [MainActivity], so a redirect delivered straight to
 * MainActivity (`singleTop`) would stack a *second* Flutter activity on top of
 * the tab and leave the browser in the back stack. This activity is
 * `singleTask`, so launching it clears everything above it — the tab included —
 * and forwarding with `CLEAR_TOP | SINGLE_TOP` then reuses the existing
 * MainActivity, delivering the deep link to its `onNewIntent` for Flutter's
 * router to pick up.
 */
class OAuthRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forward(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forward(intent)
    }

    private fun forward(source: Intent) {
        val callback = source.data
        if (callback != null) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = callback
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        }
        finish()
    }
}
