import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/export_settings.dart';
import 'package:lumacraft_mobile/core/models/video_filter.dart';
import 'package:lumacraft_mobile/features/preview/domain/editor_edits.dart';

void main() {
  const fiveSeconds = Duration(seconds: 5);

  group('EditorEdits.defaults', () {
    test('produces zero trimStart', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.trimStart, Duration.zero);
    });

    test('produces trimEnd equal to totalDuration', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.trimEnd, fiveSeconds);
    });

    test('produces 1.0 speed', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.speed, 1.0);
    });

    test('produces original filter', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.filter, VideoFilter.original);
    });

    test('produces source canvas', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.canvas, ExportAspectRatio.source);
    });
  });

  group('EditorEdits.hasEdits', () {
    test('returns false for defaults', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.hasEdits(fiveSeconds), isFalse);
    });

    test('returns false when trimStart is within 100ms threshold', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimStart: const Duration(milliseconds: 50),
      );
      expect(d.hasEdits(fiveSeconds), isFalse);
    });

    test('returns true when trimStart exceeds 100ms threshold', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimStart: const Duration(milliseconds: 200),
      );
      expect(d.hasEdits(fiveSeconds), isTrue);
    });

    test('returns false when trimEnd is within 100ms of totalDuration', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimEnd: fiveSeconds - const Duration(milliseconds: 50),
      );
      expect(d.hasEdits(fiveSeconds), isFalse);
    });

    test('returns true when trimEnd is more than 100ms before totalDuration', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimEnd: fiveSeconds - const Duration(milliseconds: 200),
      );
      expect(d.hasEdits(fiveSeconds), isTrue);
    });

    test('returns true when speed is not 1.0', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(speed: 1.5);
      expect(d.hasEdits(fiveSeconds), isTrue);
    });

    test('returns true when filter is not original', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        filter: VideoFilter.bright,
      );
      expect(d.hasEdits(fiveSeconds), isTrue);
    });

    test('returns true when canvas is not source', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        canvas: ExportAspectRatio.square,
      );
      expect(d.hasEdits(fiveSeconds), isTrue);
    });
  });

  group('EditorEdits.copyWith', () {
    test('returns equal value when no fields changed', () {
      final d = EditorEdits.defaults(fiveSeconds);
      expect(d.copyWith(), equals(d));
    });

    test('updates trimStart only', () {
      final d = EditorEdits.defaults(fiveSeconds);
      final updated = d.copyWith(trimStart: const Duration(seconds: 1));
      expect(updated.trimStart, const Duration(seconds: 1));
      expect(updated.trimEnd, d.trimEnd);
      expect(updated.speed, d.speed);
      expect(updated.filter, d.filter);
      expect(updated.canvas, d.canvas);
    });

    test('updates trimEnd only', () {
      final d = EditorEdits.defaults(fiveSeconds);
      final updated = d.copyWith(trimEnd: const Duration(seconds: 3));
      expect(updated.trimEnd, const Duration(seconds: 3));
      expect(updated.trimStart, d.trimStart);
    });

    test('updates speed only — no cross-field contamination', () {
      final d = EditorEdits.defaults(fiveSeconds);
      final updated = d.copyWith(speed: 2.0);
      expect(updated.speed, 2.0);
      expect(updated.filter, d.filter);
      expect(updated.canvas, d.canvas);
      expect(updated.trimStart, d.trimStart);
    });

    test('updates filter only — no cross-field contamination', () {
      final d = EditorEdits.defaults(fiveSeconds);
      final updated = d.copyWith(filter: VideoFilter.vintage);
      expect(updated.filter, VideoFilter.vintage);
      expect(updated.speed, d.speed);
    });

    test('updates canvas only — no cross-field contamination', () {
      final d = EditorEdits.defaults(fiveSeconds);
      final updated = d.copyWith(canvas: ExportAspectRatio.horizontal);
      expect(updated.canvas, ExportAspectRatio.horizontal);
      expect(updated.speed, d.speed);
      expect(updated.filter, d.filter);
    });

    test('equality is value-based', () {
      final a = EditorEdits.defaults(fiveSeconds);
      final b = EditorEdits.defaults(fiveSeconds);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('EditorEdits.clampTrimTo', () {
    test('clamps trimEnd to newDuration when it exceeds', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimEnd: fiveSeconds,
      );
      final clamped = d.clampTrimTo(const Duration(seconds: 3));
      expect(clamped.trimEnd, const Duration(seconds: 3));
    });

    test('clamps trimStart to zero when it exceeds newDuration', () {
      final d = EditorEdits.defaults(fiveSeconds).copyWith(
        trimStart: const Duration(seconds: 4),
      );
      final clamped = d.clampTrimTo(const Duration(seconds: 2));
      expect(clamped.trimStart, Duration.zero);
    });

    test('preserves speed, filter, canvas unchanged after clamp', () {
      final d = EditorEdits(
        trimStart: Duration.zero,
        trimEnd: fiveSeconds,
        speed: 2.0,
        filter: VideoFilter.warm,
        canvas: ExportAspectRatio.square,
      );
      final clamped = d.clampTrimTo(const Duration(seconds: 3));
      expect(clamped.speed, 2.0);
      expect(clamped.filter, VideoFilter.warm);
      expect(clamped.canvas, ExportAspectRatio.square);
    });
  });
}
