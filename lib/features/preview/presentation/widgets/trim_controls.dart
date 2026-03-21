import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TrimControls extends StatelessWidget {
  final Duration maxDuration;
  final Duration currentStart;
  final Duration currentEnd;
  final Function(Duration)? onStartChanged;
  final Function(Duration)? onEndChanged;
  final Function(Duration, Duration)? onChangeEnd;
  final double speed;

  const TrimControls({
    super.key,
    required this.maxDuration,
    required this.currentStart,
    required this.currentEnd,
    this.onStartChanged,
    this.onEndChanged,
    this.onChangeEnd,
    this.speed = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(
            currentStart.inMilliseconds.toDouble(),
            currentEnd.inMilliseconds.toDouble(),
          ),
          min: 0,
          max: maxDuration.inMilliseconds.toDouble() > 0
              ? maxDuration.inMilliseconds.toDouble()
              : 100,
          onChanged: onStartChanged == null && onEndChanged == null
              ? null
              : (RangeValues values) {
                  onStartChanged?.call(
                    Duration(milliseconds: values.start.toInt()),
                  );
                  onEndChanged?.call(
                    Duration(milliseconds: values.end.toInt()),
                  );
                },
          onChangeEnd: onChangeEnd == null
              ? null
              : (RangeValues values) {
                  onChangeEnd?.call(
                    Duration(milliseconds: values.start.toInt()),
                    Duration(milliseconds: values.end.toInt()),
                  );
                },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _timeChip(Icons.start, 'Start', currentStart),
            Text(
              _formatDuration(currentEnd - currentStart),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            _timeChip(Icons.stop, 'End', currentEnd),
          ],
        ),
      ],
    );
  }

  Widget _timeChip(IconData icon, String label, Duration time) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          _formatDuration(time),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (speed != 1.0 && speed > 0.0) {
      duration = Duration(milliseconds: (duration.inMilliseconds / speed).round());
    }
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
