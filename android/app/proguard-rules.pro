# google_mlkit_text_recognition references the optional Chinese, Devanagari,
# Japanese and Korean recognizers; only the Latin one is bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit wires its parts together at runtime through a component registry.
# R8 full mode optimises the registrars so that SharedPrefManager is never
# registered, and GmsDocumentScanning.getClient() then fails with a
# NullPointerException in release builds ("Start scanning" did nothing).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_*.** { *; }
-keep class com.google.firebase.components.** { *; }

# flutter_local_notifications keeps scheduled reminders as Gson JSON so they
# can be restored after a reboot. Without these, R8 strips the generic type
# info and release builds crash with "Missing type parameter" when scheduling.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod,InnerClasses
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
