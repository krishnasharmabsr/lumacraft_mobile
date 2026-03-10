import '../../core/models/export_settings.dart';

/// Interface for video processing operations.
abstract class IVideoProcessor {
  Future<String> processTrim({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
    void Function(double)? onProgress,
  });

  Future<String> processSpeed({
    required String inputPath,
    required String outputPath,
    required double speed,
    void Function(double)? onProgress,
  });

  Future<String> processCanvas({
    required String inputPath,
    required String outputPath,
    required String scaleFilter,
    void Function(double)? onProgress,
  });

  Future<String> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    Duration? trimStart,
    Duration? trimEnd,
    void Function(double)? onProgress,
  });
}
