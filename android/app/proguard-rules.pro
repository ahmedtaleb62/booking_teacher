# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Jitsi Meet SDK ────────────────────────────────────────────────────────────
-keep class org.jitsi.** { *; }
-keep class org.jitsi.meet.** { *; }
-dontwarn org.jitsi.**

# WebRTC (used internally by Jitsi)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# React Native bridge (Jitsi runs on React Native)
-keep class com.facebook.react.** { *; }
-dontwarn com.facebook.react.**

# Hermes JS engine (React Native runtime)
-keep class com.facebook.hermes.** { *; }
-dontwarn com.facebook.hermes.**

# JNI helpers
-keep class com.facebook.jni.** { *; }
-dontwarn com.facebook.jni.**

# Fresco image pipeline
-keep class com.facebook.imagepipeline.** { *; }
-dontwarn com.facebook.imagepipeline.**
-dontwarn com.facebook.imagepipeline.nativecode.**

# SoLoader (native lib loader used by React Native)
-keep class com.facebook.soloader.** { *; }
-dontwarn com.facebook.soloader.**

# WebRTC module
-keep class com.oney.WebRTCModule.** { *; }
-dontwarn com.oney.WebRTCModule.**

# Amplitude analytics (used by Jitsi internally)
-keep class com.amplitude.** { *; }
-dontwarn com.amplitude.**

# ── Firebase ──────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Google Play Core ──────────────────────────────────────────────────────────
-dontwarn com.google.android.play.core.**

# ── Kotlin / Coroutines ───────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
