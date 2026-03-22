import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PlaybackTimeline extends StatelessWidget {
  final Duration currentPosition;
  final Duration duration;
  final Duration trimStart;
  final Duration trimEnd;
  final VoidCallback? onScrubStart;
  final ValueChanged<Duration>? onScrubUpdate;
  final VoidCallback? onScrubEnd;

  const PlaybackTimeline({
    super.key,
    required this.currentPosition,
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
    this.onScrubStart,
    this.onScrubUpdate,
    this.onScrubEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (duration.inMilliseconds < 1000) return const SizedBox(height: 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalMillis = duration.inMilliseconds.toDouble();
        final startRatio = totalMillis > 0
            ? trimStart.inMilliseconds / totalMillis
            : 0.0;
        final endRatio = totalMillis > 0
            ? trimEnd.inMilliseconds / totalMillis
            : 1.0;
        final positionRatio = totalMillis > 0
            ? currentPosition.inMilliseconds / totalMillis
            : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 24,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base track
                Center(
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Trim region highlight
                Positioned(
                  left: startRatio * constraints.maxWidth,
                  top: 10,
                  width:
                      (endRatio - startRatio).clamp(0.0, 1.0) *
                      constraints.maxWidth,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Native Slider overlay for scrubbing
                Positioned(
                  left: -24,
                  right: -24,
                  top: -12,
                  bottom: -12,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 24,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: AppColors.accent,
                    ),
                    child: Slider(
                      value: (positionRatio * totalMillis).clamp(
                        0.0,
                        totalMillis,
                      ),
                      min: 0,
                      max: totalMillis,
                      onChangeStart: (_) => onScrubStart?.call(),
                      onChanged: (val) {
                        onScrubUpdate?.call(
                          Duration(milliseconds: val.round()),
                        );
                      },
                      onChangeEnd: (_) => onScrubEnd?.call(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
