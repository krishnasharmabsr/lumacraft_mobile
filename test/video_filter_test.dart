import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/video_filter.dart';

void main() {
  group('VideoFilter', () {
    test('contains the curated S012 filter set in order', () {
      expect(VideoFilter.all.map((filter) => filter.label).toList(), [
        'Original',
        'Bright',
        'Contrast',
        'Warm',
        'Cool',
        'Vintage',
        'B&W',
      ]);
    });

    test('original is the fallback when lookup misses', () {
      expect(VideoFilter.fromLabel('missing'), VideoFilter.original);
      expect(VideoFilter.fromLabel(null), VideoFilter.original);
    });

    test('non-original filters expose both preview and export definitions', () {
      expect(VideoFilter.warm.isOriginal, false);
      expect(VideoFilter.warm.ffmpegFilter, isNotNull);
      expect(VideoFilter.warm.matrix, isNotNull);
      expect(VideoFilter.warm.matrix, hasLength(20));
    });
  });
}
