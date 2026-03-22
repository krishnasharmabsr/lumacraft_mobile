import 'export_settings.dart';
import 'video_filter.dart';

/// An immutable bundle representing the exact parameters needed to
/// execute a video export operation. This isolates the engine layer
/// from raw orchestration arguments and UI state primitives.
class VideoExportRequest {
  final String inputPath;
  final String outputPath;
  final ExportSettings settings;
  final Duration trimStart;
  final Duration trimEnd;
  final double speed;
  final VideoFilter filter;
  final ExportAspectRatio canvas;

  const VideoExportRequest({
    required this.inputPath,
    required this.outputPath,
    required this.settings,
    required this.trimStart,
    required this.trimEnd,
    required this.speed,
    required this.filter,
    required this.canvas,
  });
}
