import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

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
    // Ensure output path is clear
    final outFile = File(outputPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final startSecs = startTime.inMilliseconds / 1000.0;
    final endSecs = endTime.inMilliseconds / 1000.0;
    final duration = endSecs - startSecs;

    // Fast seek: -ss before -i, copy video, re-encode audio if needed or copy both
    // Using copy for both for maximum speed on mobile, accurate to keyframes
    // -accurate_seek -ss START -t DURATION -i INPUT -c copy OUTPUT
    final command =
        '-y -ss $startSecs -t $duration -i "$inputPath" -c:v copy -c:a copy "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getLogsAsString();
      final logLines = logs.split('\n');
      final logTail = logLines.length > 30
          ? logLines.sublist(logLines.length - 30).join('\n')
          : logLines.join('\n');

      throw FFmpegException(
        'Failed to trim video',
        command,
        returnCode?.getValue(),
        logTail,
      );
    }

    return outputPath;
  }
}
