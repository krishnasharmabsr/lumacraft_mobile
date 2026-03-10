import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';

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

  late String _sourceVideoPath;
  late String _workingVideoPath;

  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  bool _isProcessing = false;
  bool _isPreviewingTrim = false;
  String _processingLabel = '';
  double _processingProgress = -1; // -1 = indeterminate

  double _playbackSpeed = 1.0;
  ExportAspectRatio _aspectRatio = ExportAspectRatio.source;

  VoidCallback? _previewListener;

  bool get _hasEdits => _sourceVideoPath != _workingVideoPath;

  @override
  void initState() {
    super.initState();
    _sourceVideoPath = widget.videoPath;
    _workingVideoPath = widget.videoPath;
    _initializePlayer(_workingVideoPath);
  }

  Future<void> _initializePlayer(String path) async {
    final oldController = _controller;

    final newController = VideoPlayerController.file(File(path));
    await newController.initialize();

    if (mounted) {
      setState(() {
        _controller = newController;
        _trimStart = Duration.zero;
        _trimEnd = newController.value.duration;
        _isPreviewingTrim = false;
        // Reset local ui states that are not yet applied
        _playbackSpeed = 1.0;
        _aspectRatio = ExportAspectRatio.source;
      });
    }

    newController.addListener(() {
      if (mounted) setState(() {});
    });

    newController.play();
    oldController?.dispose();
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

  void _resetEdits() {
    if (!_hasEdits) return;
    setState(() {
      _workingVideoPath = _sourceVideoPath;
    });
    _initializePlayer(_workingVideoPath);
  }

  void _previewTrim() {
    final ctrl = _controller;
    if (ctrl == null) return;

    _removePreviewListener();
    ctrl.seekTo(_trimStart);
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

  Future<void> _applyTrim() async {
    final rangeMs = (_trimEnd - _trimStart).inMilliseconds;
    if (rangeMs < 300) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid trim range. End must be greater than start.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    // If no trim is actually happening:
    if (_trimStart.inMilliseconds <= 100 &&
        _trimEnd >=
            _controller!.value.duration - const Duration(milliseconds: 100)) {
      return; // Nothing to trim
    }

    setState(() {
      _isProcessing = true;
      _processingLabel = 'Trimming...';
      _processingProgress = 0;
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final ext = _workingVideoPath.split('.').last;
      final outputPath = '$cachePath/trimmed_${const Uuid().v4()}.$ext';

      final newPath = await _processor.processTrim(
        inputPath: _workingVideoPath,
        outputPath: outputPath,
        startTime: _trimStart,
        endTime: _trimEnd,
        onProgress: (p) {
          if (mounted) setState(() => _processingProgress = p);
        },
      );

      _workingVideoPath = newPath;
      await _initializePlayer(newPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trim applied')));
      }
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

  Future<void> _applySpeed() async {
    if (_playbackSpeed == 1.0) return;

    setState(() {
      _isProcessing = true;
      _processingLabel = 'Applying Speed...';
      _processingProgress = -1;
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final ext = _workingVideoPath.split('.').last;
      final outputPath = '$cachePath/speed_${const Uuid().v4()}.$ext';

      final newPath = await _processor.processSpeed(
        inputPath: _workingVideoPath,
        outputPath: outputPath,
        speed: _playbackSpeed,
        onProgress: (p) {},
      );

      _workingVideoPath = newPath;
      await _initializePlayer(newPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Speed applied')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Speed error: $e')));
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

  Future<void> _applyCanvas() async {
    if (_aspectRatio == ExportAspectRatio.source) return;

    setState(() {
      _isProcessing = true;
      _processingLabel = 'Applying Canvas...';
      _processingProgress = -1;
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final ext = _workingVideoPath.split('.').last;
      final outputPath = '$cachePath/canvas_${const Uuid().v4()}.$ext';

      // Use the generic scaleFilter builder logic from previous export, with a generic height base like 1080 to maintain quality during intermediate.
      final targetHeight = 1080;
      final targetWidth = (targetHeight * _aspectRatio.ratio!).round();
      final scaleFilter =
          'scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:black';

      final newPath = await _processor.processCanvas(
        inputPath: _workingVideoPath,
        outputPath: outputPath,
        scaleFilter: scaleFilter,
        onProgress: (p) {},
      );

      _workingVideoPath = newPath;
      await _initializePlayer(newPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Canvas applied')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Canvas error: $e')));
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

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportSettingsSheet(
        onExport: (settings) {
          _exportWithSettings(settings);
        },
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
    return "$minutes:$seconds";
  }

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
                            aspectRatio: ctrl.value.aspectRatio,
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
                          _formatDuration(ctrl.value.duration),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          // -- Trim Section --
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingLg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.content_cut_rounded,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                      SizedBox(width: AppTheme.spacingSm),
                                      Text(
                                        'Trim',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  TrimControls(
                                    maxDuration: ctrl.value.duration,
                                    currentStart: _trimStart,
                                    currentEnd: _trimEnd,
                                    onStartChanged: (start) {
                                      setState(() => _trimStart = start);
                                      ctrl.seekTo(start);
                                    },
                                    onEndChanged: (end) {
                                      setState(() => _trimEnd = end);
                                    },
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isProcessing
                                              ? null
                                              : _previewTrim,
                                          icon: const Icon(
                                            Icons.preview,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _isPreviewingTrim
                                                ? 'Previewing...'
                                                : 'Preview Trim',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingMd),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _isProcessing
                                              ? null
                                              : _applyTrim,
                                          icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                          ),
                                          label: const Text('Apply Trim'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),

                          // -- Speed Section --
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingLg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.speed_rounded,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                      SizedBox(width: AppTheme.spacingSm),
                                      Text(
                                        'Speed',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  Row(
                                    children: [0.5, 1.0, 1.5, 2.0].map((speed) {
                                      final isSelected =
                                          _playbackSpeed == speed;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _playbackSpeed = speed,
                                            );
                                            // Optional: apply just playback speed for preview if possible.
                                            // _controller?.setPlaybackSpeed(speed);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.accent
                                                  : AppColors.cardDarkAlt,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusSm,
                                                  ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.accent
                                                    : AppColors.divider,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${speed}x',
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
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed:
                                          _isProcessing || _playbackSpeed == 1.0
                                          ? null
                                          : _applySpeed,
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Apply Speed'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),

                          // -- Canvas Section --
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingLg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.crop_free_rounded,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                      SizedBox(width: AppTheme.spacingSm),
                                      Text(
                                        'Canvas Options',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: ExportAspectRatio.values.map((
                                        ratio,
                                      ) {
                                        final isSelected =
                                            _aspectRatio == ratio;
                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => _aspectRatio = ratio,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 16,
                                            ),
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.accent
                                                  : AppColors.cardDarkAlt,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusSm,
                                                  ),
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
                                      onPressed:
                                          _isProcessing ||
                                              _aspectRatio ==
                                                  ExportAspectRatio.source
                                          ? null
                                          : _applyCanvas,
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Apply Canvas'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingLg),

                          // -- Export button --
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : _showExportSheet,
                              icon: const Icon(
                                Icons.save_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('Export Studio'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _hasEdits
                                    ? AppColors.accent
                                    : AppColors.cardDarkAlt,
                                foregroundColor: _hasEdits
                                    ? AppColors.scaffoldDark
                                    : AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
}
