# Flutter plugin Pigeon channel keep rules
# Prevents R8 from stripping Pigeon-generated platform channel classes
# that are required for release builds.

# Keep all Flutter plugin classes (they register via reflection)
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep all Pigeon-generated API classes used by Flutter plugins
-keep class dev.flutter.pigeon.** { *; }

# Keep video_player native bindings
-keep class io.flutter.plugins.videoplayer.** { *; }

# Keep permission_handler native bindings
-keep class com.baseflow.permissionhandler.** { *; }

# Keep gal native bindings
-keep class app.myzel394.gal.** { *; }

# Keep FFmpegKit native bindings
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.flutter.** { *; }

# Keep our own MethodChannel handler
-keep class com.lumacraft.studio.MainActivity { *; }

# Prevent stripping of Flutter embedding classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
