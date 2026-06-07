# Flutter wrapper — the Flutter Gradle plugin also injects its own rules,
# but keep the embedding explicitly to be safe.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep the app entry point referenced from the manifest.
-keep class mitlist.me.MainActivity { *; }

# Annotations and generic signatures used by JSON/reflection paths.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Suppress notes about missing optional platform classes.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
