import 'package:flutter/material.dart';

class TrimControls extends StatelessWidget {
  final Duration maxDuration;
  final Duration currentStart;
  final Duration currentEnd;
  final Function(Duration) onStartChanged;
  final Function(Duration) onEndChanged;

  const TrimControls({
    super.key,
    required this.maxDuration,
    required this.currentStart,
    required this.currentEnd,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Trim Video", style: TextStyle(fontWeight: FontWeight.bold)),
        RangeSlider(
          values: RangeValues(
            currentStart.inMilliseconds.toDouble(),
            currentEnd.inMilliseconds.toDouble(),
          ),
          min: 0,
          max: maxDuration.inMilliseconds.toDouble() > 0
              ? maxDuration.inMilliseconds.toDouble()
              : 100,
          onChanged: (RangeValues values) {
            onStartChanged(Duration(milliseconds: values.start.toInt()));
            onEndChanged(Duration(milliseconds: values.end.toInt()));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Start: ${_formatDuration(currentStart)}"),
            Text("End: ${_formatDuration(currentEnd)}"),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
