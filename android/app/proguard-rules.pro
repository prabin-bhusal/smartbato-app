# Keep Flutter and plugin reflection paths stable in release.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.example.app.** { *; }
-dontwarn io.flutter.embedding.**
