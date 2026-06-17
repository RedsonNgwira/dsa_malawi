# R8/ProGuard rules for DSA Malawi
# Prevents R8 from stripping optional Google ML Kit language packs

# Google ML Kit Text Recognition - keep all language options
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Keep ML Kit commons
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# Keep all Google ML Kit model classes
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
