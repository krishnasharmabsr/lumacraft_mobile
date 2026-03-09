abstract class IVideoProcessor {
  Future<String> processTrim({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  });
}
