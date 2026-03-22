import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/export_settings.dart';
import 'package:lumacraft_mobile/core/models/video_filter.dart';
import 'package:lumacraft_mobile/features/preview/domain/editor_edits.dart';
import 'package:lumacraft_mobile/features/preview/presentation/models/editor_preview_overrides.dart';

void main() {
  const fiveSeconds = Duration(seconds: 5);
  final baseEdits = EditorEdits.defaults(fiveSeconds);

  group('EditorPreviewOverrides — effectiveSpeed', () {
    test('returns override speed when set', () {
      const overrides = EditorPreviewOverrides(speed: 2.0);
      expect(overrides.effectiveSpeed(baseEdits), 2.0);
    });

    test('falls back to edits.speed when null', () {
      const overrides = EditorPreviewOverrides();
      // baseEdits.speed is 1.0
      expect(overrides.effectiveSpeed(baseEdits), 1.0);
    });

    test('falls back to non-default edits.speed when null', () {
      final edits = baseEdits.copyWith(speed: 0.5);
      const overrides = EditorPreviewOverrides();
      expect(overrides.effectiveSpeed(edits), 0.5);
    });
  });

  group('EditorPreviewOverrides — effectiveFilter', () {
    test('returns override filter when set', () {
      final overrides = EditorPreviewOverrides(filter: VideoFilter.vintage);
      expect(overrides.effectiveFilter(baseEdits), VideoFilter.vintage);
    });

    test('falls back to edits.filter when null', () {
      const overrides = EditorPreviewOverrides();
      expect(overrides.effectiveFilter(baseEdits), VideoFilter.original);
    });

    test('falls back to non-default edits.filter when null', () {
      final edits = baseEdits.copyWith(filter: VideoFilter.warm);
      const overrides = EditorPreviewOverrides();
      expect(overrides.effectiveFilter(edits), VideoFilter.warm);
    });
  });

  group('EditorPreviewOverrides — effectiveCanvas', () {
    test('returns override canvas when set', () {
      const overrides = EditorPreviewOverrides(canvas: ExportAspectRatio.square);
      expect(overrides.effectiveCanvas(baseEdits), ExportAspectRatio.square);
    });

    test('falls back to edits.canvas when null', () {
      const overrides = EditorPreviewOverrides();
      expect(overrides.effectiveCanvas(baseEdits), ExportAspectRatio.source);
    });

    test('falls back to non-default edits.canvas when null', () {
      final edits = baseEdits.copyWith(canvas: ExportAspectRatio.horizontal);
      const overrides = EditorPreviewOverrides();
      expect(overrides.effectiveCanvas(edits), ExportAspectRatio.horizontal);
    });
  });

  group('EditorPreviewOverrides — none constant', () {
    test('none has all null fields', () {
      expect(EditorPreviewOverrides.none.speed, isNull);
      expect(EditorPreviewOverrides.none.filter, isNull);
      expect(EditorPreviewOverrides.none.canvas, isNull);
    });
  });

  group('EditorPreviewOverrides — mutation helpers', () {
    test('withSpeed updates speed only', () {
      const base = EditorPreviewOverrides(filter: VideoFilter.bright);
      final updated = base.withSpeed(1.5);
      expect(updated.speed, 1.5);
      expect(updated.filter, VideoFilter.bright);
      expect(updated.canvas, isNull);
    });

    test('withFilter updates filter only', () {
      const base = EditorPreviewOverrides(speed: 2.0);
      final updated = base.withFilter(VideoFilter.cool);
      expect(updated.filter, VideoFilter.cool);
      expect(updated.speed, 2.0);
      expect(updated.canvas, isNull);
    });

    test('withCanvas updates canvas only', () {
      const base = EditorPreviewOverrides(speed: 0.5);
      final updated = base.withCanvas(ExportAspectRatio.vertical);
      expect(updated.canvas, ExportAspectRatio.vertical);
      expect(updated.speed, 0.5);
      expect(updated.filter, isNull);
    });
  });
}
