import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';
import '../../core/services/pro_gate.dart';
import '../io/native_video_picker.dart';

import '../../core/models/export_settings.dart';
import 'i_video_processor.dart';
import 'ffmpeg_exception.dart';

/// Progress callback: receives a value from 0.0 to 1.0.
typedef ProgressCallback = void Function(double progress);

// ────────────────────────────────────────────────────────────
//  FAILURE CLASSIFICATION
// ────────────────────────────────────────────────────────────
enum ExportFailureType { watermark, audio, encoder, unknown }

enum VideoCodecProfile { mpeg4Default, x264Fallback }

class FFmpegProcessor implements IVideoProcessor {
  @override
  Future<String> processTrim({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
    ProgressCallback? onProgress,
  }) async {
    if (endTime <= startTime) {
      throw FFmpegException(
        'Invalid trim duration: endTime must be greater than startTime',
        '',
        0,
        '',
      );
    }

    final outFile = File(outputPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final outDir = outFile.parent;
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final startSecs = startTime.inMilliseconds / 1000.0;
    final endSecs = endTime.inMilliseconds / 1000.0;
    final duration = endSecs - startSecs;

    final command =
        '-y -ss $startSecs -t $duration -i "$inputPath" -map 0:v:0 -map 0:a? -c:v mpeg4 -q:v 3 -c:a aac -b:a 128k -movflags +faststart "$outputPath"';

    final totalMs = (duration * 1000).toInt();
    return _executeCommand(command, outputPath, totalMs, onProgress);
  }

  // ────────────────────────────────────────────────────────────
  //  ATEMPO CHAIN BUILDER
  // ────────────────────────────────────────────────────────────
  static String buildAtempoChain(double speed) {
    if (speed <= 0) return 'atempo=1.0';

    final List<String> segments = [];
    double remaining = speed;

    if (remaining > 2.0) {
      while (remaining > 2.0) {
        segments.add('atempo=2.0');
        remaining /= 2.0;
      }
      if ((remaining - 1.0).abs() > 0.001) {
        segments.add('atempo=$remaining');
      }
    } else if (remaining < 0.5) {
      while (remaining < 0.5) {
        segments.add('atempo=0.5');
        remaining /= 0.5;
      }
      if ((remaining - 1.0).abs() > 0.001) {
        segments.add('atempo=$remaining');
      }
    } else {
      segments.add('atempo=$speed');
    }

    if (segments.isEmpty) segments.add('atempo=1.0');
    return segments.join(',');
  }

  // ────────────────────────────────────────────────────────────
  //  FAILURE CLASSIFIER (pure/testable)
  // ────────────────────────────────────────────────────────────
  static ExportFailureType classifyFailure(String logTail) {
    final lower = logTail.toLowerCase();

    // Watermark / image input failures
    final wmPatterns = [
      'image2',
      'png',
      'overlay',
      'input #1',
      'could not find codec parameters',
      'error while decoding stream #1',
    ];
    for (final p in wmPatterns) {
      if (lower.contains(p)) return ExportFailureType.watermark;
    }

    // Audio mapping failures
    final audioPatterns = [
      'stream map',
      'matches no streams',
      '0:a:0',
      'invalid input stream',
    ];
    for (final p in audioPatterns) {
      if (lower.contains(p)) return ExportFailureType.audio;
    }

    // Encoder failures
    final encoderPatterns = [
      'error initializing output stream',
      'unknown encoder',
      'encoder',
      'mpeg4',
    ];
    for (final p in encoderPatterns) {
      if (lower.contains(p)) return ExportFailureType.encoder;
    }

    return ExportFailureType.unknown;
  }

  // ────────────────────────────────────────────────────────────
  //  EXPORT COMMAND BUILDER (pure/testable)
  // ────────────────────────────────────────────────────────────
  static ExportCommandResult buildExportCommand({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    required Duration trimStart,
    required Duration trimEnd,
    required double playbackSpeed,
    required ExportAspectRatio aspectRatio,
    required bool hasAudio,
    required int? finalFps,
    required bool applyWatermark,
    required String? watermarkPath,
    bool includeWatermark = true,
    bool includeAudio = true,
    VideoCodecProfile videoCodecProfile = VideoCodecProfile.mpeg4Default,
  }) {
    final effectiveAudio = hasAudio && includeAudio;
    final effectiveWatermark =
        applyWatermark && watermarkPath != null && includeWatermark;

    final parts = <String>['-y'];
    double totalDurationSecs = 0;
    String diagnostics = '';

    // 1. Trim parameters
    if (trimEnd > trimStart) {
      final startSecs = trimStart.inMilliseconds / 1000.0;
      final duration =
          (trimEnd.inMilliseconds - trimStart.inMilliseconds) / 1000.0;
      parts.addAll(['-ss', '$startSecs', '-t', '$duration']);
      totalDurationSecs = duration;
    }

    parts.addAll(['-i', '"$inputPath"']);

    // 2. Watermark input — looped image input
    if (effectiveWatermark) {
      parts.addAll(['-loop', '1', '-framerate', '1', '-i', '"$watermarkPath"']);
      diagnostics += 'watermark_active=true path=$watermarkPath\n';
    } else if (applyWatermark && !effectiveWatermark) {
      final reason = watermarkPath == null
          ? 'watermark_path_null'
          : 'includeWatermark=false';
      diagnostics += 'watermark_skipped=true reason=$reason\n';
    }

    if (!includeAudio && hasAudio) {
      diagnostics += 'audio_skipped=true reason=includeAudio=false\n';
    }

    if (videoCodecProfile == VideoCodecProfile.x264Fallback) {
      diagnostics += 'codec_profile=x264_fallback\n';
    }

    final List<String> filterSegments = [];
    String currentVideoMap = '[v_initial]';

    // Graph Start — passthrough to start naming
    filterSegments.add('[0:v:0]null$currentVideoMap');

    // Track whether audio goes through a filter graph
    bool audioFiltered = false;
    const String audioLabel = '[a_speed]';

    // 3. Speed
    if (playbackSpeed != 1.0) {
      final videoPts = 1.0 / playbackSpeed;
      const String nextMap = '[v_speed]';
      filterSegments.add('${currentVideoMap}setpts=$videoPts*PTS$nextMap');
      currentVideoMap = nextMap;

      if (effectiveAudio) {
        final atempoChain = buildAtempoChain(playbackSpeed);
        filterSegments.add('[0:a:0]$atempoChain$audioLabel');
        audioFiltered = true;
      }
      totalDurationSecs = playbackSpeed > 0
          ? totalDurationSecs / playbackSpeed
          : totalDurationSecs;
    }

    // 4. Canvas (Aspect Ratio)
    if (aspectRatio != ExportAspectRatio.source) {
      const String nextMap = '[v_canvas]';
      final targetHeight = 1080;
      final targetWidth = (targetHeight * aspectRatio.ratio!).round();
      final scaleFilter =
          'scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:black';
      filterSegments.add('$currentVideoMap$scaleFilter$nextMap');
      currentVideoMap = nextMap;
    }

    // 5. Final Scale from Export Settings (resolution)
    const String nextScaleMap = '[v_scaled]';
    filterSegments.add('$currentVideoMap${settings.scaleFilter}$nextScaleMap');
    currentVideoMap = nextScaleMap;

    // 6. Watermark overlay
    if (effectiveWatermark) {
      filterSegments.add('[1:v]format=rgba,scale=120:-1[wm]');
      const String nextMap = '[v_out]';
      filterSegments.add(
        '$currentVideoMap[wm]overlay=main_w-overlay_w-20:main_h-overlay_h-20:shortest=1$nextMap',
      );
      currentVideoMap = nextMap;
    }

    parts.addAll([
      '-filter_complex',
      '"${filterSegments.join(';')}"',
      '-map',
      '"$currentVideoMap"',
    ]);

    // Audio mapping — bare stream spec for unfiltered, label for filtered
    if (effectiveAudio) {
      if (audioFiltered) {
        parts.addAll(['-map', '"$audioLabel"']);
      } else {
        parts.addAll(['-map', '0:a:0']);
      }
    }

    // Video codec
    switch (videoCodecProfile) {
      case VideoCodecProfile.mpeg4Default:
        parts.addAll(['-c:v', 'mpeg4', '-q:v', '${settings.qualityValue}']);
      case VideoCodecProfile.x264Fallback:
        parts.addAll([
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          '-preset',
          'veryfast',
          '-crf',
          '23',
        ]);
    }

    if (finalFps != null) {
      parts.addAll(['-r', '$finalFps']);
    }

    if (effectiveAudio) {
      parts.addAll(['-c:a', 'aac', '-b:a', settings.audioBitrate]);
    }

    if (settings.format == ExportFormat.mp4) {
      parts.addAll(['-movflags', '+faststart']);
    }

    parts.add('"$outputPath"');

    final totalMs = totalDurationSecs > 0
        ? (totalDurationSecs * 1000).toInt()
        : 0;

    // Determine if watermark was skipped for user-facing message
    String? watermarkSkippedMessage;
    if (applyWatermark && !effectiveWatermark) {
      watermarkSkippedMessage =
          'Watermark skipped due to device codec limitations';
    }

    return ExportCommandResult(
      command: parts.join(' '),
      totalMs: totalMs,
      diagnostics: diagnostics,
      watermarkSkippedMessage: watermarkSkippedMessage,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  RETRY MATRIX DECISION (pure/testable)
  //  Given current attempt config and failure type, returns
  //  next attempt config, or null if all retries exhausted.
  // ────────────────────────────────────────────────────────────
  static ExportAttemptConfig? nextAttempt(
    ExportAttemptConfig current,
    ExportFailureType failureType,
  ) {
    // A → B: disable watermark
    if (current.includeWatermark) {
      return ExportAttemptConfig(
        label: 'B',
        includeWatermark: false,
        includeAudio: current.includeAudio,
        videoCodecProfile: current.videoCodecProfile,
      );
    }

    // B → C: disable audio
    if (current.includeAudio) {
      return ExportAttemptConfig(
        label: 'C',
        includeWatermark: false,
        includeAudio: false,
        videoCodecProfile: current.videoCodecProfile,
      );
    }

    // C → D: x264 fallback codec
    if (current.videoCodecProfile == VideoCodecProfile.mpeg4Default) {
      return ExportAttemptConfig(
        label: 'D',
        includeWatermark: false,
        includeAudio: false,
        videoCodecProfile: VideoCodecProfile.x264Fallback,
      );
    }

    // All retries exhausted
    return null;
  }

  @override
  Future<String> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    required Duration trimStart,
    required Duration trimEnd,
    required double playbackSpeed,
    required ExportAspectRatio aspectRatio,
    ProgressCallback? onProgress,
  }) async {
    final outFile = File(outputPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final outDir = outFile.parent;
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // Detect Audio + FPS
    int? finalFps = settings.fps;
    bool hasAudio = false;

    try {
      final mediaInfo = await FFprobeKit.getMediaInformation(inputPath);
      final streams = mediaInfo.getMediaInformation()?.getStreams();
      if (streams != null) {
        for (final stream in streams) {
          if (stream.getType() == 'audio') {
            hasAudio = true;
          }
          if (stream.getType() == 'video') {
            final rateStr =
                stream.getAverageFrameRate() ?? stream.getRealFrameRate();
            if (rateStr != null && rateStr.contains('/')) {
              final rateParts = rateStr.split('/');
              if (rateParts.length == 2 && rateParts[1] != '0') {
                final sourceFps =
                    (double.parse(rateParts[0]) / double.parse(rateParts[1]))
                        .round();
                if (sourceFps > 0 && finalFps != null && sourceFps < finalFps) {
                  finalFps = sourceFps;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Watermark preflight — Dart-side decode only (NO FFprobe on PNG)
    final bool applyWatermark = !ProGate.isPro;
    String? watermarkPath;
    String wmDiagnostics = '';

    if (applyWatermark) {
      try {
        final ByteData data = await rootBundle.load(
          'assets/branding/logo_mark_master_1024.png',
        );
        final Uint8List assetBytes = data.buffer.asUint8List();

        final image = img.decodePng(assetBytes);
        if (image == null || image.width == 0 || image.height == 0) {
          throw Exception(
            'Watermark preflight: decoded width/height is zero or null',
          );
        }

        wmDiagnostics +=
            'Watermark loaded. '
            'Asset=${assetBytes.length}B '
            '${image.width}x${image.height}\n';

        final pngBytes = img.encodePng(image);
        final String cachePath = await NativeVideoPicker.getCachePath();
        watermarkPath = '$cachePath/watermark_runtime.png';
        final File wFile = File(watermarkPath);
        await wFile.writeAsBytes(pngBytes);

        final finalSize = await wFile.length();
        if (finalSize == 0) {
          throw Exception('Watermark preflight: encoded file size is 0');
        }
        wmDiagnostics += 'Runtime written: $watermarkPath ($finalSize B)\n';
      } catch (e) {
        wmDiagnostics += 'watermark_skipped=true reason=$e\n';
        watermarkPath = null;
      }
    }

    // ────────────────────────────────────────────────────────
    //  MULTI-ATTEMPT EXPORT EXECUTION (A → B → C → D)
    // ────────────────────────────────────────────────────────
    var attemptConfig = ExportAttemptConfig(
      label: 'A',
      includeWatermark: true,
      includeAudio: true,
      videoCodecProfile: VideoCodecProfile.mpeg4Default,
    );

    final allDiagnostics = StringBuffer(wmDiagnostics);
    FFmpegException? lastError;

    while (true) {
      final result = buildExportCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        settings: settings,
        trimStart: trimStart,
        trimEnd: trimEnd,
        playbackSpeed: playbackSpeed,
        aspectRatio: aspectRatio,
        hasAudio: hasAudio,
        finalFps: finalFps,
        applyWatermark: applyWatermark,
        watermarkPath: watermarkPath,
        includeWatermark: attemptConfig.includeWatermark,
        includeAudio: attemptConfig.includeAudio,
        videoCodecProfile: attemptConfig.videoCodecProfile,
      );

      allDiagnostics.writeln('--- Attempt ${attemptConfig.label} ---');
      allDiagnostics.writeln(result.diagnostics);

      debugPrint('--- FFMPEG EXPORT ATTEMPT ${attemptConfig.label} ---');
      debugPrint('Diagnostics:\n${result.diagnostics}');
      debugPrint(
        'hasAudio: $hasAudio, includeAudio: ${attemptConfig.includeAudio}',
      );
      debugPrint('includeWatermark: ${attemptConfig.includeWatermark}');
      debugPrint('codec: ${attemptConfig.videoCodecProfile.name}');
      debugPrint('command: ${result.command}');

      // Clean output file before each attempt
      final outF = File(outputPath);
      if (await outF.exists()) await outF.delete();

      try {
        final path = await _executeCommand(
          result.command,
          outputPath,
          result.totalMs,
          onProgress,
        );

        allDiagnostics.writeln('Attempt ${attemptConfig.label}: SUCCESS');

        // Log a warning if we degraded from the original intent
        if (attemptConfig.label != 'A') {
          debugPrint(
            'Export succeeded on attempt ${attemptConfig.label} '
            '(degraded from full export)',
          );
          if (result.watermarkSkippedMessage != null) {
            debugPrint(result.watermarkSkippedMessage!);
          }
        }

        return path;
      } on FFmpegException catch (e) {
        final failureType = classifyFailure(e.logTail);
        allDiagnostics.writeln(
          'Attempt ${attemptConfig.label}: FAILED '
          '(type=$failureType, code=${e.returnCode})',
        );

        debugPrint(
          'Export attempt ${attemptConfig.label} FAILED: '
          'type=$failureType, code=${e.returnCode}',
        );

        lastError = e;

        // Try next attempt
        final next = nextAttempt(attemptConfig, failureType);
        if (next == null) {
          // All retries exhausted
          break;
        }
        attemptConfig = next;
      }
    }

    // All attempts failed — throw with accumulated diagnostics
    throw FFmpegException(
      'Export failed after all retry attempts (A/B/C/D)',
      lastError.command,
      lastError.returnCode,
      'FULL DIAGNOSTICS:\n$allDiagnostics\n'
          '=== LAST LOG TAIL ===\n${lastError.logTail}',
    );
  }

  Future<String> _executeCommand(
    String command,
    String outputPath,
    int totalDurationMs,
    ProgressCallback? onProgress,
  ) async {
    final completer = Completer<void>();

    final session = await FFmpegKit.executeAsync(
      command,
      (session) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      null,
      totalDurationMs > 0 && onProgress != null
          ? (Statistics statistics) {
              final time = statistics.getTime();
              if (time > 0 && totalDurationMs > 0) {
                final progress = (time / totalDurationMs).clamp(0.0, 1.0);
                onProgress(progress);
              }
            }
          : null,
    );

    await completer.future;

    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getLogsAsString();
      final logLines = logs.split('\n');
      final logTail = logLines.length > 30
          ? logLines.sublist(logLines.length - 30).join('\n')
          : logLines.join('\n');

      throw FFmpegException(
        'FFmpeg command failed',
        command,
        returnCode?.getValue(),
        logTail,
      );
    }

    onProgress?.call(1.0);
    return outputPath;
  }
}

// ────────────────────────────────────────────────────────────
//  DATA CLASSES
// ────────────────────────────────────────────────────────────

/// Configuration for a single export attempt.
class ExportAttemptConfig {
  final String label;
  final bool includeWatermark;
  final bool includeAudio;
  final VideoCodecProfile videoCodecProfile;

  const ExportAttemptConfig({
    required this.label,
    required this.includeWatermark,
    required this.includeAudio,
    required this.videoCodecProfile,
  });
}

/// Result from [FFmpegProcessor.buildExportCommand].
class ExportCommandResult {
  final String command;
  final int totalMs;
  final String diagnostics;
  final String? watermarkSkippedMessage;

  const ExportCommandResult({
    required this.command,
    required this.totalMs,
    required this.diagnostics,
    this.watermarkSkippedMessage,
  });
}
