# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# App components registered in the manifest / method channels.
-keep class com.arham.hisaab.** { *; }

# JNI (sqlite3, Impeller, etc.)
-keepclasseswithmembernames class * {
    native <methods>;
}

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Keep line numbers for Play crash deobfuscation.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
