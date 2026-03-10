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

  String _currentVideoPath = '';
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  bool _isProcessing = false;
  bool _isPreviewingTrim = false;
  bool _hasEdits = false;
  String _processingLabel = '';
  VoidCallback? _previewListener;

  @override
  void initState() {
    super.initState();
    _currentVideoPath = widget.videoPath;
    _initializePlayer(_currentVideoPath);
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

  Future<void> _processTrim() async {
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

    setState(() {
      _isProcessing = true;
      _processingLabel = 'Trimming...';
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final ext = _currentVideoPath.split('.').last;
      final outputPath = '$cachePath/trimmed_${const Uuid().v4()}.$ext';

      final trimmedPath = await _processor.processTrim(
        inputPath: _currentVideoPath,
        outputPath: outputPath,
        startTime: _trimStart,
        endTime: _trimEnd,
      );

      _currentVideoPath = trimmedPath;
      _hasEdits = true;
      await _initializePlayer(trimmedPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trim successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Trim error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportSettingsSheet(
        hasEdits: _hasEdits,
        onExport: (settings, saveCopy) {
          if (saveCopy) {
            _exportWithSettings(settings, saveCopy: true);
          } else {
            _exportWithSettings(settings, saveCopy: false);
          }
        },
      ),
    );
  }

  Future<void> _exportWithSettings(
    ExportSettings settings, {
    bool saveCopy = false,
  }) async {
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Exporting ${settings.resolution.label}...';
    });

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final outputPath = '$cachePath/export_${const Uuid().v4()}.mp4';

      // If saveCopy (no edits), export from original with settings
      // If has edits, export trimmed video with settings
      await _processor.processExport(
        inputPath: _currentVideoPath,
        outputPath: outputPath,
        settings: settings,
      );

      final success = await _ioService.saveVideoToGallery(outputPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Exported ${settings.resolution.label} to gallery!'
                  : 'Export failed.',
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
        setState(() => _isProcessing = false);
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
      appBar: AppBar(
        title: const Text('LumaCraft Editor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    _processingLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // --- Hero video preview ---
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
                            // Tap to play/pause overlay
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
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
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),

                  // --- Playback position bar ---
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
                            onPressed: () {
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

                  // --- Controls section ---
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
                            // -- Trim card --
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingLg,
                                ),
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
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingMd),

                            // -- Action buttons --
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _previewTrim,
                                    icon: const Icon(Icons.preview, size: 18),
                                    label: Text(
                                      _isPreviewingTrim
                                          ? 'Previewing...'
                                          : 'Preview',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingMd),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _processTrim,
                                    icon: const Icon(
                                      Icons.content_cut,
                                      size: 18,
                                    ),
                                    label: const Text('Process Trim'),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppTheme.spacingMd),

                            // -- Export button (always available via sheet) --
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _showExportSheet,
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
                                padding: EdgeInsets.only(
                                  top: AppTheme.spacingXs,
                                ),
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
    );
  }
}
