# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ZegoCloud keep rules
-keep class com.zego.** { *; }
-keep class im.zego.** { *; }
-dontwarn com.zego.**
-dontwarn im.zego.**

# Zego express engine
-keep class com.zegotech.** { *; }
-dontwarn com.zegotech.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Suppress missing class warnings for optional dependencies
-dontwarn com.itgsa.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
