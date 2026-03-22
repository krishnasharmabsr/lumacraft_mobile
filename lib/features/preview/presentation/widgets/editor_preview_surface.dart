import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/export_settings.dart';

import '../../domain/editor_edits.dart';
import '../models/editor_preview_overrides.dart';
import 'playback_timeline.dart';

class EditorPreviewSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final Duration videoDuration;
  final EditorEdits edits;
  final EditorPreviewOverrides preview;
  final bool isProcessing;

  // Overlay State Tracking
  final bool showOverlay;
  final bool showVolumeSlider;
  final bool isMuted;
  final double volume;

  // Action Callbacks
  final VoidCallback onToggleOverlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleVolumeSlider;
  final Function(double localDy, double trackHeight)
  onSetVolumeFromVerticalDrag;
  final VoidCallback onResetOverlayTimer;
  final VoidCallback onCancelOverlayTimer;

  // Timeline Scrubbing Callbacks
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubUpdate;
  final VoidCallback onScrubEnd;

  const EditorPreviewSurface({
    super.key,
    required this.controller,
    required this.videoDuration,
    required this.edits,
    required this.preview,
    required this.isProcessing,
    required this.showOverlay,
    required this.showVolumeSlider,
    required this.isMuted,
    required this.volume,
    required this.onToggleOverlay,
    required this.onTogglePlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleMute,
    required this.onToggleVolumeSlider,
    required this.onSetVolumeFromVerticalDrag,
    required this.onResetOverlayTimer,
    required this.onCancelOverlayTimer,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  String _formatDuration(Duration duration, {double speed = 1.0}) {
    if (speed != 1.0 && speed > 0.0) {
      duration = Duration(
        milliseconds: (duration.inMilliseconds / speed).round(),
      );
    }
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  ColorFilter? _buildColorFilter() {
    final matrix = preview.effectiveFilter(edits).matrix;
    if (matrix == null) return null;
    return ColorFilter.matrix(matrix);
  }

  Widget _buildVideoContent() {
    Widget video = SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    );

    final colorFilter = _buildColorFilter();
    if (colorFilter != null) {
      video = ColorFiltered(colorFilter: colorFilter, child: video);
    }

    return video;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleOverlay,
      child: Container(
        color: AppColors.playerBg,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio:
                  preview.effectiveCanvas(edits) == ExportAspectRatio.source ||
                      preview.effectiveCanvas(edits).ratio == null
                  ? controller.value.aspectRatio
                  : preview.effectiveCanvas(edits).ratio!,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.contain,
                  clipBehavior: Clip.hardEdge,
                  child: _buildVideoContent(),
                ),
              ),
            ),
            if (showOverlay && !isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: Stack(
                    children: [
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                iconSize: 36,
                                color: Colors.white,
                                onPressed: onSeekBack,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                iconSize: 56,
                                color: Colors.white,
                                icon: Icon(
                                  controller.value.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                ),
                                onPressed: onTogglePlayPause,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                iconSize: 36,
                                color: Colors.white,
                                onPressed: onSeekForward,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {}, // Blocks overlay toggle
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                              vertical: AppTheme.spacingSm,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomLeft,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: onToggleMute,
                                          onLongPress: onToggleVolumeSlider,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              isMuted || volume == 0
                                                  ? Icons.volume_off
                                                  : Icons.volume_up,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_formatDuration(controller.value.position, speed: edits.speed)} / ${_formatDuration(videoDuration, speed: edits.speed)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    PlaybackTimeline(
                                      currentPosition:
                                          controller.value.position,
                                      duration: videoDuration,
                                      trimStart: edits.trimStart,
                                      trimEnd: edits.trimEnd,
                                      onScrubStart: onScrubStart,
                                      onScrubUpdate: onScrubUpdate,
                                      onScrubEnd: onScrubEnd,
                                    ),
                                  ],
                                ),
                                if (showVolumeSlider)
                                  Positioned(
                                    left: 8,
                                    bottom: 64,
                                    child: Container(
                                      height: 140,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final trackHeight =
                                              constraints.maxHeight - 20;
                                          final knobBottom =
                                              (volume * trackHeight)
                                                  .clamp(0.0, trackHeight)
                                                  .toDouble();
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) {
                                              onCancelOverlayTimer();
                                              onSetVolumeFromVerticalDrag(
                                                details.localPosition.dy,
                                                constraints.maxHeight,
                                              );
                                              onResetOverlayTimer();
                                            },
                                            onVerticalDragStart: (_) =>
                                                onCancelOverlayTimer(),
                                            onVerticalDragUpdate: (details) {
                                              onSetVolumeFromVerticalDrag(
                                                details.localPosition.dy,
                                                constraints.maxHeight,
                                              );
                                            },
                                            onVerticalDragEnd: (_) =>
                                                onResetOverlayTimer(),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Positioned(
                                                  top: 10,
                                                  bottom: 10,
                                                  child: Container(
                                                    width: 4,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white30,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  left: 18,
                                                  right: 18,
                                                  bottom: 10,
                                                  height: trackHeight * volume,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 2 + knobBottom,
                                                  child: Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors.accent,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
