import '../../features/preview/domain/editor_edits.dart';
import 'export_settings.dart';

/// An immutable bundle representing the exact parameters needed to
/// execute a video export operation. This isolates the engine layer
/// from raw orchestration arguments and UI state primitives.
class VideoExportRequest {
  final String inputPath;
  final String outputPath;
  final ExportSettings settings;
  final EditorEdits edits;

  const VideoExportRequest({
    required this.inputPath,
    required this.outputPath,
    required this.settings,
    required this.edits,
  });
}
