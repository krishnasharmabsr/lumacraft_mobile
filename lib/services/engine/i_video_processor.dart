import '../../core/models/video_export_request.dart';
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
    required VideoExportRequest request,
    void Function(double)? onProgress,
  });
}
