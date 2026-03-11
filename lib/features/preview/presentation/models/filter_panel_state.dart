import '../../../../core/models/video_filter.dart';

class FilterPanelState {
  final VideoFilter previewedFilter;
  final VideoFilter appliedFilter;

  const FilterPanelState({
    required this.previewedFilter,
    required this.appliedFilter,
  });

  bool get hasPendingChanges => previewedFilter != appliedFilter;

  String get appliedBadgeLabel => 'Export: ${appliedFilter.label}';

  String get statusText {
    if (hasPendingChanges) {
      return 'Previewing ${previewedFilter.label}. Export will use ${appliedFilter.label} until you apply.';
    }
    if (appliedFilter.isOriginal) {
      return 'Preview and export both use Original.';
    }
    return 'Preview matches export: ${appliedFilter.label}.';
  }

  String get applyButtonLabel {
    if (!hasPendingChanges) {
      return appliedFilter.isOriginal
          ? 'Original Applied'
          : '${appliedFilter.label} Applied';
    }
    return previewedFilter.isOriginal
        ? 'Apply Original'
        : 'Apply ${previewedFilter.label}';
  }
}
