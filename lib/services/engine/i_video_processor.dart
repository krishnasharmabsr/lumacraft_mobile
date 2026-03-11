import '../../core/models/export_settings.dart';
import '../../core/models/video_filter.dart';
import 'export_result.dart';

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
  Future<ExportResult> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    required Duration trimStart,
    required Duration trimEnd,
    required double playbackSpeed,
    required VideoFilter videoFilter,
    required ExportAspectRatio aspectRatio,
    void Function(double)? onProgress,
  });
}
