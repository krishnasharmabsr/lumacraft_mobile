import 'dart:io';
import 'package:flutter/services.dart';

/// Native Android service via MethodChannel.
/// Provides video picking (ACTION_OPEN_DOCUMENT) and cache path access.
/// Bypasses Flutter plugin registration issues in release builds.
class NativeVideoPicker {
  static const _channel = MethodChannel('com.lumacraft.studio/video_picker');

  /// Returns the local cache path of the picked video, or null if cancelled.
  static Future<String?> pickVideo() async {
    try {
      final String? path = await _channel.invokeMethod<String>('pickVideo');
      return path;
    } on PlatformException catch (e) {
      throw Exception('Native video picker error: ${e.message}');
    }
  }

  /// Returns the app cache directory path from the native side.
  /// Replaces path_provider dependency for Android.
  static Future<String> getCachePath() async {
    if (Platform.isAndroid) {
      final String? path = await _channel.invokeMethod<String>('getCachePath');
      if (path != null) return path;
    }
    // Fallback for non-Android or failure
    return Directory.systemTemp.path;
  }
}
