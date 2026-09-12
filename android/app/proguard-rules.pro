# ProGuard Rules for Nour Ramadan App
# Prevents R8 from obfuscating/removing critical code in Release builds

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep all Kotlin classes in com.NourRamadan package
-keep class com.NourRamadan.** { *; }
-keepclassmembers class com.NourRamadan.** { *; }

# ✅ PHASE 2: Adhan library (prayer times calculation)
-keep class com.batoulapps.adhan.** { *; }
-dontwarn com.batoulapps.adhan.**

# Keep BroadcastReceiver classes
-keep public class * extends android.content.BroadcastReceiver
-keep class com.NourRamadan.AzanAlarmReceiver { *; }
-keep class com.NourRamadan.AzanBootReceiver { *; }
-keep class com.NourRamadan.TimeChangeReceiver { *; }

# Keep Service classes
-keep public class * extends android.app.Service
-keep class com.NourRamadan.PrayerCountdownService { *; }
-keep class com.NourRamadan.AzanForegroundService { *; }

# Keep Plugin classes
-keep class com.NourRamadan.AzanPlugin { *; }
-keepclassmembers class com.NourRamadan.AzanPlugin { *; }

# Keep all companion objects and their members
-keepclassmembers class * {
    public static final ** Companion;
}
-keepclassmembers class **$Companion {
    *;
}

# Keep Intent extra keys
-keepclassmembers class * {
    public static final java.lang.String EXTRA_*;
    public static final java.lang.String ACTION_*;
}

# Keep all methods that handle Intents
-keepclassmembers class * extends android.content.BroadcastReceiver {
    public void onReceive(android.content.Context, android.content.Intent);
}

# Keep all Service lifecycle methods
-keepclassmembers class * extends android.app.Service {
    public int onStartCommand(android.content.Intent, int, int);
    public android.os.IBinder onBind(android.content.Intent);
}

# Keep MethodChannel handlers
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler {
    public void onMethodCall(io.flutter.plugin.common.MethodCall, io.flutter.plugin.common.MethodChannel$Result);
}

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore specific
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.v1.** { *; }
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.DocumentId <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.ServerTimestamp <fields>;
}

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Keep source file names and line numbers for better crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Remove logging in release builds (optional - comment out if you need logs)
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
# }

# Keep crash reporting
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# WorkManager
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}

# SharedPreferences
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }

# AlarmManager
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# MediaPlayer
-keep class android.media.MediaPlayer { *; }
-keep class android.media.AudioManager { *; }

# Firebase Crashlytics
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Play Core (optional - for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep all model classes that use Firestore
-keep class * {
    @com.google.firebase.firestore.IgnoreExtraProperties *;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName *;
}

# If you use custom model classes, keep them
# Replace 'com.NourRamadan.models' with your actual package
-keep class com.NourRamadan.models.** { *; }
-keep class com.NourRamadan.features.**.models.** { *; }
