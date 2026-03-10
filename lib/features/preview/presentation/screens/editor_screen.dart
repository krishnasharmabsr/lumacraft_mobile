import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';

import '../../../../core/models/export_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/engine/ffmpeg_processor.dart';
import '../../../../services/io/media_io_service.dart';
import '../../../../services/io/native_video_picker.dart';
import '../../../export/presentation/widgets/export_settings_sheet.dart';
import '../widgets/processing_overlay.dart';
import '../widgets/trim_controls.dart';

class EditorScreen extends StatefulWidget {
  final String videoPath;

  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  VideoPlayerController? _controller;
  final FFmpegProcessor _processor = FFmpegProcessor();
  final MediaIoService _ioService = MediaIoService();

  late String _workingVideoPath;

  // --- Timeline ---
  Duration _videoDuration = Duration.zero;
  bool _isTimelineInvalid = false;

  // --- Trim state ---
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;

  // --- Speed state (preview vs applied) ---
  double _previewSpeed = 1.0;
  double _appliedSpeed = 1.0;

  // --- Canvas state (preview vs applied) ---
  ExportAspectRatio _previewCanvas = ExportAspectRatio.source;
  ExportAspectRatio _appliedCanvas = ExportAspectRatio.source;

  // --- Processing ---
  bool _isProcessing = false;
  bool _isPreviewingTrim = false;
  String _processingLabel = '';
  double _processingProgress = -1;

  VoidCallback? _previewListener;

  bool get _hasEdits {
    if (_videoDuration == Duration.zero) return false;
    final isTrimmed =
        _trimStart.inMilliseconds > 100 ||
        _trimEnd < _videoDuration - const Duration(milliseconds: 100);
    return isTrimmed ||
        _appliedSpeed != 1.0 ||
        _appliedCanvas != ExportAspectRatio.source;
  }

  @override
  void initState() {
    super.initState();
    _workingVideoPath = widget.videoPath;
    _initializePlayer(_workingVideoPath);
  }

