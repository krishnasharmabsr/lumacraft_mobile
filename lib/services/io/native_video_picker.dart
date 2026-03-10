import 'package:flutter/services.dart';

/// Native Android video picker using ACTION_OPEN_DOCUMENT via MethodChannel.
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
}
