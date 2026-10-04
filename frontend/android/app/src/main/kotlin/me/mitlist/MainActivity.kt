package me.mitlist

import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.mitlist.widgets.WidgetChannel
import me.mitlist.widgets.WidgetUpdater

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 15 cancels a widget's PendingIntents when the app is
        // force-stopped; re-push every widget so their taps work again.
        WidgetUpdater.onAppStart(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Home screen widgets bridge (plans/047, contract C4).
        WidgetChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mitlist/oauth_launcher",
        ).setMethodCallHandler { call, result ->
            if (call.method != "startAuthSession") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val url = call.argument<String>("url")
            if (url.isNullOrBlank()) {
                result.error("invalid_url", "OAuth URL is required.", null)
                return@setMethodCallHandler
            }

            try {
                CustomTabsIntent.Builder()
                    .setShowTitle(true)
                    .setUrlBarHidingEnabled(true)
                    .build()
                    .launchUrl(this, Uri.parse(url))
                // Unlike iOS's ASWebAuthenticationSession, a Custom Tab cannot
                // hand the callback back through this channel. The mitlist://
                // redirect lands in DeepLinkActivity, which dismisses the
                // tab and forwards the deep link here. Answering null tells the
                // caller "opened, expect the router to take it from here".
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error(
                    "launch_failed",
                    "No browser available to complete sign-in.",
                    null,
                )
            }
        }
    }
}