  // ────────────────────────────────────────────────────────────
  //  PLAYER INIT WITH FFPROBE DURATION FALLBACK
  // ────────────────────────────────────────────────────────────
  Future<void> _initializePlayer(String path, {bool keepEdits = false}) async {
    final oldController = _controller;

    final newController = VideoPlayerController.file(File(path));
    await newController.initialize();

    Duration resolvedDuration = newController.value.duration;

    // Fallback chain when video_player reports 0
    if (resolvedDuration.inMilliseconds <= 0) {
      resolvedDuration = await _resolveDurationViaFFprobe(path);
    }

    final timelineInvalid = resolvedDuration.inMilliseconds <= 0;

    if (mounted) {
      setState(() {
        _controller = newController;
        _videoDuration = resolvedDuration;
        _isTimelineInvalid = timelineInvalid;
        _trimStart = Duration.zero;
        _trimEnd = resolvedDuration;
        _isPreviewingTrim = false;
        if (!keepEdits) {
          _previewSpeed = 1.0;
          _appliedSpeed = 1.0;
          _previewCanvas = ExportAspectRatio.source;
          _appliedCanvas = ExportAspectRatio.source;
        }
      });
    }

    newController.addListener(() {
      if (mounted) setState(() {});
    });

    if (!timelineInvalid) {
      newController.play();
    }
    oldController?.dispose();

    if (timelineInvalid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Timeline unavailable for this file. Trim controls disabled.',
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// FFprobe fallback: tries format duration, then first video stream duration.
  Future<Duration> _resolveDurationViaFFprobe(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final media = info.getMediaInformation();
      if (media == null) return Duration.zero;

      // Try format-level duration
      final formatDur = media.getDuration();
      if (formatDur != null) {
        final secs = double.tryParse(formatDur);
        if (secs != null && secs > 0) {
          return Duration(milliseconds: (secs * 1000).round());
        }
      }

      // Try stream-level duration
      final streams = media.getStreams();
      if (streams.isNotEmpty) {
        for (final stream in streams) {
          if (stream.getType() == 'video') {
            final props = stream.getAllProperties();
            if (props != null) {
              final streamDur = props['duration'] ?? props['tags']?['DURATION'];
              if (streamDur != null) {
                final secs = double.tryParse(streamDur.toString());
                if (secs != null && secs > 0) {
                  return Duration(milliseconds: (secs * 1000).round());
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return Duration.zero;
  }

  @override
  void dispose() {
    _removePreviewListener();
    _controller?.dispose();
    super.dispose();
  }

  void _removePreviewListener() {
    if (_previewListener != null && _controller != null) {
      _controller!.removeListener(_previewListener!);
      _previewListener = null;
    }
    _isPreviewingTrim = false;
  }

  // ────────────────────────────────────────────────────────────
  //  RESET
  // ────────────────────────────────────────────────────────────
  void _resetEdits() {
    if (!_hasEdits) return;
    setState(() {
      _trimStart = Duration.zero;
      _trimEnd = _videoDuration;
      _previewSpeed = 1.0;
      _appliedSpeed = 1.0;
      _previewCanvas = ExportAspectRatio.source;
      _appliedCanvas = ExportAspectRatio.source;
    });
    _controller?.setPlaybackSpeed(1.0);
    _controller?.seekTo(Duration.zero);
  }

  // ────────────────────────────────────────────────────────────
  //  TRIM WORKFLOW
  // ────────────────────────────────────────────────────────────
  void _previewTrim() {
    final ctrl = _controller;
    if (ctrl == null || _isTimelineInvalid) return;

    _removePreviewListener();
    ctrl.seekTo(_trimStart);
    ctrl.setPlaybackSpeed(_previewSpeed);
    ctrl.play();
    _isPreviewingTrim = true;

    _previewListener = () {
      if (!mounted || !_isPreviewingTrim) return;
      if (ctrl.value.position >= _trimEnd) {
        ctrl.pause();
        _removePreviewListener();
        if (mounted) setState(() {});
      }
    };
    ctrl.addListener(_previewListener!);
    setState(() {});
  }

  Future<void> _processTrim() async {
    final ctrl = _controller;
    if (ctrl == null || _isTimelineInvalid) return;

    // Validate range
    final delta = _trimEnd - _trimStart;
    if (delta.inMilliseconds <= 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trim range is too small or invalid.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingLabel = 'Trimming video...';
      _processingProgress = 0;
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final outputPath = '$cachePath/trim_${const Uuid().v4()}.mp4';

      await _processor.processTrim(
        inputPath: _workingVideoPath,
        outputPath: outputPath,
        startTime: _trimStart,
        endTime: _trimEnd,
        onProgress: (p) {
          if (mounted) setState(() => _processingProgress = p);
        },
      );

      // Reload player with trimmed video, keep applied speed/canvas
      _workingVideoPath = outputPath;
      await _initializePlayer(outputPath, keepEdits: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Trim error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingProgress = -1;
        });
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  //  SPEED
  // ────────────────────────────────────────────────────────────
  void _applySpeed() {
    setState(() => _appliedSpeed = _previewSpeed);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speed ${_appliedSpeed.toStringAsFixed(2)}x applied.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  //  CANVAS
  // ────────────────────────────────────────────────────────────
  void _applyCanvas() {
    setState(() => _appliedCanvas = _previewCanvas);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Canvas ${_appliedCanvas.label} applied.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  //  EXPORT
  // ────────────────────────────────────────────────────────────
  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportSettingsSheet(
        onExport: (settings) => _exportWithSettings(settings),
      ),
    );
  }

  Future<void> _exportWithSettings(ExportSettings settings) async {
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Exporting ${settings.resolution.label}...';
      _processingProgress = 0;
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final outputPath =
          '$cachePath/export_${const Uuid().v4()}.${settings.extension}';

      await _processor.processExport(
        inputPath: _workingVideoPath,
        outputPath: outputPath,
        settings: settings,
        trimStart: _trimStart,
        trimEnd: _trimEnd,
        playbackSpeed: _appliedSpeed,
        aspectRatio: _appliedCanvas,
        onProgress: (p) {
          if (mounted) setState(() => _processingProgress = p);
        },
      );

      final success = await _ioService.saveVideoToGallery(outputPath);

      if (mounted) {
        final fileName = outputPath.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Exported $fileName to gallery!' : 'Export failed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingProgress = -1;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      appBar: _isProcessing
          ? null
          : AppBar(
              title: const Text('LumaCraft Editor'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_hasEdits)
                  TextButton.icon(
                    onPressed: _resetEdits,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
              ],
            ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── VIDEO PREVIEW ──
                if (isReady)
                  Flexible(
                    flex: 3,
                    child: Container(
                      color: AppColors.playerBg,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                _previewCanvas == ExportAspectRatio.source ||
                                    _previewCanvas.ratio == null
                                ? ctrl.value.aspectRatio
                                : _previewCanvas.ratio!,
                            child: VideoPlayer(ctrl),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _isProcessing
                                  ? null
                                  : () {
                                      _removePreviewListener();
                                      setState(() {
                                        ctrl.value.isPlaying
                                            ? ctrl.pause()
                                            : ctrl.play();
                                      });
                                    },
                              behavior: HitTestBehavior.translucent,
                              child: AnimatedOpacity(
                                opacity: ctrl.value.isPlaying ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  color: Colors.black38,
                                  child: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: AppColors.accent,
                                    size: 56,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(
                    flex: 3,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),

                // ── PLAYBACK BAR ──
                if (isReady)
                  Container(
                    color: AppColors.surfaceDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                      vertical: AppTheme.spacingSm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(ctrl.value.position),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            ctrl.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.textPrimary,
                          ),
                          iconSize: 28,
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  _removePreviewListener();
                                  setState(() {
                                    ctrl.value.isPlaying
                                        ? ctrl.pause()
                                        : ctrl.play();
                                  });
                                },
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(_videoDuration),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── CONTROLS ──
                if (isReady)
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingLg,
                        vertical: AppTheme.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTrimCard(ctrl),
                          const SizedBox(height: AppTheme.spacingMd),
                          _buildSpeedCard(),
                          const SizedBox(height: AppTheme.spacingMd),
                          _buildCanvasCard(),
                          const SizedBox(height: AppTheme.spacingLg),
                          _buildExportButton(),
                          const SizedBox(height: AppTheme.spacingLg),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isProcessing)
            ProcessingOverlay(
              label: _processingLabel,
              progress: _processingProgress,
            ),
        ],
      ),
    );
  }

  // ── TRIM CARD ──
  Widget _buildTrimCard(VideoPlayerController ctrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.content_cut_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Trim',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_isTimelineInvalid)
                  const Text(
                    '⚠ Unavailable',
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (_isTimelineInvalid)
              const Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: Text(
                  'Timeline could not be resolved for this video. Trim is disabled.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            TrimControls(
              maxDuration: _videoDuration,
              currentStart: _trimStart,
              currentEnd: _trimEnd,
              onStartChanged: _isTimelineInvalid
                  ? null
                  : (start) {
                      setState(() => _trimStart = start);
                    },
              onEndChanged: _isTimelineInvalid
                  ? null
                  : (end) => setState(() => _trimEnd = end),
              onChangeEnd: _isTimelineInvalid
                  ? null
                  : (start, end) {
                      setState(() {
                        _trimStart = start;
                        _trimEnd = end;
                      });
                      _previewTrim(); // Auto-preview when user releases drag
                    },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_isProcessing || _isTimelineInvalid)
                    ? null
                    : _processTrim,
                icon: const Icon(Icons.cut_rounded, size: 18),
                label: const Text('Process Trim'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.scaffoldDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SPEED CARD ──
  Widget _buildSpeedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Speed',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _appliedSpeed != 1.0
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.cardDarkAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    '${_previewSpeed.toStringAsFixed(2)}x',
                    style: TextStyle(
                      color: _appliedSpeed != 1.0
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            // Labels at edges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0.25x',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                Text(
                  '8.0x',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            Slider(
              value: _previewSpeed,
              min: 0.25,
              max: 8.0,
              divisions: 31, // 0.25 increments
              activeColor: AppColors.accent,
              inactiveColor: AppColors.divider,
              onChanged: (val) {
                setState(
                  () => _previewSpeed = (val * 4).roundToDouble() / 4,
                ); // snap to 0.25
                _controller?.setPlaybackSpeed(_previewSpeed);
              },
            ),
            if (_appliedSpeed != 1.0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: Text(
                  'Applied: ${_appliedSpeed.toStringAsFixed(2)}x',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _applySpeed,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Apply Speed'),
                style: FilledButton.styleFrom(
                  backgroundColor: _previewSpeed != _appliedSpeed
                      ? AppColors.accent
                      : AppColors.cardDarkAlt,
                  foregroundColor: _previewSpeed != _appliedSpeed
                      ? AppColors.scaffoldDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CANVAS CARD ──
  Widget _buildCanvasCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.crop_free_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Canvas',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_appliedCanvas != ExportAspectRatio.source)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      _appliedCanvas.label,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ExportAspectRatio.values.map((ratio) {
                  final isSelected = _previewCanvas == ratio;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _previewCanvas = ratio);
                      // Instant visual preview in viewport
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.cardDarkAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.divider,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ratio.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.scaffoldDark
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _applyCanvas,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Apply Canvas'),
                style: FilledButton.styleFrom(
                  backgroundColor: _previewCanvas != _appliedCanvas
                      ? AppColors.accent
                      : AppColors.cardDarkAlt,
                  foregroundColor: _previewCanvas != _appliedCanvas
                      ? AppColors.scaffoldDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EXPORT BUTTON ──
  Widget _buildExportButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _showExportSheet,
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: const Text('Export Studio'),
            style: FilledButton.styleFrom(
              backgroundColor: _hasEdits
                  ? AppColors.accent
                  : AppColors.cardDarkAlt,
              foregroundColor: _hasEdits
                  ? AppColors.scaffoldDark
                  : AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_hasEdits)
          const Padding(
            padding: EdgeInsets.only(top: AppTheme.spacingXs),
            child: Text(
              'Edited • Ready to export',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
