# Flutter and Kotlin rules for R8 / Proguard
-keep class kotlin.Unit { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Result { *; }

# SharedPreferences Android Plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin { *; }
-keep class io.flutter.plugins.sharedpreferences.Messages { *; }
-keep class io.flutter.plugins.sharedpreferences.Messages$* { *; }
