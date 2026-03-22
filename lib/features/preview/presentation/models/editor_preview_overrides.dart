import '../../../../core/models/export_settings.dart';
import '../../../../core/models/video_filter.dart';
import '../../../../core/models/crop_selection.dart';
import '../../../preview/domain/editor_edits.dart';

/// Transient, UI-only preview overrides for tool drag states.
///
/// When a field is null, the corresponding [EditorEdits] value is authoritative.
/// This object is preserved while the editor session remains active so preview
/// state continues to match the previous screen-local behavior.
///
/// It is reset only when the editor resets all edits or a fresh player
/// initialization discards the current editing session.
///
/// **Trim is not here.** Trim bounds are committed directly into [EditorEdits]
/// on every slider change — there is no deferred "Apply Trim" action.
///
/// ## keepEdits: true reinit
///
/// On `_initializePlayer(keepEdits: true)` (only called from `_processTrim`),
/// [EditorPreviewOverrides] is **preserved**, not reset. This matches the
/// previous behavior where `_previewSpeed`, `_previewFilter`, and
/// `_previewCanvas` were preserved across that reinit.
///
/// The user may have the speed tool open with a pending preview drag, then
/// trigger Trim Process while still in the trim panel; the speed preview must
/// survive the reinit.
class EditorPreviewOverrides {
  /// Pending preview speed from the speed slider, or null if unchanged.
  final double? speed;

  /// Pending preview filter from the filter selector, or null if unchanged.
  final VideoFilter? filter;

  /// Pending preview canvas selection, or null if unchanged.
  final ExportAspectRatio? canvas;

  /// Pending preview crop selection, or null if unchanged.
  final CropSelection? crop;

  const EditorPreviewOverrides({
    this.speed,
    this.filter,
    this.canvas,
    this.crop,
  });

  /// All-null default: no overrides active.
  static const none = EditorPreviewOverrides();

  // ── Effective value resolution ──────────────────────────────────────────

  /// The speed to apply to the player preview.
  double effectiveSpeed(EditorEdits edits) => speed ?? edits.speed;

  /// The filter to render in preview.
  VideoFilter effectiveFilter(EditorEdits edits) => filter ?? edits.filter;

  /// The canvas to show in preview.
  ExportAspectRatio effectiveCanvas(EditorEdits edits) => canvas ?? edits.canvas;

  /// The crop to show in preview.
  CropSelection effectiveCrop(EditorEdits edits) => crop ?? edits.crop;

  // ── Pending-change helpers ──────────────────────────────────────────────

  bool get hasSpeedOverride => speed != null;
  bool get hasFilterOverride => filter != null;
  bool get hasCanvasOverride => canvas != null;
  bool get hasCropOverride => crop != null;

  // ── Mutation helpers ────────────────────────────────────────────────────

  EditorPreviewOverrides withSpeed(double? value) =>
      EditorPreviewOverrides(speed: value, filter: filter, canvas: canvas, crop: crop);

  EditorPreviewOverrides withFilter(VideoFilter? value) =>
      EditorPreviewOverrides(speed: speed, filter: value, canvas: canvas, crop: crop);

  EditorPreviewOverrides withCanvas(ExportAspectRatio? value) =>
      EditorPreviewOverrides(speed: speed, filter: filter, canvas: value, crop: crop);

  EditorPreviewOverrides withCrop(CropSelection? value) =>
      EditorPreviewOverrides(speed: speed, filter: filter, canvas: canvas, crop: value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorPreviewOverrides &&
          speed == other.speed &&
          filter == other.filter &&
          canvas == other.canvas &&
          crop == other.crop;

  @override
  int get hashCode => Object.hash(speed, filter, canvas, crop);

  @override
  String toString() =>
      'EditorPreviewOverrides(speed: $speed, filter: ${filter?.label}, '
      'canvas: ${canvas?.label}, crop: $crop)';
}
