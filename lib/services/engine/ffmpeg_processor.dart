import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

import '../../core/models/export_settings.dart';
import 'i_video_processor.dart';
import 'ffmpeg_exception.dart';

class FFmpegProcessor implements IVideoProcessor {
  @override
  Future<String> processTrim({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
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

    return _executeCommand(command, outputPath);
  }

  /// Export with configurable settings (resolution, FPS, quality).
  Future<String> processExport({
    required String inputPath,
    required String outputPath,
    required ExportSettings settings,
    Duration? trimStart,
    Duration? trimEnd,
  }) async {
    final outFile = File(outputPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final parts = <String>['-y'];

    // Trim parameters (optional)
    if (trimStart != null && trimEnd != null && trimEnd > trimStart) {
      final startSecs = trimStart.inMilliseconds / 1000.0;
      final duration =
          (trimEnd.inMilliseconds - trimStart.inMilliseconds) / 1000.0;
      parts.addAll(['-ss', '$startSecs', '-t', '$duration']);
    }

    parts.addAll(['-i', '"$inputPath"']);
    parts.addAll(['-map', '0:v:0', '-map', '0:a?']);

    // Video codec + quality + resolution + FPS
    parts.addAll([
      '-c:v',
      'mpeg4',
      '-q:v',
      '${settings.qualityValue}',
      settings.scaleFilter,
      '-r',
      '${settings.fps}',
    ]);

    // Audio
    parts.addAll(['-c:a', 'aac', '-b:a', settings.audioBitrate]);

    // MP4 optimization
    parts.addAll(['-movflags', '+faststart']);

    parts.add('"$outputPath"');

    return _executeCommand(parts.join(' '), outputPath);
  }

  Future<String> _executeCommand(String command, String outputPath) async {
    final session = await FFmpegKit.execute(command);
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

    return outputPath;
  }
}
