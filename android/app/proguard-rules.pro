# ============================================================================
# PANOPTES — R8 / PROGUARD ANTI-REVERSE-ENGINEERING & ML KIT RULES
# ============================================================================

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google ML Kit Face Detection native JNI bridge protection
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.android.odml.image.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Strip verbose debug/trace logging in release builds to prevent logcat leakage
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}
