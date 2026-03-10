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

class FFmpegProcessor implements IVideoProcessor {
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

    final parts = <String>['-y'];
    double totalDurationSecs = 0;

    // 1. Trim parameters
    if (trimEnd > trimStart) {
      final startSecs = trimStart.inMilliseconds / 1000.0;
      final duration =
          (trimEnd.inMilliseconds - trimStart.inMilliseconds) / 1000.0;
      parts.addAll(['-ss', '$startSecs', '-t', '$duration']);
      totalDurationSecs = duration;
    }

    parts.addAll(['-i', '"$inputPath"']);

    final bool applyWatermark = !ProGate.isPro;
    String? watermarkPath;
    String diagnostics = '';
    bool useTextFallback = false;

    // 2. Watermark Preflight
    if (applyWatermark) {
      try {
        final ByteData data = await rootBundle.load(
          'assets/branding/logo_mark_master_1024.png',
        );
        final Uint8List assetBytes = data.buffer.asUint8List();

        final image = img.decodePng(assetBytes);
        if (image == null || image.width == 0 || image.height == 0) {
          throw Exception(
            'Watermark preflight failed: decoded width/height is zero or null',
          );
        }

        diagnostics += 'Watermark loaded from asset.\n';
        diagnostics += 'Asset bytes size: ${assetBytes.length}\n';
        diagnostics += 'Decoded dimensions: ${image.width}x${image.height}\n';

        final pngBytes = img.encodePng(image);
        final String cachePath = await NativeVideoPicker.getCachePath();
        watermarkPath = '$cachePath/watermark_runtime.png';
        final File wFile = File(watermarkPath);
        await wFile.writeAsBytes(pngBytes);

        final finalSize = await wFile.length();
        if (finalSize == 0) {
          throw Exception('Watermark preflight failed: encoded file size is 0');
        }
        diagnostics += 'Runtime file written to: $watermarkPath\n';
        diagnostics += 'Runtime file size: $finalSize\n';

        // Additional ffprobe check to ensure the file is readable by ffmpeg
        final wmInfo = await FFprobeKit.getMediaInformation(watermarkPath);
        final wmStreams = wmInfo.getMediaInformation()?.getStreams();
        bool hasWmVideo = false;
        if (wmStreams != null) {
          for (final stream in wmStreams) {
            if (stream.getType() == 'video' &&
                stream.getWidth() != null &&
                stream.getWidth()! > 0) {
              hasWmVideo = true;
              diagnostics +=
                  'FFprobe verified watermark width: ${stream.getWidth()}\n';
              break;
            }
          }
        }
        if (!hasWmVideo) {
          throw Exception(
            'Watermark preflight failed: FFprobe could not read video stream from PNG',
          );
        }

        // Use robust explicit -i input without fragile flags
        parts.addAll(['-i', '"$watermarkPath"']);
      } catch (e) {
        diagnostics +=
            'WARNING: Image watermark failed: $e. Falling back to text.\n';
        useTextFallback = true;
      }
    }

    final List<String> filterSegments = [];
    String currentVideoMap = '[v_initial]';

    // Graph Start
    filterSegments.add(
      '[0:v:0]null$currentVideoMap',
    ); // Just a passthrough to start naming
    String currentAudioMap = hasAudio ? '[0:a:0]' : '';

    // 3. Speed
    if (playbackSpeed != 1.0) {
      final videoPts = 1.0 / playbackSpeed;
      final String nextMap = '[v_speed]';
      filterSegments.add(
        '$currentVideoMap'
        'setpts=$videoPts*PTS$nextMap',
      );
      currentVideoMap = nextMap;

      if (hasAudio) {
        final String nextAudioMap = '[a_speed]';
        filterSegments.add(
          '$currentAudioMap'
          'atempo=$playbackSpeed$nextAudioMap',
        );
        currentAudioMap = nextAudioMap;
      }
      totalDurationSecs = totalDurationSecs / playbackSpeed;
    }

