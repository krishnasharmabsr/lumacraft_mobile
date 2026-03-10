import '../../core/models/export_settings.dart';

/// Interface for video processing operations.
abstract class IVideoProcessor {
  /// Extract a trimmed portion of the video.
  Future<String> processTrim({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
    void Function(double)? onProgress,
  });

  /// Master combined export pass.
  Future<String> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    required Duration trimStart,
    required Duration trimEnd,
    required double playbackSpeed,
    required ExportAspectRatio aspectRatio,
    void Function(double)? onProgress,
  });
}
