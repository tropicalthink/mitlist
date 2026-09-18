# The Flutter embedding AAR ships its own consumer keep rules and the Flutter
# Gradle plugin injects flutter_proguard_rules.pro, so no blanket io.flutter.**
# keep is needed here. A `-keep class io.flutter.** { *; }` used to live here and
# exempted about half of the DEX from R8 (Play "App optimisation" review, 2026-09-18).

# Move every obfuscated class into the root package: smaller DEX, and Play's
# "Repackage classes" check. Default behaviour from AGP 9.1.
-repackageclasses ''

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

# TensorFlow Lite / LiteRT (tflite_flutter) — Dart talks to the C API through
# dart:ffi, so the Java classes only need their JNI entry points preserved.
# The optional GPU delegate is not bundled (CPU-only inference; see
# grocery_classifier_service.dart). Matches missing_rules.txt.
-keepclasseswithmembers class org.tensorflow.lite.** { native <methods>; }
-keepclasseswithmembers class com.google.ai.edge.litert.** { native <methods>; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**
