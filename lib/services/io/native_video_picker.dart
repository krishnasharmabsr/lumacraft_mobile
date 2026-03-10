import 'dart:developer' as developer;
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

  /// Returns the duration of the media file in milliseconds as a string.
  /// Uses MediaMetadataRetriever on Android.
  static Future<String?> getMediaDuration(String path) async {
    if (Platform.isAndroid) {
      try {
        final String? duration = await _channel.invokeMethod<String>(
          'getMediaDuration',
          {'path': path},
        );
        return duration;
      } catch (e) {
        developer.log(
          'NativeVideoPicker getMediaDuration error: $e',
          name: 'NativeVideoPicker',
        );
        return null;
      }
    }
    return null;
  }

  /// Returns the duration of the media file using MediaExtractor fallback.
  static Future<String?> getMediaDurationExtractor(String path) async {
    if (Platform.isAndroid) {
      try {
        final String? duration = await _channel.invokeMethod<String>(
          'getMediaDurationExtractor',
          {'path': path},
        );
        return duration;
      } catch (e) {
        developer.log(
          'NativeVideoPicker getMediaDurationExtractor error: $e',
          name: 'NativeVideoPicker',
        );
        return null;
      }
    }
    return null;
  }
}
