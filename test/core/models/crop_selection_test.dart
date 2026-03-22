import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/crop_selection.dart';

void main() {
  group('CropSelection.withAspectRatio', () {
    test('clears applied aspect ratio for Free mode', () {
      final square = CropSelection.full.withAspectRatio(1.0);

      final free = square.withAspectRatio(null);

      expect(free.appliedAspectRatio, isNull);
      expect(free.left, square.left);
      expect(free.top, square.top);
      expect(free.right, square.right);
      expect(free.bottom, square.bottom);
    });
  });

  group('CropSelection.resize', () {
    test('corner resize with locked ratio changes both axes', () {
      const crop = CropSelection(
        left: 0.25,
        top: 0.25,
        right: 0.75,
        bottom: 0.75,
        appliedAspectRatio: 1.0,
      );

      final resized = crop.resize(
        const Offset(-0.10, -0.06),
        isTop: true,
        isLeft: true,
        isBottom: false,
        isRight: false,
        lockAspectRatio: 1.0,
      );

      expect(resized.width, greaterThan(crop.width));
      expect(resized.height, greaterThan(crop.height));
      expect(resized.width, closeTo(resized.height, 0.0001));
      expect(resized.right, crop.right);
      expect(resized.bottom, crop.bottom);
    });

    test('free corner resize changes width and height independently', () {
      const crop = CropSelection(
        left: 0.20,
        top: 0.20,
        right: 0.70,
        bottom: 0.70,
      );

      final resized = crop.resize(
        const Offset(-0.05, 0.10),
        isTop: true,
        isLeft: true,
        isBottom: false,
        isRight: false,
      );

      expect(resized.left, lessThan(crop.left));
      expect(resized.top, greaterThan(crop.top));
      expect(resized.right, crop.right);
      expect(resized.bottom, crop.bottom);
    });
  });

  group('CropSelection equality', () {
    test('includes appliedAspectRatio in equality', () {
      const free = CropSelection.full;
      const square = CropSelection(
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
        appliedAspectRatio: 1.0,
      );

      expect(free, isNot(equals(square)));
    });
  });
}
