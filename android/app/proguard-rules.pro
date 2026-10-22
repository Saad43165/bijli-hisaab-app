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
