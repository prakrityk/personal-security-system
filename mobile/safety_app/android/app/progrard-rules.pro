# ============================================================
# TENSORFLOW LITE - ULTIMATE KEEP RULES
# ============================================================
# Keep ALL TensorFlow classes without exception
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Specifically keep the missing class and its constructor
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep all native methods and classes that might be called via JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Don't warn about any missing TensorFlow classes (they are handled by the keeps)
-dontwarn org.tensorflow.**
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**

# ============================================================
# IGNORE ALL OTHER WARNINGS (They are not breaking the build)
# ============================================================
-dontwarn com.google.mlkit.**
-dontwarn com.tfliteflutter.**
-dontwarn com.ryanheise.audioservice.**
-dontwarn co.quis.flutter_contacts.**
-dontwarn io.flutter.plugins.firebase.database.**
-dontwarn com.llfbandit.record.**

# ============================================================
# GENERIC ANDROID RULES
# ============================================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# Keep all public classes and methods (broad but safe)
-keep class * {
    public protected *;
}