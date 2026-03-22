import 'dart:ui';

/// Represents a normalized crop region within a video coordinate space.
///
/// Coordinates are normalized from 0.0 to 1.0, where (0,0) is top-left
/// and (1,1) is bottom-right.
class CropSelection {
  static const double _minExtent = 0.05;

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? appliedAspectRatio; // Tracks the active preset

  const CropSelection({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.appliedAspectRatio,
  });

  /// The default crop representing the entire source area.
  static const full = CropSelection(
    left: 0.0,
    top: 0.0,
    right: 1.0,
    bottom: 1.0,
    appliedAspectRatio: null,
  );

  /// Normalized width (0..1).
  double get width => (right - left).clamp(0.01, 1.0);

  /// Normalized height (0..1).
  double get height => (bottom - top).clamp(0.01, 1.0);

  /// The active aspect ratio preset.
  double? get aspectRatio => appliedAspectRatio;

  /// Returns true if the selection represents the full source area.
  bool get isFull =>
      left == 0.0 && top == 0.0 && right == 1.0 && bottom == 1.0;

  /// Moves the selection area by [dx] and [dy], clamped to bounds.
  CropSelection move(double dx, double dy) {
    var newLeft = (left + dx).clamp(0.0, 1.0 - width);
    var newTop = (top + dy).clamp(0.0, 1.0 - height);
    return copyWith(
      left: newLeft,
      top: newTop,
      right: (newLeft + width).clamp(0.0, 1.0),
      bottom: (newTop + height).clamp(0.0, 1.0),
      // Moving breaks the "locked" aspect ratio if we want to allow free movement?
      // Actually, moving shouldn't break the ratio.
    );
  }

  /// Resizes the selection from a specific handle.
  CropSelection resize(
    Offset delta, {
    required bool isTop,
    required bool isBottom,
    required bool isLeft,
    required bool isRight,
    double? lockAspectRatio,
  }) {
    if (lockAspectRatio != null && (isLeft || isRight) && (isTop || isBottom)) {
      return _resizeLockedCorner(
        delta,
        isTop: isTop,
        isBottom: isBottom,
        isLeft: isLeft,
        isRight: isRight,
        lockAspectRatio: lockAspectRatio,
      );
    }

    double newLeft = left;
    double newTop = top;
    double newRight = right;
    double newBottom = bottom;

    if (isLeft) newLeft = (left + delta.dx).clamp(0.0, right - _minExtent);
    if (isRight) newRight = (right + delta.dx).clamp(left + _minExtent, 1.0);
    if (isTop) newTop = (top + delta.dy).clamp(0.0, bottom - _minExtent);
    if (isBottom) newBottom = (bottom + delta.dy).clamp(top + _minExtent, 1.0);

    if (lockAspectRatio != null) {
      double newWidth = newRight - newLeft;
      double newHeight = newBottom - newTop;

      if (isLeft || isRight) {
        newHeight = newWidth / lockAspectRatio;
      } else {
        newWidth = newHeight * lockAspectRatio;
      }

      if (isLeft || isRight) {
        final centerY = (top + bottom) / 2;
        newTop = (centerY - newHeight / 2).clamp(0.0, 1.0 - newHeight);
        newBottom = newTop + newHeight;
      } else {
        final centerX = (left + right) / 2;
        newLeft = (centerX - newWidth / 2).clamp(0.0, 1.0 - newWidth);
        newRight = newLeft + newWidth;
      }
    }

    return copyWith(
      left: newLeft,
      top: newTop,
      right: newRight,
      bottom: newBottom,
      appliedAspectRatio: lockAspectRatio,
    );
  }

  /// Returns a new selection with the given aspect ratio, centered.
  CropSelection withAspectRatio(double? ratio) {
    if (ratio == null) return copyWith(clearAspectRatio: true);

    // To prevent compounding shrinkage, we always calculate relative to
    // the max possible area centered at the current selection.
    double newWidth;
    double newHeight;

    if (ratio > 1.0) {
      // Wide ratio: max width is 1.0
      newWidth = 1.0;
      newHeight = 1.0 / ratio;
    } else {
      // Tall ratio: max height is 1.0
      newHeight = 1.0;
      newWidth = ratio;
    }

    // Centering
    double centerX = left + width / 2;
    double centerY = top + height / 2;

    double leftVal = (centerX - newWidth / 2);
    double topVal = (centerY - newHeight / 2);

    // If it goes out of bounds, shift it back
    if (leftVal < 0) leftVal = 0;
    if (topVal < 0) topVal = 0;
    if (leftVal + newWidth > 1.0) leftVal = 1.0 - newWidth;
    if (topVal + newHeight > 1.0) topVal = 1.0 - newHeight;

    return CropSelection(
      left: leftVal,
      top: topVal,
      right: leftVal + newWidth,
      bottom: topVal + newHeight,
      appliedAspectRatio: ratio,
    );
  }

  CropSelection _resizeLockedCorner(
    Offset delta, {
    required bool isTop,
    required bool isBottom,
    required bool isLeft,
    required bool isRight,
    required double lockAspectRatio,
  }) {
    final anchorX = isLeft ? right : left;
    final anchorY = isTop ? bottom : top;

    final currentWidth = right - left;
    final currentHeight = bottom - top;

    final rawWidth = (currentWidth + (isLeft ? -delta.dx : delta.dx))
        .clamp(_minExtent, 1.0);
    final rawHeight = (currentHeight + (isTop ? -delta.dy : delta.dy))
        .clamp(_minExtent, 1.0);

    final horizontalDominant =
        delta.dx.abs() >= (delta.dy.abs() * lockAspectRatio);

    double nextWidth = horizontalDominant ? rawWidth : rawHeight * lockAspectRatio;
    double nextHeight = nextWidth / lockAspectRatio;

    final availableWidth = isLeft ? anchorX : (1.0 - anchorX);
    final availableHeight = isTop ? anchorY : (1.0 - anchorY);
    final maxWidth = availableWidth < availableHeight * lockAspectRatio
        ? availableWidth
        : availableHeight * lockAspectRatio;

    nextWidth = nextWidth.clamp(_minExtent, maxWidth);
    nextHeight = nextWidth / lockAspectRatio;

    final newLeft = isLeft ? anchorX - nextWidth : anchorX;
    final newRight = isRight ? anchorX + nextWidth : anchorX;
    final newTop = isTop ? anchorY - nextHeight : anchorY;
    final newBottom = isBottom ? anchorY + nextHeight : anchorY;

    return CropSelection(
      left: newLeft,
      top: newTop,
      right: newRight,
      bottom: newBottom,
      appliedAspectRatio: lockAspectRatio,
    );
  }

  /// Creates a copy with selected fields replaced.
  CropSelection copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? appliedAspectRatio,
    bool clearAspectRatio = false,
  }) {
    return CropSelection(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      appliedAspectRatio:
          clearAspectRatio ? null : (appliedAspectRatio ?? this.appliedAspectRatio),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropSelection &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom &&
          appliedAspectRatio == other.appliedAspectRatio;

  @override
  int get hashCode => Object.hash(left, top, right, bottom, appliedAspectRatio);

  @override
  String toString() =>
      'CropSelection(l: ${left.toStringAsFixed(3)}, t: ${top.toStringAsFixed(3)}, '
      'r: ${right.toStringAsFixed(3)}, b: ${bottom.toStringAsFixed(3)})';
}
