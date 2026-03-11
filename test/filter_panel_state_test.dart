import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/video_filter.dart';
import 'package:lumacraft_mobile/features/preview/presentation/models/filter_panel_state.dart';

void main() {
  group('FilterPanelState', () {
    test('uses explicit preview and export messaging when preview differs', () {
      const state = FilterPanelState(
        previewedFilter: VideoFilter.blackAndWhite,
        appliedFilter: VideoFilter.bright,
      );

      expect(state.hasPendingChanges, true);
      expect(state.appliedBadgeLabel, 'Export: Bright');
      expect(
        state.statusText,
        'Previewing B&W. Export will use Bright until you apply.',
      );
      expect(state.applyButtonLabel, 'Apply B&W');
    });

    test('reports matched non-original preview/export state clearly', () {
      const state = FilterPanelState(
        previewedFilter: VideoFilter.warm,
        appliedFilter: VideoFilter.warm,
      );

      expect(state.hasPendingChanges, false);
      expect(state.appliedBadgeLabel, 'Export: Warm');
      expect(state.statusText, 'Preview matches export: Warm.');
      expect(state.applyButtonLabel, 'Warm Applied');
    });

    test('reports original state clearly', () {
      const state = FilterPanelState(
        previewedFilter: VideoFilter.original,
        appliedFilter: VideoFilter.original,
      );

      expect(state.hasPendingChanges, false);
      expect(state.appliedBadgeLabel, 'Export: Original');
      expect(state.statusText, 'Preview and export both use Original.');
      expect(state.applyButtonLabel, 'Original Applied');
    });
  });
}
