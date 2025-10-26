# --- Flutter core classes ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Keep your MainActivity ---
-keep class com.cropsync.cropsync.MainActivity { *; }

# --- Fix for Play Core SplitCompat missing class issue ---
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# --- General keep rules ---
-keep class * extends android.app.Application
-keepclassmembers class * implements java.io.Serializable { *; }
-keepclassmembers class * implements android.os.Parcelable { *; }

# --- Optional: prevent stripping Flutter generated plugin registrant ---
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
