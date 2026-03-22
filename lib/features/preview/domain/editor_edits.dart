import '../../../../core/models/export_settings.dart';
import '../../../../core/models/video_filter.dart';
import '../../../../core/models/crop_selection.dart';

/// Immutable value object representing the **committed, export-authoritative**
/// edit state for the editor. This is the single source of truth for what will
/// be used during export.
///
/// Presentation-only preview overrides live in [EditorPreviewOverrides].
class EditorEdits {
  final Duration trimStart;
  final Duration trimEnd;

  /// Applied playback speed (1.0 = no change). Used in export.
  final double speed;

  /// Applied video filter (VideoFilter.original = no filter). Used in export.
  final VideoFilter filter;

  /// Applied canvas / aspect ratio (ExportAspectRatio.source = no change).
  final ExportAspectRatio canvas;

  /// Applied crop selection (CropSelection.full = no crop).
  final CropSelection crop;

  const EditorEdits({
    required this.trimStart,
    required this.trimEnd,
    required this.speed,
    required this.filter,
    required this.canvas,
    required this.crop,
  });

  /// Default (no-edit) state for a given total video duration.
  static EditorEdits defaults(Duration totalDuration) => EditorEdits(
    trimStart: Duration.zero,
    trimEnd: totalDuration,
    speed: 1.0,
    filter: VideoFilter.original,
    canvas: ExportAspectRatio.source,
    crop: CropSelection.full,
  );

  /// Returns true if any edit is materially different from the unedited state.
  ///
  /// Trim threshold: 100ms matches the existing screen-level check, ensuring
  /// sub-100ms rounding errors in slider callbacks do not trigger false positives.
  bool hasEdits(Duration totalDuration) {
    final isTrimmed =
        trimStart.inMilliseconds > 100 ||
        trimEnd < totalDuration - const Duration(milliseconds: 100);
    return isTrimmed ||
        filter != VideoFilter.original ||
        speed != 1.0 ||
        canvas != ExportAspectRatio.source ||
        !crop.isFull;
  }

  /// Clamps trim bounds to fit within [newDuration].
  ///
  /// Used after `_initializePlayer(keepEdits: true)` when the new video
  /// duration (e.g. after a processTrim) may be shorter than the current bounds.
  EditorEdits clampTrimTo(Duration newDuration) {
    return copyWith(
      trimStart: trimStart > newDuration ? Duration.zero : trimStart,
      trimEnd: trimEnd > newDuration ? newDuration : trimEnd,
    );
  }

  /// Creates a copy with selected fields replaced.
  EditorEdits copyWith({
    Duration? trimStart,
    Duration? trimEnd,
    double? speed,
    VideoFilter? filter,
    ExportAspectRatio? canvas,
    CropSelection? crop,
  }) {
    return EditorEdits(
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      speed: speed ?? this.speed,
      filter: filter ?? this.filter,
      canvas: canvas ?? this.canvas,
      crop: crop ?? this.crop,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorEdits &&
          trimStart == other.trimStart &&
          trimEnd == other.trimEnd &&
          speed == other.speed &&
          filter == other.filter &&
          canvas == other.canvas &&
          crop == other.crop;

  @override
  int get hashCode => Object.hash(trimStart, trimEnd, speed, filter, canvas, crop);

  @override
  String toString() =>
      'EditorEdits(trimStart: $trimStart, trimEnd: $trimEnd, speed: $speed, '
      'filter: ${filter.label}, canvas: ${canvas.label}, crop: $crop)';
}
