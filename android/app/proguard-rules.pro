# Preserve ExoPlayer classes used by just_audio
-keep class com.google.android.exoplayer2.** { *; }

# Keep AudioService classes
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }

# Flutter embedding & method channel
-keep class io.flutter.plugin.common.MethodChannel** { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }

# Prevent stripping of annotations and metadata
-keepattributes *Annotation*
