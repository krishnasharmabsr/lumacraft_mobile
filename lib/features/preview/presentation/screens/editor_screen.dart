import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

import '../../../../core/models/export_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/engine/ffmpeg_processor.dart';
import '../../../../services/io/media_io_service.dart';
import '../../../../services/io/native_video_picker.dart';
import '../../../export/presentation/widgets/export_settings_sheet.dart';
import '../widgets/processing_overlay.dart';
import '../widgets/trim_controls.dart';

enum EditorTool { none, trim, speed, canvas }

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

  // --- Tool Panel state ---
  EditorTool _activeTool = EditorTool.none;

  // --- Speed state (preview vs applied) ---
  double _previewSpeed = 1.0;
  double _appliedSpeed = 1.0;

  // --- Canvas state (preview vs applied) ---
  ExportAspectRatio _previewCanvas = ExportAspectRatio.source;
  ExportAspectRatio _appliedCanvas = ExportAspectRatio.source;

  // --- Audio state ---
  double _volume = 1.0;
  bool _isMuted = false;

  // --- Processing ---
  bool _isProcessing = false;
  bool _isPreviewingTrim = false;

  bool _showOverlay = true;
  bool _showVolumeSlider = false;
  Timer? _overlayTimer;

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
  //  PLAYER INIT WITH FFPROBE DURATION FALLBACK + NORMALIZATION
  // ────────────────────────────────────────────────────────────
  Future<void> _initializePlayer(String path, {bool keepEdits = false}) async {
    final oldController = _controller;

    var newController = VideoPlayerController.file(File(path));
    await newController.initialize();

    Duration resolvedDuration = newController.value.duration;
    String winningSource = 'video_player';

    developer.log(
      'video_player initial duration: ${resolvedDuration.inMilliseconds}ms',
      name: '[DurationProbe]',
    );

    // Fallback chain when video_player reports 0
    if (resolvedDuration.inMilliseconds <= 0) {
      final fallback = await _resolveDurationFallback(path);
      resolvedDuration = fallback.duration;
      winningSource = fallback.source;
    }

    // ── Normalization fallback if duration is still zero ──
    if (resolvedDuration.inMilliseconds <= 0) {
      developer.log(
        'normalization_triggered=yes, all probes failed, attempting normalization',
        name: '[DurationProbe]',
      );

      // Show processing overlay while normalizing
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _processingLabel = 'Normalizing video...';
          _processingProgress = -1;
        });
      }

      final normResult = await _tryNormalizeVideo(path);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = '';
        });
      }

      if (normResult != null) {
        // Use the PROBED duration as source-of-truth (never trust controller blindly)
        newController.dispose();
        newController = VideoPlayerController.file(File(normResult.path));
        await newController.initialize();
        // Take the probed duration — controller may still report 0
        resolvedDuration = normResult.duration;
        winningSource = 'normalized_probe_${normResult.mode}';
        _workingVideoPath = normResult.path;
        developer.log(
          'normalization_success: mode=${normResult.mode}, probed_duration=${normResult.duration.inMilliseconds}ms, controller_duration=${newController.value.duration.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
      } else {
        developer.log(
          'normalization_failed: both remux and reencode unsuccessful',
          name: '[DurationProbe]',
        );
      }
    } else {
      developer.log('normalization_triggered=no', name: '[DurationProbe]');
    }

    developer.log(
      'FINAL duration resolved via $winningSource: ${resolvedDuration.inMilliseconds}ms',
      name: '[DurationProbe]',
    );

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
      if (!mounted) return;
      if (_videoDuration.inMilliseconds <= 0 &&
          newController.value.duration.inMilliseconds > 0) {
        developer.log(
          'video_player late update: ${newController.value.duration.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
        _videoDuration = newController.value.duration;
        _isTimelineInvalid = false;
        if (_trimEnd.inMilliseconds <= 0) {
          _trimEnd = _videoDuration;
        }
      }
      setState(() {});
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

  /// Try remux first, then re-encode. Returns record with path, probed duration, and mode; or null.
  Future<({String path, Duration duration, String mode})?> _tryNormalizeVideo(
    String inputPath,
  ) async {
    final cacheDir = File(inputPath).parent;
    final uuid = const Uuid().v4().substring(0, 8);
    // Clean stale normalization files
    try {
      cacheDir
          .listSync()
          .whereType<File>()
          .where((f) {
            final name = f.uri.pathSegments.last;
            return name.startsWith('norm_') && name.endsWith('.mp4');
          })
          .forEach((f) {
            try {
              f.deleteSync();
            } catch (_) {}
          });
    } catch (_) {}

    final remuxPath = '${cacheDir.path}/norm_remux_$uuid.mp4';
    final reencPath = '${cacheDir.path}/norm_reenc_$uuid.mp4';

    // 1) Remux attempt
    try {
      developer.log('normalization_attempt=remux', name: '[DurationProbe]');
      final session = await FFmpegKit.execute(
        '-y -fflags +genpts -i "$inputPath" -map 0:v:0 -map 0:a? -c copy -movflags +faststart "$remuxPath"',
      );
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && File(remuxPath).existsSync()) {
        final dur = await _quickProbeDuration(remuxPath);
        if (dur.inMilliseconds > 0) {
          developer.log(
            'normalization_mode=remux, success, probed_duration=${dur.inMilliseconds}ms',
            name: '[DurationProbe]',
          );
          return (path: remuxPath, duration: dur, mode: 'remux');
        }
      }
      developer.log(
        'remux produced 0-duration or failed, trying re-encode',
        name: '[DurationProbe]',
      );
    } catch (e) {
      developer.log('remux error: $e', name: '[DurationProbe]');
    }

    // 2) Re-encode attempt
    try {
      developer.log('normalization_attempt=reencode', name: '[DurationProbe]');
      final session = await FFmpegKit.execute(
        '-y -fflags +genpts -i "$inputPath" -map 0:v:0 -map 0:a? -c:v libx264 -preset ultrafast -crf 23 -c:a aac -movflags +faststart "$reencPath"',
      );
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && File(reencPath).existsSync()) {
        final dur = await _quickProbeDuration(reencPath);
        if (dur.inMilliseconds > 0) {
          developer.log(
            'normalization_mode=reencode, success, probed_duration=${dur.inMilliseconds}ms',
            name: '[DurationProbe]',
          );
          return (path: reencPath, duration: dur, mode: 'reencode');
        }
      }
      developer.log(
        'reencode also failed to produce valid duration',
        name: '[DurationProbe]',
      );
    } catch (e) {
      developer.log('reencode error: $e', name: '[DurationProbe]');
    }

    developer.log(
      'normalization_failed: both remux and reencode unsuccessful',
      name: '[DurationProbe]',
    );
    return null;
  }

  /// Quick FFprobe duration check on a file.
  Future<Duration> _quickProbeDuration(String path) async {
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final media = info.getMediaInformation();
      if (media != null) {
        final d = _parseDurationString(media.getDuration());
        if (d != null) return d;
      }
    } catch (_) {}
    return Duration.zero;
  }

  Duration? _parseDurationString(String? durationStr) {
    if (durationStr == null || durationStr.trim().isEmpty) return null;
    durationStr = durationStr.trim().replaceAll(',', '.');

    // Try decimal seconds (e.g., "21.64")
    final secs = double.tryParse(durationStr);
    if (secs != null && secs > 0) {
      return Duration(milliseconds: (secs * 1000).round());
    }

    // Try sexagesimal HH:MM:SS.mmm format (e.g., "00:00:21.64")
    final parts = durationStr.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final sParts = parts[2].split('.');
      final s = int.tryParse(sParts[0]) ?? 0;
      final ms = sParts.length > 1
          ? int.tryParse(sParts[1].padRight(3, '0').substring(0, 3)) ?? 0
          : 0;

      final duration = Duration(
        hours: h,
        minutes: m,
        seconds: s,
        milliseconds: ms,
      );
      if (duration.inMilliseconds > 0) return duration;
    }

    return null;
  }

  /// Multi-source fallback: 1) FFprobe field, 2) FFprobe command, 3) Android MMR, 4) Android MediaExtractor
  Future<({Duration duration, String source})> _resolveDurationFallback(
    String path,
  ) async {
    // 1. Try format-level / stream-level duration from FFprobeKit
    try {
      final info = await FFprobeKit.getMediaInformation(path);
      final media = info.getMediaInformation();
      if (media != null) {
        final parsedFormat = _parseDurationString(media.getDuration());
        if (parsedFormat != null) {
          developer.log(
            'ffprobe_field format: ${parsedFormat.inMilliseconds}ms',
            name: '[DurationProbe]',
          );
          return (duration: parsedFormat, source: 'ffprobe_field');
        }

        final streams = media.getStreams();
        if (streams.isNotEmpty) {
          for (final stream in streams) {
            if (stream.getType() == 'video') {
              final props = stream.getAllProperties();
              if (props != null) {
                final streamDur =
                    props['duration'] ?? props['tags']?['DURATION'];
                final parsedStream = _parseDurationString(
                  streamDur?.toString(),
                );
                if (parsedStream != null) {
                  developer.log(
                    'ffprobe_field stream: ${parsedStream.inMilliseconds}ms',
                    name: '[DurationProbe]',
                  );
                  return (duration: parsedStream, source: 'ffprobe_field');
                }
              }
            }
          }
        }
      }
      developer.log(
        'ffprobe_field: no duration found',
        name: '[DurationProbe]',
      );
    } catch (e) {
      developer.log('ffprobe_field error: $e', name: '[DurationProbe]');
    }

    // 2. Try raw FFprobe execution
    try {
      final session = await FFprobeKit.execute(
        '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$path"',
      );
      final output = await session.getOutput();
      final logsStr = await session.getAllLogsAsString();

      final parsedOut = _parseDurationString(output?.trim());
      if (parsedOut != null) {
        developer.log(
          'ffprobe_output: ${parsedOut.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
        return (duration: parsedOut, source: 'ffprobe_log');
      }

      final parsedLogs = _parseDurationString(logsStr?.trim());
      if (parsedLogs != null) {
        developer.log(
          'ffprobe_logs: ${parsedLogs.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
        return (duration: parsedLogs, source: 'ffprobe_log');
      }

      developer.log('ffprobe_raw: no duration found', name: '[DurationProbe]');
    } catch (e) {
      developer.log('ffprobe_raw error: $e', name: '[DurationProbe]');
    }

    // 2b. Try FFprobe full output regex
    try {
      final session = await FFprobeKit.execute('-i "$path"');
      final output = await session.getOutput();
      final logsStr = await session.getAllLogsAsString();

      final combined = '${output ?? ""} ${logsStr ?? ""}';

      final match = RegExp(
        r'Duration:\s+(\d{2}:\d{2}:\d{2}\.\d+)',
      ).firstMatch(combined);
      if (match != null) {
        final parsedRegex = _parseDurationString(match.group(1));
        if (parsedRegex != null) {
          developer.log(
            'ffprobe_regex: ${parsedRegex.inMilliseconds}ms',
            name: '[DurationProbe]',
          );
          return (duration: parsedRegex, source: 'ffprobe_log_regex');
        }
      }
      developer.log(
        'ffprobe_regex: no duration found',
        name: '[DurationProbe]',
      );
    } catch (e) {
      developer.log('ffprobe_regex error: $e', name: '[DurationProbe]');
    }

    // 3. Fallback to Native Android MMR
    try {
      final nativeDurStr = await NativeVideoPicker.getMediaDuration(path);
      if (nativeDurStr != null) {
        final millis = int.tryParse(nativeDurStr);
        if (millis != null && millis > 0) {
          developer.log('mmr: ${millis}ms', name: '[DurationProbe]');
          return (duration: Duration(milliseconds: millis), source: 'mmr');
        }
      }
      developer.log('mmr: no duration found', name: '[DurationProbe]');
    } catch (e) {
      developer.log('mmr error: $e', name: '[DurationProbe]');
    }

    // 4. Fallback to Native Android MediaExtractor
    try {
      final extractorDurStr = await NativeVideoPicker.getMediaDurationExtractor(
        path,
      );
      if (extractorDurStr != null) {
        final millis = int.tryParse(extractorDurStr);
        if (millis != null && millis > 0) {
          developer.log(
            'media_extractor: ${millis}ms',
            name: '[DurationProbe]',
          );
          return (
            duration: Duration(milliseconds: millis),
            source: 'media_extractor',
          );
        }
      }
      developer.log(
        'media_extractor: no duration found',
        name: '[DurationProbe]',
      );
    } catch (e) {
      developer.log('media_extractor error: $e', name: '[DurationProbe]');
    }

    developer.log('all_probes_failed', name: '[DurationProbe]');
    return (duration: Duration.zero, source: 'none');
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _removePreviewListener();
    _controller?.dispose();
    super.dispose();
  }

  void _resetOverlayTimer() {
    _overlayTimer?.cancel();
    if (_controller?.value.isPlaying == true) {
      _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  void _toggleOverlay() {
    if (_isProcessing) return;
    setState(() {
      _showOverlay = !_showOverlay;
    });
    if (_showOverlay) _resetOverlayTimer();
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
  //  AUDIO CONTROLS
  // ────────────────────────────────────────────────────────────
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _controller?.setVolume(_isMuted ? 0.0 : _volume);
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      if (value > 0) _isMuted = false;
    });
    _controller?.setVolume(_isMuted ? 0.0 : _volume);
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
      appBar:
          _isProcessing ||
              MediaQuery.of(context).orientation == Orientation.landscape
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
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          return Stack(
            children: [
              SafeArea(
                child: Flex(
                  direction: isLandscape ? Axis.horizontal : Axis.vertical,
                  children: [
                    if (isReady)
                      Flexible(
                        flex: isLandscape ? 5 : 3,
                        child: GestureDetector(
                          onTap: _toggleOverlay,
                          child: Container(
                            color: AppColors.playerBg,
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AspectRatio(
                                  aspectRatio:
                                      _previewCanvas ==
                                              ExportAspectRatio.source ||
                                          _previewCanvas.ratio == null
                                      ? ctrl.value.aspectRatio
                                      : _previewCanvas.ratio!,
                                  child: VideoPlayer(ctrl),
                                ),
                                if (_showOverlay && !_isProcessing)
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
                                                    icon: const Icon(
                                                      Icons.replay_10,
                                                    ),
                                                    iconSize: 36,
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      _resetOverlayTimer();
                                                      final pos =
                                                          ctrl.value.position -
                                                          const Duration(
                                                            seconds: 10,
                                                          );
                                                      ctrl.seekTo(
                                                        pos < Duration.zero
                                                            ? Duration.zero
                                                            : pos,
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 16),
                                                  IconButton(
                                                    iconSize: 56,
                                                    color: Colors.white,
                                                    icon: Icon(
                                                      ctrl.value.isPlaying
                                                          ? Icons
                                                                .pause_circle_filled
                                                          : Icons
                                                                .play_circle_filled,
                                                    ),
                                                    onPressed: () {
                                                      _removePreviewListener();
                                                      setState(() {
                                                        if (ctrl
                                                            .value
                                                            .isPlaying) {
                                                          ctrl.pause();
                                                          _overlayTimer
                                                              ?.cancel();
                                                        } else {
                                                          ctrl.play();
                                                          _resetOverlayTimer();
                                                        }
                                                      });
                                                    },
                                                  ),
                                                  const SizedBox(width: 16),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.forward_10,
                                                    ),
                                                    iconSize: 36,
                                                    color: Colors.white,
                                                    onPressed: () {
                                                      _resetOverlayTimer();
                                                      final pos =
                                                          ctrl.value.position +
                                                          const Duration(
                                                            seconds: 10,
                                                          );
                                                      ctrl.seekTo(
                                                        pos > _videoDuration
                                                            ? _videoDuration
                                                            : pos,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        AppTheme.spacingMd,
                                                    vertical:
                                                        AppTheme.spacingSm,
                                                  ),
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black87,
                                                  ],
                                                ),
                                              ),
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.bottomLeft,
                                                children: [
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () {
                                                              setState(() {
                                                                _showVolumeSlider =
                                                                    !_showVolumeSlider;
                                                              });
                                                              _resetOverlayTimer();
                                                            },
                                                            onLongPress: () {
                                                              _toggleMute();
                                                              _resetOverlayTimer();
                                                            },
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    8.0,
                                                                  ),
                                                              child: Icon(
                                                                _isMuted ||
                                                                        _volume ==
                                                                            0
                                                                    ? Icons
                                                                          .volume_off
                                                                    : Icons
                                                                          .volume_up,
                                                                color: Colors
                                                                    .white,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            '${_formatDuration(ctrl.value.position)} / ${_formatDuration(_videoDuration)}',
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors.white,
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
                                                        controller: ctrl,
                                                        duration:
                                                            _videoDuration,
                                                        trimStart: _trimStart,
                                                        trimEnd: _trimEnd,
                                                      ),
                                                    ],
                                                  ),
                                                  if (_showVolumeSlider)
                                                    Positioned(
                                                      left: 8,
                                                      bottom: 64,
                                                      child: Container(
                                                        height: 140,
                                                        width: 40,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black87,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Expanded(
                                                              child: RotatedBox(
                                                                quarterTurns: 3,
                                                                child: SliderTheme(
                                                                  data: SliderTheme.of(context).copyWith(
                                                                    trackHeight:
                                                                        2,
                                                                    thumbShape:
                                                                        const RoundSliderThumbShape(
                                                                          enabledThumbRadius:
                                                                              6,
                                                                        ),
                                                                    overlayShape:
                                                                        const RoundSliderOverlayShape(
                                                                          overlayRadius:
                                                                              10,
                                                                        ),
                                                                  ),
                                                                  child: Slider(
                                                                    value:
                                                                        _volume,
                                                                    min: 0.0,
                                                                    max: 1.0,
                                                                    activeColor:
                                                                        AppColors
                                                                            .accent,
                                                                    inactiveColor:
                                                                        Colors
                                                                            .white30,
                                                                    onChangeStart:
                                                                        (
                                                                          _,
                                                                        ) => _overlayTimer
                                                                            ?.cancel(),
                                                                    onChangeEnd:
                                                                        (_) =>
                                                                            _resetOverlayTimer(),
                                                                    onChanged:
                                                                        (val) {
                                                                          _setVolume(
                                                                            val,
                                                                          );
                                                                        },
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
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

                    // ── TOOLBAR ICONS ──
                    if (isReady && !_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingSm,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.divider, width: 1),
                            bottom: BorderSide(
                              color: AppColors.divider,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ToolIconButton(
                              icon: Icons.cut,
                              label: 'Trim',
                              isActive: _activeTool == EditorTool.trim,
                              onPressed: () => setState(
                                () =>
                                    _activeTool = _activeTool == EditorTool.trim
                                    ? EditorTool.none
                                    : EditorTool.trim,
                              ),
                            ),
                            _ToolIconButton(
                              icon: Icons.speed,
                              label: 'Speed',
                              isActive: _activeTool == EditorTool.speed,
                              onPressed: () => setState(
                                () => _activeTool =
                                    _activeTool == EditorTool.speed
                                    ? EditorTool.none
                                    : EditorTool.speed,
                              ),
                            ),
                            _ToolIconButton(
                              icon: Icons.crop,
                              label: 'Canvas',
                              isActive: _activeTool == EditorTool.canvas,
                              onPressed: () => setState(
                                () => _activeTool =
                                    _activeTool == EditorTool.canvas
                                    ? EditorTool.none
                                    : EditorTool.canvas,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── TOOL PANEL OR SPACER ──
                    if (isReady &&
                        !_isProcessing &&
                        _activeTool != EditorTool.none)
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppTheme.spacingMd),
                          child: Column(
                            children: [
                              _buildActiveToolPanel(ctrl),
                              const SizedBox(height: AppTheme.spacingLg),
                              _buildExportButton(),
                              const SizedBox(height: AppTheme.spacingLg),
                            ],
                          ),
                        ),
                      )
                    else if (isReady &&
                        !_isProcessing &&
                        _activeTool == EditorTool.none)
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildExportButton(),
                            const SizedBox(height: AppTheme.spacingLg),
                          ],
                        ),
                      ),

                    if (_isProcessing)
                      const Expanded(
                        flex: 4,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
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
          );
        },
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
  Widget _buildSpeedCard(VideoPlayerController ctrl) {
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

  // ────────────────────────────────────────────────────────────
  //  ACTIVE TOOL PANEL ROUTER
  // ────────────────────────────────────────────────────────────
  Widget _buildActiveToolPanel(VideoPlayerController ctrl) {
    switch (_activeTool) {
      case EditorTool.trim:
        return _buildTrimCard(ctrl);
      case EditorTool.speed:
        return _buildSpeedCard(ctrl);
      case EditorTool.canvas:
        return _buildCanvasCard();
      case EditorTool.none:
        return const SizedBox.shrink();
    }
  }
}

// ────────────────────────────────────────────────────────────
//  UI COMPONENT: TOOL ICON BUTTON
// ────────────────────────────────────────────────────────────
class _ToolIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _ToolIconButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: isActive ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  UI COMPONENT: PLAYBACK TIMELINE WITH TRIM HIGHLIGHT
// ────────────────────────────────────────────────────────────
class PlaybackTimeline extends StatelessWidget {
  final VideoPlayerController controller;
  final Duration duration;
  final Duration trimStart;
  final Duration trimEnd;

  const PlaybackTimeline({
    super.key,
    required this.controller,
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (duration.inMilliseconds == 0) return const SizedBox(height: 16);

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
            ? controller.value.position.inMilliseconds / totalMillis
            : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final double percent =
                (details.localPosition.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                );
            controller.seekTo(
              Duration(milliseconds: (percent * totalMillis).round()),
            );
          },
          onTapDown: (details) {
            final double percent =
                (details.localPosition.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                );
            controller.seekTo(
              Duration(milliseconds: (percent * totalMillis).round()),
            );
          },
          child: Container(
            height: 24,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base track
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Trim region highlight
                Positioned(
                  left: startRatio * constraints.maxWidth,
                  width:
                      (endRatio - startRatio).clamp(0.0, 1.0) *
                      constraints.maxWidth,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Playhead
                Positioned(
                  left: (positionRatio * constraints.maxWidth) - 6,
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
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
