import '../../../../core/models/export_settings.dart';
import '../../../../core/models/video_filter.dart';
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

  const EditorPreviewOverrides({this.speed, this.filter, this.canvas});

  /// All-null default: no overrides active.
  static const none = EditorPreviewOverrides();

  // ── Effective value resolution ──────────────────────────────────────────

  /// The speed to apply to the player preview.
  double effectiveSpeed(EditorEdits edits) => speed ?? edits.speed;

  /// The filter to render in preview.
  VideoFilter effectiveFilter(EditorEdits edits) => filter ?? edits.filter;

  /// The canvas to show in preview.
  ExportAspectRatio effectiveCanvas(EditorEdits edits) => canvas ?? edits.canvas;

  // ── Pending-change helpers ──────────────────────────────────────────────

  bool get hasSpeedOverride => speed != null;
  bool get hasFilterOverride => filter != null;
  bool get hasCanvasOverride => canvas != null;

  // ── Mutation helpers ────────────────────────────────────────────────────

  EditorPreviewOverrides withSpeed(double? value) =>
      EditorPreviewOverrides(speed: value, filter: filter, canvas: canvas);

  EditorPreviewOverrides withFilter(VideoFilter? value) =>
      EditorPreviewOverrides(speed: speed, filter: value, canvas: canvas);

  EditorPreviewOverrides withCanvas(ExportAspectRatio? value) =>
      EditorPreviewOverrides(speed: speed, filter: filter, canvas: value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorPreviewOverrides &&
          speed == other.speed &&
          filter == other.filter &&
          canvas == other.canvas;

  @override
  int get hashCode => Object.hash(speed, filter, canvas);

  @override
  String toString() =>
      'EditorPreviewOverrides(speed: $speed, filter: ${filter?.label}, '
      'canvas: ${canvas?.label})';
}
