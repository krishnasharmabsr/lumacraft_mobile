import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';

import '../../core/models/export_settings.dart';
import 'i_video_processor.dart';
import 'ffmpeg_exception.dart';

/// Progress callback: receives a value from 0.0 to 1.0.
typedef ProgressCallback = void Function(double progress);

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

    final startSecs = startTime.inMilliseconds / 1000.0;
    final endSecs = endTime.inMilliseconds / 1000.0;
    final duration = endSecs - startSecs;

    final command =
        '-y -ss $startSecs -t $duration -i "$inputPath" -map 0:v:0 -map 0:a? -c:v mpeg4 -q:v 3 -c:a aac -b:a 128k -movflags +faststart "$outputPath"';

    final totalMs = (duration * 1000).toInt();
    return _executeCommand(command, outputPath, totalMs, onProgress);
  }

  /// Export with configurable settings (resolution, FPS, quality).
  Future<String> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    Duration? trimStart,
    Duration? trimEnd,
    ProgressCallback? onProgress,
  }) async {
    final outFile = File(outputPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final parts = <String>['-y'];
    double totalDurationSecs = 0;

    // Trim parameters (optional)
    if (trimStart != null && trimEnd != null && trimEnd > trimStart) {
      final startSecs = trimStart.inMilliseconds / 1000.0;
      final duration =
          (trimEnd.inMilliseconds - trimStart.inMilliseconds) / 1000.0;
      parts.addAll(['-ss', '$startSecs', '-t', '$duration']);
      totalDurationSecs = duration;
    }

    parts.addAll(['-i', '"$inputPath"']);
    parts.addAll(['-map', '0:v:0', '-map', '0:a?']);

    // Auto-detect and clamp FPS if needed
    int? finalFps = settings.fps;
    if (finalFps != null) {
      try {
        final mediaInfo = await FFprobeKit.getMediaInformation(inputPath);
        final streams = mediaInfo.getMediaInformation()?.getStreams();
        if (streams != null) {
          for (final stream in streams) {
            if (stream.getType() == 'video') {
              final rateStr =
                  stream.getAverageFrameRate() ?? stream.getRealFrameRate();
              if (rateStr != null && rateStr.contains('/')) {
                final rateParts = rateStr.split('/');
                if (rateParts.length == 2 && rateParts[1] != '0') {
                  final sourceFps =
                      (double.parse(rateParts[0]) / double.parse(rateParts[1]))
                          .round();
                  if (sourceFps > 0 && sourceFps < finalFps!) {
                    finalFps = sourceFps;
                  }
                }
              }
              break;
            }
          }
        }
      } catch (_) {
        // Fallback to user-selected FPS if probing fails
      }
    }

    // Video codec + quality + resolution
    parts.addAll([
      '-c:v',
      'mpeg4',
      '-q:v',
      '${settings.qualityValue}',
      settings.scaleFilter,
    ]);

    if (finalFps != null) {
      parts.addAll(['-r', '$finalFps']);
    }

    // Audio
    parts.addAll(['-c:a', 'aac', '-b:a', settings.audioBitrate]);

    // MP4 optimization (only for MP4)
    if (settings.format == ExportFormat.mp4) {
      parts.addAll(['-movflags', '+faststart']);
    }

    parts.add('"$outputPath"');

    final totalMs = totalDurationSecs > 0
        ? (totalDurationSecs * 1000).toInt()
        : 0;

    return _executeCommand(parts.join(' '), outputPath, totalMs, onProgress);
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
