package me.mitlist

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * The single entry point for every `mitlist://` link — the OAuth callback
 * (`mitlist:///auth/callback`), invites (`mitlist:///join/<code>`) and shared
 * recipes (`mitlist:///r/<token>`) — which it hands to [MainActivity].
 *
 * Exactly one activity may claim the scheme. Android ignores `pathPrefix` on
 * an intent filter that has no `host`, and these URIs have none (the triple
 * slash is deliberate: Flutter routes on the path), so splitting the scheme
 * across two activities by path does not work — both match every link, and
 * Android shows an app chooser listing "mitlist" twice for our own OAuth
 * redirect.
 *
 * The indirection also closes the Custom Tab that Google or Apple sign-in
 * runs in. The tab sits above MainActivity in this app's task, so a redirect
 * delivered straight to MainActivity (`singleTop`) would stack a *second*
 * Flutter activity on top of the tab and leave the browser in the back stack.
 * This activity is `singleTask`, so launching it clears everything above it —
 * the tab included — and forwarding with `CLEAR_TOP | SINGLE_TOP` then reuses
 * the existing MainActivity, delivering the link to its `onNewIntent` for
 * Flutter's router to pick up. From a cold start there is nothing to clear
 * and MainActivity simply launches with the link as its initial route.
 */
class DeepLinkActivity : Activity() {
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
        val link = source.data
        if (link != null) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = link
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        }
        finish()
    }
}