    // 4. Canvas (Aspect Ratio)
    if (aspectRatio != ExportAspectRatio.source) {
      final String nextMap = '[v_canvas]';

      // Use a generic height base like 1080 to maintain quality during intermediate.
      final targetHeight = 1080;
      final targetWidth = (targetHeight * aspectRatio.ratio!).round();
      final scaleFilter =
          'scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:black';

      filterSegments.add('$currentVideoMap$scaleFilter$nextMap');
      currentVideoMap = nextMap;
    }

    // 5. Final Scale configuration from Export Settings (resolution)
    final String nextScaleMap = '[v_scaled]';
    filterSegments.add('$currentVideoMap${settings.scaleFilter}$nextScaleMap');
    currentVideoMap = nextScaleMap;

    // 6. Watermark overlay
    if (applyWatermark) {
      if (!useTextFallback) {
        // [1:v] references the second input file
        filterSegments.add('[1:v]scale=120:-1[wm]');
        // Apply overlay
        final String nextMap = '[v_out]';
        filterSegments.add(
          '$currentVideoMap[wm]overlay=main_w-overlay_w-20:main_h-overlay_h-20:shortest=1$nextMap',
        );
        currentVideoMap = nextMap;
      } else {
        final String nextMap = '[v_out]';
        // Fallback text watermark
        filterSegments.add(
          '$currentVideoMap'
          'drawtext=text=\'LumaCraft\':fontcolor=white@0.5:fontsize=48:x=w-tw-20:y=h-th-20$nextMap',
        );
        currentVideoMap = nextMap;
      }
    }

    parts.addAll([
      '-filter_complex',
      '"${filterSegments.join(';')}"',
      '-map',
      '"$currentVideoMap"',
    ]);

    if (hasAudio) {
      parts.addAll(['-map', '"$currentAudioMap"']);
    }

    parts.addAll(['-c:v', 'mpeg4', '-q:v', '${settings.qualityValue}']);

    if (finalFps != null) {
      parts.addAll(['-r', '$finalFps']);
    }

    if (hasAudio) {
      parts.addAll(['-c:a', 'aac', '-b:a', settings.audioBitrate]);
    }

    if (settings.format == ExportFormat.mp4) {
      parts.addAll(['-movflags', '+faststart']);
    }

    parts.add('"$outputPath"');

    final totalMs = totalDurationSecs > 0
        ? (totalDurationSecs * 1000).toInt()
        : 0;

    final commandStr = parts.join(' ');
    debugPrint('--- FFMPEG EXPORT PROFILE ---');
    debugPrint('Watermark details:\n$diagnostics');
    debugPrint('hasAudio: $hasAudio');
    debugPrint('targetFps: $finalFps');
    debugPrint('format: ${settings.format.name}');
    debugPrint('resolution: ${settings.resolution.label}');
    debugPrint('command: $commandStr');
    debugPrint('----------------------------');

    try {
      return await _executeCommand(commandStr, outputPath, totalMs, onProgress);
    } catch (e) {
      if (e is FFmpegException) {
        throw FFmpegException(
          e.message,
          e.command,
          e.returnCode,
          'DIAGNOSTICS:\n$diagnostics\n=== LOG TAIL ===\n${e.logTail}',
        );
      }
      rethrow;
    }
  }

  Future<String> _executeCommand(
    String command,
    String outputPath,
    int totalDurationMs,
    ProgressCallback? onProgress,
  ) async {
    // Use a Completer to properly wait for async execution to finish
    final completer = Completer<void>();

    final session = await FFmpegKit.executeAsync(
      command,
      // Completion callback — signals that FFmpeg has finished
      (session) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      null, // Log callback
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

    // Wait for the completion callback to fire
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

    // Ensure 100% on completion
    onProgress?.call(1.0);

    return outputPath;
  }
}
