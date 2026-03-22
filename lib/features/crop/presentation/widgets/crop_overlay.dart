import 'package:flutter/material.dart';
import '../../../../core/models/crop_selection.dart';
import '../../../../core/theme/app_colors.dart';

class CropOverlay extends StatefulWidget {
  final CropSelection crop;
  final Rect contentBox;
  final ValueChanged<CropSelection> onCropChanged;

  const CropOverlay({
    super.key,
    required this.crop,
    required this.contentBox,
    required this.onCropChanged,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

enum _CropHandleKind {
  move,
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class _CropOverlayState extends State<CropOverlay> {
  static const double _dragSensitivity = 3.0;
  _CropHandleKind? _activeHandle;

  @override
  Widget build(BuildContext context) {
    if (widget.contentBox.isEmpty) return const SizedBox.shrink();

    final left = widget.contentBox.left + (widget.crop.left * widget.contentBox.width);
    final top = widget.contentBox.top + (widget.crop.top * widget.contentBox.height);
    final width = widget.crop.width * widget.contentBox.width;
    final height = widget.crop.height * widget.contentBox.height;
    final visibleDotSize = ((width < height ? width : height) * 0.16)
        .clamp(8.0, 14.0);

    return Stack(
      children: [
        // Dimmed area outside the crop
        _buildScrim(widget.contentBox, Rect.fromLTWH(left, top, width, height)),

        // The crop rectangle itself
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 3x3 Grid
                const _CropGrid(),

                // Drag anywhere inside the crop area to move it.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (_) => setState(() => _activeHandle = _CropHandleKind.move),
                    onPanStart: (_) => setState(() => _activeHandle = _CropHandleKind.move),
                    onPanUpdate: (details) {
                      final dx =
                          (details.delta.dx * _dragSensitivity) / widget.contentBox.width;
                      final dy =
                          (details.delta.dy * _dragSensitivity) / widget.contentBox.height;
                      widget.onCropChanged(widget.crop.move(dx, dy));
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // Edge resize zones stay attached to the crop border.
                _EdgeZone(
                  alignment: Alignment.topCenter,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.topCenter),
                  onDrag: (delta) => _onResize(delta, isTop: true),
                ),
                _EdgeZone(
                  alignment: Alignment.bottomCenter,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.bottomCenter),
                  onDrag: (delta) => _onResize(delta, isBottom: true),
                ),
                _EdgeZone(
                  alignment: Alignment.centerLeft,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.centerLeft),
                  onDrag: (delta) => _onResize(delta, isLeft: true),
                ),
                _EdgeZone(
                  alignment: Alignment.centerRight,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.centerRight),
                  onDrag: (delta) => _onResize(delta, isRight: true),
                ),

                // Corner resize zones sit above the edges for priority.
                _CornerZone(
                  alignment: Alignment.topLeft,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.topLeft),
                  onDrag: (delta) => _onResize(delta, isTop: true, isLeft: true),
                ),
                _CornerZone(
                  alignment: Alignment.topRight,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.topRight),
                  onDrag: (delta) => _onResize(delta, isTop: true, isRight: true),
                ),
                _CornerZone(
                  alignment: Alignment.bottomLeft,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.bottomLeft),
                  onDrag: (delta) => _onResize(delta, isBottom: true, isLeft: true),
                ),
                _CornerZone(
                  alignment: Alignment.bottomRight,
                  onActivate: () => setState(() => _activeHandle = _CropHandleKind.bottomRight),
                  onDrag: (delta) => _onResize(delta, isBottom: true, isRight: true),
                ),

                // Visual handle dots remain small and adaptive.
                _HandleMarker(
                  alignment: Alignment.topLeft,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.topLeft,
                ),
                _HandleMarker(
                  alignment: Alignment.topCenter,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.topCenter,
                ),
                _HandleMarker(
                  alignment: Alignment.topRight,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.topRight,
                ),
                _HandleMarker(
                  alignment: Alignment.centerLeft,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.centerLeft,
                ),
                _HandleMarker(
                  alignment: Alignment.centerRight,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.centerRight,
                ),
                _HandleMarker(
                  alignment: Alignment.bottomLeft,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.bottomLeft,
                ),
                _HandleMarker(
                  alignment: Alignment.bottomCenter,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.bottomCenter,
                ),
                _HandleMarker(
                  alignment: Alignment.bottomRight,
                  markerSize: visibleDotSize,
                  isActive: _activeHandle == _CropHandleKind.bottomRight,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onResize(Offset delta, {
    bool isTop = false,
    bool isBottom = false,
    bool isLeft = false,
    bool isRight = false,
  }) {
    final dx = (delta.dx * _dragSensitivity) / widget.contentBox.width;
    final dy = (delta.dy * _dragSensitivity) / widget.contentBox.height;

    widget.onCropChanged(widget.crop.resize(
      Offset(dx, dy),
      isTop: isTop,
      isBottom: isBottom,
      isLeft: isLeft,
      isRight: isRight,
      lockAspectRatio: widget.crop.appliedAspectRatio,
    ));
  }

  Widget _buildScrim(Rect contentBox, Rect cropRect) {
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.6),
          BlendMode.srcOut,
        ),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
            ),
            Positioned.fromRect(
              rect: cropRect,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeZone extends StatelessWidget {
  final Alignment alignment;
  final VoidCallback onActivate;
  final ValueChanged<Offset> onDrag;

  const _EdgeZone({
    required this.alignment,
    required this.onActivate,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    const thickness = 32.0;
    const cornerInset = 28.0;

    if (alignment == Alignment.topCenter) {
      return Positioned(
        left: cornerInset,
        right: cornerInset,
        top: -(thickness / 2),
        height: thickness,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    if (alignment == Alignment.bottomCenter) {
      return Positioned(
        left: cornerInset,
        right: cornerInset,
        bottom: -(thickness / 2),
        height: thickness,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    if (alignment == Alignment.centerLeft) {
      return Positioned(
        left: -(thickness / 2),
        top: cornerInset,
        bottom: cornerInset,
        width: thickness,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    return Positioned(
      right: -(thickness / 2),
      top: cornerInset,
      bottom: cornerInset,
      width: thickness,
      child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
    );
  }
}

class _CornerZone extends StatelessWidget {
  final Alignment alignment;
  final VoidCallback onActivate;
  final ValueChanged<Offset> onDrag;

  const _CornerZone({
    required this.alignment,
    required this.onActivate,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    const hitSize = 40.0;

    if (alignment == Alignment.topLeft) {
      return Positioned(
        left: -(hitSize / 2),
        top: -(hitSize / 2),
        width: hitSize,
        height: hitSize,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    if (alignment == Alignment.topRight) {
      return Positioned(
        right: -(hitSize / 2),
        top: -(hitSize / 2),
        width: hitSize,
        height: hitSize,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    if (alignment == Alignment.bottomLeft) {
      return Positioned(
        left: -(hitSize / 2),
        bottom: -(hitSize / 2),
        width: hitSize,
        height: hitSize,
        child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
      );
    }
    return Positioned(
      right: -(hitSize / 2),
      bottom: -(hitSize / 2),
      width: hitSize,
      height: hitSize,
      child: _ZoneGesture(onActivate: onActivate, onDrag: onDrag),
    );
  }
}

class _ZoneGesture extends StatelessWidget {
  final VoidCallback onActivate;
  final ValueChanged<Offset> onDrag;

  const _ZoneGesture({
    required this.onActivate,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => onActivate(),
      onPanStart: (_) => onActivate(),
      onPanUpdate: (details) => onDrag(details.delta),
      child: const SizedBox.expand(),
    );
  }
}

class _HandleMarker extends StatelessWidget {
  final Alignment alignment;
  final double markerSize;
  final bool isActive;

  const _HandleMarker({
    required this.alignment,
    required this.markerSize,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final outwardOffset = Offset(
      alignment.x * _markerThickness / 2,
      alignment.y * _markerThickness / 2,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Transform.translate(
            offset: outwardOffset,
            child: _buildMarker(),
          ),
        ),
      ),
    );
  }

  double get _markerThickness => isActive ? 5.0 : 4.0;

  Widget _buildMarker() {
    final accentColor = AppColors.accent;
    final edgeThickness = _markerThickness;
    final edgeLength = markerSize + (isActive ? 8.0 : 4.0);
    final glow = [
      BoxShadow(
        color: (isActive ? accentColor : Colors.black).withValues(
          alpha: isActive ? 0.55 : 0.3,
        ),
        blurRadius: isActive ? 10 : 4,
      ),
    ];

    if (alignment == Alignment.topCenter || alignment == Alignment.bottomCenter) {
      return Container(
        width: edgeLength,
        height: edgeThickness,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? Colors.white : AppColors.scaffoldDark,
            width: isActive ? 1.8 : 1.1,
          ),
          boxShadow: glow,
        ),
      );
    }

    if (alignment == Alignment.centerLeft || alignment == Alignment.centerRight) {
      return Container(
        width: edgeThickness,
        height: edgeLength,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? Colors.white : AppColors.scaffoldDark,
            width: isActive ? 1.8 : 1.1,
          ),
          boxShadow: glow,
        ),
      );
    }

    final cornerThickness = edgeThickness;
    final cornerLength = markerSize + 6.0;
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return SizedBox(
      width: cornerLength,
      height: cornerLength,
      child: Stack(
        children: [
          Positioned(
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            width: cornerLength,
            height: cornerThickness,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? Colors.white : AppColors.scaffoldDark,
                  width: isActive ? 1.8 : 1.1,
                ),
                boxShadow: glow,
              ),
            ),
          ),
          Positioned(
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            width: cornerThickness,
            height: cornerLength,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? Colors.white : AppColors.scaffoldDark,
                  width: isActive ? 1.8 : 1.1,
                ),
                boxShadow: glow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropGrid extends StatelessWidget {
  const _CropGrid();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(-0.33, 0),
          child: Container(width: 0.5, color: Colors.white70),
        ),
        Align(
          alignment: const Alignment(0.33, 0),
          child: Container(width: 0.5, color: Colors.white70),
        ),
        Align(
          alignment: const Alignment(0, -0.33),
          child: Container(height: 0.5, color: Colors.white70),
        ),
        Align(
          alignment: const Alignment(0, 0.33),
          child: Container(height: 0.5, color: Colors.white70),
        ),
      ],
    );
  }
}
