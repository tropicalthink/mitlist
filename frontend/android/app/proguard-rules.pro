# Flutter wrapper — the Flutter Gradle plugin also injects its own rules,
# but keep the embedding explicitly to be safe.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep the app entry point referenced from the manifest.
-keep class me.mitlist.MainActivity { *; }

# Annotations and generic signatures used by JSON/reflection paths.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Suppress notes about missing optional platform classes.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Play Core split-install APIs — referenced by Flutter deferred components but
# optional when not using Play Feature Delivery (see missing_rules.txt).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# TensorFlow Lite (tflite_flutter) — keep the interpreter runtime, and suppress
# the optional GPU delegate which we don't bundle (CPU-only inference; see
# grocery_classifier_service.dart). Matches missing_rules.txt.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**
