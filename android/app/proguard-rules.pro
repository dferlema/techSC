# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# local_auth rules
-keep class com.baseflow.localauthentication.** { *; }
-keep class androidx.biometric.** { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.storage.** { *; }

# Google Play Core (Fixes R8 missing class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.tasks.** { *; }
