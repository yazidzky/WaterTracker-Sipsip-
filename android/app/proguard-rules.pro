# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver

# Gson (used by some plugins including this one potentially)
-keep class com.google.gson.** { *; }

# Android Lifecycle
-keep class androidx.lifecycle.DefaultLifecycleObserver
