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
  late String _playbackVideoPath;

  // --- Timeline ---
  Duration _videoDuration = Duration.zero;
  bool _isTimelineInvalid = false;

  // --- Playback ---
  String _playbackSourceKind = 'working';

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
  bool _isScrubbing = false;
  bool _seekInProgress = false;
  ({Duration target, String source, bool? resumePlayback})? _queuedSeekRequest;
  Duration? _pendingScrubTarget;
  bool _resumePlaybackAfterScrub = false;
  Timer? _overlayTimer;

  String _processingLabel = '';
  double _processingProgress = -1;

  VoidCallback? _previewListener;
  VoidCallback? _controllerListener;

  bool get _hasEdits {
    if (!_isUsableDuration(_videoDuration)) return false;
    final isTrimmed =
        _trimStart.inMilliseconds > 100 ||
        _trimEnd < _videoDuration - const Duration(milliseconds: 100);
    return isTrimmed ||
        _appliedSpeed != 1.0 ||
        _appliedCanvas != ExportAspectRatio.source;
  }

  bool _isUsableDuration(Duration d) => d.inMilliseconds >= 1000;

  @override
  void initState() {
    super.initState();
    _workingVideoPath = widget.videoPath;
    _playbackVideoPath = widget.videoPath;
    _initializePlayer(_workingVideoPath);
  }

  // ────────────────────────────────────────────────────────────
  //  PLAYER INIT WITH FFPROBE DURATION FALLBACK + NORMALIZATION
  // ────────────────────────────────────────────────────────────
  Future<void> _initializePlayer(String path, {bool keepEdits = false}) async {
    final oldController = _controller;
    _removePreviewListener();

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _processingLabel = 'Preparing playback...';
        _processingProgress = -1;
      });
    }

    final playbackSource = await _preparePlaybackSource(path);
    path = playbackSource.path;
    _playbackVideoPath = path;
    _playbackSourceKind = playbackSource.kind;

    var newController = VideoPlayerController.file(File(path));
    await newController.initialize();

    Duration resolvedDuration = newController.value.duration;
    String winningSource = 'video_player';

    developer.log(
      'video_player initial duration: ${resolvedDuration.inMilliseconds}ms',
      name: '[DurationProbe]',
    );

    // Fallback chain when video_player reports unusable duration
    if (!_isUsableDuration(resolvedDuration)) {
      final fallback = await _resolveDurationFallback(path);
      resolvedDuration = fallback.duration;
      winningSource = fallback.source;
    }

    // ── Normalization fallback if duration is still unusable ──
    if (playbackSource.kind == '__legacy__' &&
        !_isUsableDuration(resolvedDuration)) {
      developer.log(
        'normalization_triggered=yes, all probes failed or returned tiny duration, attempting normalization',
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

      final normResult = null;

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = '';
        });
      }

      if (normResult != null && _isUsableDuration(normResult.duration)) {
        // Use the PROBED duration as source-of-truth (never trust controller blindly)
        newController.dispose();
        newController = VideoPlayerController.file(File(normResult.path));
        await newController.initialize();
        // Take the probed duration — controller may still report 0
        resolvedDuration = normResult.duration;
        winningSource = 'normalized_probe_${normResult.mode}';
        _workingVideoPath = normResult.path; // Update working path!
        path = _workingVideoPath;
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
      developer.log(
        'normalization_triggered=${playbackSource.kind != 'working'}, kind=${playbackSource.kind}',
        name: '[DurationProbe]',
      );
    }

    if (!_isUsableDuration(resolvedDuration) &&
        _isUsableDuration(playbackSource.duration)) {
      resolvedDuration = playbackSource.duration;
      winningSource = playbackSource.durationSource;
    }

    developer.log(
      'FINAL working duration resolved via $winningSource: ${resolvedDuration.inMilliseconds}ms',
      name: '[DurationProbe]',
    );

    // Ensure we have a strictly usable absolute length
    if (resolvedDuration.inMilliseconds < 1000) {
      resolvedDuration = const Duration(milliseconds: 1000);
    }
    _videoDuration = resolvedDuration;

    // ── Pre-Generate Seek/Preview Proxy ──
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _processingLabel = 'Optimizing playback...';
        _processingProgress = -1;
      });
    }

    // No proxy generation: UI seek math stays on the active playback source.

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _processingLabel = '';
      });
    }

    final activeCtrl = newController;
    developer.log(
      'active playback source=$_playbackVideoPath, resolvedMs=${_videoDuration.inMilliseconds}, kind=$_playbackSourceKind',
      name: '[DurationProbe]',
    );

    final timelineInvalid = !_isUsableDuration(_videoDuration);

    if (mounted) {
      setState(() {
        _controller = activeCtrl;
        _isTimelineInvalid = timelineInvalid;
        _trimStart = Duration.zero;
        _trimEnd = _videoDuration;
        _isPreviewingTrim = false;
        if (!keepEdits) {
          _previewSpeed = 1.0;
          _appliedSpeed = 1.0;
          _previewCanvas = ExportAspectRatio.source;
          _appliedCanvas = ExportAspectRatio.source;
        } else {
          if (_trimStart > _videoDuration) _trimStart = Duration.zero;
          if (_trimEnd > _videoDuration) _trimEnd = _videoDuration;
        }
      });
    }

    _detachControllerListener(oldController);
    _attachControllerListener(activeCtrl);
    await activeCtrl.setVolume(_isMuted ? 0.0 : _volume);

    if (!timelineInvalid) {
      activeCtrl.play();
      _resetOverlayTimer();
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
            return (name.startsWith('playback_') || name.startsWith('norm_')) &&
                name.endsWith('.mp4');
          })
          .forEach((f) {
            try {
              f.deleteSync();
            } catch (_) {}
          });
    } catch (_) {}

    final remuxPath = '${cacheDir.path}/playback_remux_$uuid.mp4';
    final reencPath = '${cacheDir.path}/playback_reenc_$uuid.mp4';

    // 1) Remux attempt
    try {
      developer.log('normalization_attempt=remux', name: '[DurationProbe]');
      final session = await FFmpegKit.execute(
        '-y -fflags +genpts -i "$inputPath" -map 0:v:0 -map 0:a? -c copy -movflags +faststart "$remuxPath"',
      );
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && File(remuxPath).existsSync()) {
        final dur = await _quickProbeDuration(remuxPath);
        if (_isUsableDuration(dur)) {
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
        if (_isUsableDuration(dur)) {
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
      final duration = Duration(milliseconds: (secs * 1000).round());
      if (_isUsableDuration(duration)) return duration;
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
      if (_isUsableDuration(duration)) return duration;
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
        if (parsedFormat != null && _isUsableDuration(parsedFormat)) {
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
                if (parsedStream != null && _isUsableDuration(parsedStream)) {
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
      if (parsedOut != null && _isUsableDuration(parsedOut)) {
        developer.log(
          'ffprobe_output: ${parsedOut.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
        return (duration: parsedOut, source: 'ffprobe_log');
      }

      final parsedLogs = _parseDurationString(logsStr?.trim());
      if (parsedLogs != null && _isUsableDuration(parsedLogs)) {
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
        if (parsedRegex != null && _isUsableDuration(parsedRegex)) {
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
        if (millis != null) {
          final dur = Duration(milliseconds: millis);
          if (_isUsableDuration(dur)) {
            developer.log('mmr: ${millis}ms', name: '[DurationProbe]');
            return (duration: dur, source: 'mmr');
          }
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
        if (millis != null) {
          final dur = Duration(milliseconds: millis);
          if (_isUsableDuration(dur)) {
            developer.log(
              'media_extractor: ${millis}ms',
              name: '[DurationProbe]',
            );
            return (duration: dur, source: 'media_extractor');
          }
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

  Future<({String path, Duration duration, String durationSource, String kind})>
  _preparePlaybackSource(String inputPath) async {
    var resolvedDuration = await _quickProbeDuration(inputPath);
    var durationSource = _isUsableDuration(resolvedDuration)
        ? 'ffprobe_field'
        : 'none';
    var playbackPath = inputPath;
    var playbackKind = 'working';

    if (!_isUsableDuration(resolvedDuration)) {
      final fallback = await _resolveDurationFallback(inputPath);
      resolvedDuration = fallback.duration;
      durationSource = fallback.source;
    }

    final shouldNormalize = _shouldNormalizePlaybackSource(
      inputPath,
      duration: resolvedDuration,
      durationSource: durationSource,
    );

    developer.log(
      'prepare path=$inputPath, durationMs=${resolvedDuration.inMilliseconds}, durationSource=$durationSource, normalize=$shouldNormalize',
      name: '[DurationProbe]',
    );

    if (shouldNormalize) {
      final normResult = await _tryNormalizeVideo(inputPath);
      if (normResult != null && _isUsableDuration(normResult.duration)) {
        playbackPath = normResult.path;
        resolvedDuration = normResult.duration;
        durationSource = 'normalized_probe_${normResult.mode}';
        playbackKind = normResult.mode;
      }
    }

    return (
      path: playbackPath,
      duration: resolvedDuration,
      durationSource: durationSource,
      kind: playbackKind,
    );
  }

  bool _shouldNormalizePlaybackSource(
    String path, {
    required Duration duration,
    required String durationSource,
  }) {
    if (_isEditorManagedPlaybackSource(path)) {
      return !_isUsableDuration(duration);
    }

    final lowerPath = path.toLowerCase();
    return !lowerPath.endsWith('.mp4') ||
        !_isUsableDuration(duration) ||
        durationSource != 'video_player' ||
        lowerPath.contains('working_');
  }

  bool _isEditorManagedPlaybackSource(String path) {
    final name = File(path).uri.pathSegments.last.toLowerCase();
    return name.startsWith('trim_') ||
        name.startsWith('playback_remux_') ||
        name.startsWith('playback_reenc_') ||
        name.startsWith('norm_') ||
        name.startsWith('export_');
  }

  void _attachControllerListener(VideoPlayerController controller) {
    _controllerListener = () {
      if (!mounted) return;

      final reportedDuration = controller.value.duration;
      if (_isUsableDuration(reportedDuration) &&
          reportedDuration.inMilliseconds > _videoDuration.inMilliseconds) {
        developer.log(
          'controller duration promotion: ${reportedDuration.inMilliseconds}ms',
          name: '[DurationProbe]',
        );
        _videoDuration = reportedDuration;
        if (_trimEnd > _videoDuration) {
          _trimEnd = _videoDuration;
        }
        _isTimelineInvalid = false;
      }

      setState(() {});
    };
    controller.addListener(_controllerListener!);
  }

  void _detachControllerListener(VideoPlayerController? controller) {
    if (_controllerListener != null && controller != null) {
      controller.removeListener(_controllerListener!);
    }
    _controllerListener = null;
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _removePreviewListener();
    _detachControllerListener(_controller);
    _controller?.dispose();
    super.dispose();
  }

  Duration _clampToTimeline(Duration target) {
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (_isUsableDuration(_videoDuration) && clamped > _videoDuration) {
      clamped = _videoDuration;
    }
    return clamped;
  }

  Future<bool> _waitForSeekVerification(
    VideoPlayerController controller,
    Duration target,
  ) async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      final diff =
          (controller.value.position.inMilliseconds - target.inMilliseconds)
              .abs();
      if (diff <= 200) {
        return true;
      }
    }
    return false;
  }

  Duration _nearTargetFallback(Duration target) {
    if (target <= const Duration(milliseconds: 250)) {
      return const Duration(milliseconds: 250);
    }
    final fallback = target - const Duration(milliseconds: 250);
    return _clampToTimeline(fallback);
  }

  Future<bool> _hardReinitializeSeek(
    Duration target, {
    required bool resumePlayback,
  }) async {
    final oldController = _controller;
    if (_playbackVideoPath.isEmpty) return false;

    try {
      final newController = VideoPlayerController.file(
        File(_playbackVideoPath),
      );
      await newController.initialize();
      await newController.setVolume(_isMuted ? 0.0 : _volume);
      await newController.setPlaybackSpeed(_previewSpeed);
      await newController.seekTo(target);

      final verified = await _waitForSeekVerification(newController, target);
      _detachControllerListener(oldController);
      _attachControllerListener(newController);

      if (mounted) {
        setState(() {
          _controller = newController;
        });
      } else {
        _controller = newController;
      }

      await oldController?.dispose();

      if (verified && resumePlayback) {
        await newController.play();
        _resetOverlayTimer();
      }
      return verified;
    } catch (e) {
      developer.log('hard_reinit_error: $e', name: '[SeekProbe]');
      return false;
    }
  }

  Future<bool> _runVerifiedSeek(
    Duration target, {
    required String source,
    bool? resumePlayback,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;

    final clampedTarget = _clampToTimeline(target);
    final wasPlaying = controller.value.isPlaying;
    final shouldResume = resumePlayback ?? wasPlaying;

    await controller.pause();
    await controller.seekTo(clampedTarget);

    var success = await _waitForSeekVerification(controller, clampedTarget);
    if (!success) {
      final fallbackTarget = _nearTargetFallback(clampedTarget);
      await controller.seekTo(fallbackTarget);
      success = await _waitForSeekVerification(controller, fallbackTarget);
    }

    if (!success) {
      success = await _hardReinitializeSeek(
        clampedTarget,
        resumePlayback: shouldResume,
      );
    } else if (shouldResume && _controller != null) {
      await _controller!.play();
      _resetOverlayTimer();
    }

    final finalPosition = _controller?.value.position ?? Duration.zero;
    developer.log(
      'source=$source, requestedMs=${target.inMilliseconds}, clampedMs=${clampedTarget.inMilliseconds}, finalMs=${finalPosition.inMilliseconds}, ${success ? 'success' : 'fail'}',
      name: '[SeekProbe]',
    );

    if (mounted) {
      setState(() {});
    }
    return success;
  }

  Future<void> _seekTo(
    Duration target, {
    String source = '',
    bool? resumePlayback,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final request = (
      target: _clampToTimeline(target),
      source: source,
      resumePlayback: resumePlayback,
    );

    if (_seekInProgress) {
      _queuedSeekRequest = request;
      return;
    }

    _seekInProgress = true;
    try {
      var nextRequest = request;
      while (true) {
        await _runVerifiedSeek(
          nextRequest.target,
          source: nextRequest.source,
          resumePlayback: nextRequest.resumePlayback,
        );

        final queued = _queuedSeekRequest;
        _queuedSeekRequest = null;
        if (queued == null) break;
        nextRequest = queued;
      }
    } finally {
      _seekInProgress = false;
    }
  }

  void _resetOverlayTimer() {
    _overlayTimer?.cancel();
    if (_isScrubbing) return;
    if (_controller?.value.isPlaying == true) {
      _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _controller?.value.isPlaying == true && !_isScrubbing) {
          setState(() => _showOverlay = false);
        }
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
    unawaited(
      _seekTo(Duration.zero, source: 'reset_edits', resumePlayback: false),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  AUDIO CONTROLS
  // ────────────────────────────────────────────────────────────
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    unawaited(_applyVolume());
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value.clamp(0.0, 1.0).toDouble();
      if (value > 0) _isMuted = false;
    });
    unawaited(_applyVolume());
  }

  Future<void> _applyVolume() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final target = (_isMuted ? 0.0 : _volume).clamp(0.0, 1.0).toDouble();
    try {
      await ctrl.setVolume(target);
    } catch (e) {
      developer.log('volume_apply_error: $e', name: '[AudioProbe]');
    }
  }

  void _setVolumeFromVerticalDrag({
    required double localDy,
    required double trackHeight,
  }) {
    final safeHeight = trackHeight <= 0 ? 1.0 : trackHeight;
    final next = (1 - (localDy / safeHeight)).clamp(0.0, 1.0).toDouble();
    _setVolume(next);
  }

  // ────────────────────────────────────────────────────────────
  //  TRIM WORKFLOW
  // ────────────────────────────────────────────────────────────
  void _previewTrim() {
    final ctrl = _controller;
    if (ctrl == null || _isTimelineInvalid) return;

    _removePreviewListener();
    unawaited(
      _seekTo(
        _trimStart,
        source: 'trim_preview_start',
        resumePlayback: false,
      ).then((_) {
        final activeCtrl = _controller;
        if (!mounted || activeCtrl == null || _isTimelineInvalid) return;
        activeCtrl.setPlaybackSpeed(_previewSpeed);
        activeCtrl.play();
        _isPreviewingTrim = true;

        _previewListener = () {
          if (!mounted || !_isPreviewingTrim) return;
          if (activeCtrl.value.position >= _trimEnd) {
            activeCtrl.pause();
            _removePreviewListener();
            if (mounted) setState(() {});
          }
        };
        activeCtrl.addListener(_previewListener!);
        setState(() {});
      }),
    );
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
                                                    onPressed: () async {
                                                      _removePreviewListener();
                                                      await _seekTo(
                                                        ctrl.value.position -
                                                            const Duration(
                                                              seconds: 10,
                                                            ),
                                                        source: 'btn_seek_back',
                                                      );
                                                      _resetOverlayTimer();
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
                                                    onPressed: () async {
                                                      _removePreviewListener();
                                                      await _seekTo(
                                                        ctrl.value.position +
                                                            const Duration(
                                                              seconds: 10,
                                                            ),
                                                        source:
                                                            'btn_seek_forward',
                                                      );
                                                      _resetOverlayTimer();
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
                                            child: GestureDetector(
                                              onTap:
                                                  () {}, // Blocks overlay toggle
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
                                                  alignment:
                                                      Alignment.bottomLeft,
                                                  children: [
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () {
                                                                _toggleMute();
                                                                _resetOverlayTimer();
                                                              },
                                                              onLongPress: () {
                                                                setState(() {
                                                                  _showVolumeSlider =
                                                                      !_showVolumeSlider;
                                                                });
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
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontFeatures: [
                                                                  FontFeature.tabularFigures(),
                                                                ],
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        PlaybackTimeline(
                                                          currentPosition: ctrl
                                                              .value
                                                              .position,
                                                          duration:
                                                              _videoDuration,
                                                          trimStart: _trimStart,
                                                          trimEnd: _trimEnd,
                                                          onScrubStart: () {
                                                            _resumePlaybackAfterScrub =
                                                                ctrl
                                                                    .value
                                                                    .isPlaying;
                                                            ctrl.pause();
                                                            setState(
                                                              () =>
                                                                  _isScrubbing =
                                                                      true,
                                                            );
                                                            _pendingScrubTarget =
                                                                null;
                                                            _overlayTimer
                                                                ?.cancel();
                                                          },
                                                          onScrubUpdate: (target) {
                                                            _pendingScrubTarget =
                                                                target;
                                                            _seekTo(
                                                              target,
                                                              source:
                                                                  'slider_scrub',
                                                              resumePlayback:
                                                                  false,
                                                            );
                                                          },
                                                          onScrubEnd: () {
                                                            final target =
                                                                _pendingScrubTarget;
                                                            setState(
                                                              () =>
                                                                  _isScrubbing =
                                                                      false,
                                                            );
                                                            if (target !=
                                                                null) {
                                                              _seekTo(
                                                                target,
                                                                source:
                                                                    'slider_scrub_commit',
                                                                resumePlayback:
                                                                    _resumePlaybackAfterScrub,
                                                              );
                                                            }
                                                            _resumePlaybackAfterScrub =
                                                                false;
                                                            _resetOverlayTimer();
                                                          },
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
                                                            color:
                                                                Colors.black87,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                          child: LayoutBuilder(
                                                            builder:
                                                                (
                                                                  context,
                                                                  constraints,
                                                                ) {
                                                                  final trackHeight =
                                                                      constraints.maxHeight -
                                                                      20;
                                                                  final knobBottom =
                                                                      (_volume *
                                                                              trackHeight)
                                                                          .clamp(
                                                                            0.0,
                                                                            trackHeight,
                                                                          )
                                                                          .toDouble();
                                                                  return GestureDetector(
                                                                    behavior:
                                                                        HitTestBehavior
                                                                            .opaque,
                                                                    onTapDown:
                                                                        (
                                                                          details,
                                                                        ) {
                                                                          _overlayTimer
                                                                              ?.cancel();
                                                                          _setVolumeFromVerticalDrag(
                                                                            localDy: details
                                                                                .localPosition
                                                                                .dy,
                                                                            trackHeight:
                                                                                constraints.maxHeight,
                                                                          );
                                                                          _resetOverlayTimer();
                                                                        },
                                                                    onVerticalDragStart:
                                                                        (_) => _overlayTimer
                                                                            ?.cancel(),
                                                                    onVerticalDragUpdate:
                                                                        (
                                                                          details,
                                                                        ) {
                                                                          _setVolumeFromVerticalDrag(
                                                                            localDy: details
                                                                                .localPosition
                                                                                .dy,
                                                                            trackHeight:
                                                                                constraints.maxHeight,
                                                                          );
                                                                        },
                                                                    onVerticalDragEnd:
                                                                        (_) =>
                                                                            _resetOverlayTimer(),
                                                                    child: Stack(
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      children: [
                                                                        Positioned(
                                                                          top:
                                                                              10,
                                                                          bottom:
                                                                              10,
                                                                          child: Container(
                                                                            width:
                                                                                4,
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.white30,
                                                                              borderRadius: BorderRadius.circular(
                                                                                999,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Positioned(
                                                                          left:
                                                                              18,
                                                                          right:
                                                                              18,
                                                                          bottom:
                                                                              10,
                                                                          height:
                                                                              trackHeight *
                                                                              _volume,
                                                                          child: Container(
                                                                            decoration: BoxDecoration(
                                                                              color: AppColors.accent,
                                                                              borderRadius: BorderRadius.circular(
                                                                                999,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Positioned(
                                                                          bottom:
                                                                              2 +
                                                                              knobBottom,
                                                                          child: Container(
                                                                            width:
                                                                                14,
                                                                            height:
                                                                                14,
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.white,
                                                                              borderRadius: BorderRadius.circular(
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
